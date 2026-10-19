import Foundation
import Darwin

public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
}

public final class DaemonIpcClient: @unchecked Sendable {
    public static let defaultSocketPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.synkrophase/synkro.sock"
    }()

    private let socketPath: String
    private let queue = DispatchQueue(label: "com.shakyapurna.synkrogui.ipc", qos: .userInitiated)
    private var socketFd: Int32 = -1
    private var readSource: (any DispatchSourceRead)?
    private var isRunning: Bool = false
    private var isConnected: Bool = false
    private var nextRequestId: UInt64 = 10
    private var pendingContinuations: [UInt64: CheckedContinuation<IpcResponse, Error>] = [:]
    private var readBuffer = Data()

    private var onEventCallback: (@Sendable (IpcEvent) -> Void)?
    private var onStateChangeCallback: (@Sendable (ConnectionState) -> Void)?

    public init(socketPath: String = DaemonIpcClient.defaultSocketPath) {
        self.socketPath = socketPath
    }

    public func setCallbacks(
        onEvent: @escaping @Sendable (IpcEvent) -> Void,
        onStateChange: @escaping @Sendable (ConnectionState) -> Void
    ) {
        queue.async {
            self.onEventCallback = onEvent
            self.onStateChangeCallback = onStateChange
        }
    }

    public func start() {
        queue.async {
            guard !self.isRunning else { return }
            self.isRunning = true
            self.connectionLoop()
        }
    }

    public func stop() {
        queue.async {
            self.isRunning = false
            self.closeSocket()
            self.notifyState(.disconnected)
        }
    }

    private func notifyState(_ state: ConnectionState) {
        if state == .connected {
            self.isConnected = true
        } else if state == .disconnected {
            self.isConnected = false
        }
        onStateChangeCallback?(state)
    }

    private func connectionLoop() {
        guard isRunning else { return }

        if FileManager.default.fileExists(atPath: socketPath) {
            if socketFd < 0 {
                notifyState(.connecting)
                if connectSocket() {
                    notifyState(.connected)
                    // Send initial subscription handshake
                    Task { [weak self] in
                        _ = try? await self?.sendRequest(method: "subscribe")
                    }
                } else {
                    notifyState(.disconnected)
                }
            }
        } else {
            if socketFd >= 0 {
                closeSocket()
                notifyState(.disconnected)
            }
        }

        queue.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
            self?.connectionLoop()
        }
    }

    private func connectSocket() -> Bool {
        closeSocket()

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }

        // Set non-blocking
        let flags = fcntl(fd, F_GETFL, 0)
        if flags >= 0 {
            _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = socketPath.utf8CString
        guard pathBytes.count < MemoryLayout.size(ofValue: addr.sun_path) else {
            Darwin.close(fd)
            return false
        }

        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let raw = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
            for (i, byte) in pathBytes.enumerated() {
                raw[i] = byte
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                Darwin.connect(fd, saPtr, addrLen)
            }
        }

        // On non-blocking sockets, 0 means connected, EINPROGRESS means connect in progress
        if connectResult == 0 || errno == EINPROGRESS {
            self.socketFd = fd
            setupReadSource(fd)
            return true
        } else {
            Darwin.close(fd)
            return false
        }
    }

    private func setupReadSource(_ fd: Int32) {
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = Darwin.read(fd, &buffer, buffer.count)
            if bytesRead > 0 {
                self.readBuffer.append(buffer, count: bytesRead)
                while let newlineIndex = self.readBuffer.firstIndex(of: 0x0A) {
                    let lineData = self.readBuffer.subdata(in: 0..<newlineIndex)
                    self.readBuffer.removeSubrange(0...newlineIndex)
                    if !lineData.isEmpty {
                        self.handleIncomingLine(lineData)
                    }
                }
            } else if bytesRead == 0 {
                // EOF - Daemon closed connection
                self.closeSocket()
                self.notifyState(.disconnected)
            }
        }
        source.setCancelHandler {
            Darwin.close(fd)
        }
        self.readSource = source
        source.resume()
    }

    private func closeSocket() {
        if let source = readSource {
            source.cancel()
            readSource = nil
        } else if socketFd >= 0 {
            Darwin.close(socketFd)
        }
        socketFd = -1
        readBuffer.removeAll()

        for (_, cont) in pendingContinuations {
            cont.resume(throwing: NSError(domain: "SynkroIpc", code: -1, userInfo: [NSLocalizedDescriptionKey: "Socket closed"]))
        }
        pendingContinuations.removeAll()
    }

    private func handleIncomingLine(_ data: Data) {
        let decoder = JSONDecoder()

        // Check if this is an IpcResponse
        if let response = try? decoder.decode(IpcResponse.self, from: data), let reqId = response.id {
            if let continuation = pendingContinuations.removeValue(forKey: reqId) {
                continuation.resume(returning: response)
                return
            }
        }

        // Check if this is an IpcEvent
        if let event = try? decoder.decode(IpcEvent.self, from: data) {
            onEventCallback?(event)
        }
    }

    public func sendRequest(method: String, params: AnyCodable = .null) async throws -> IpcResponse {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.socketFd >= 0 else {
                    continuation.resume(throwing: NSError(domain: "SynkroIpc", code: -2, userInfo: [NSLocalizedDescriptionKey: "Socket not connected"]))
                    return
                }

                let reqId = self.nextRequestId
                self.nextRequestId += 1

                let request = IpcRequest(id: reqId, method: method, params: params)
                guard var data = try? JSONEncoder().encode(request) else {
                    continuation.resume(throwing: NSError(domain: "SynkroIpc", code: -4, userInfo: [NSLocalizedDescriptionKey: "Serialization failed"]))
                    return
                }
                data.append(0x0A) // Append newline delimiter

                self.pendingContinuations[reqId] = continuation

                data.withUnsafeBytes { rawBuffer in
                    if let ptr = rawBuffer.baseAddress {
                        let sent = Darwin.write(self.socketFd, ptr, data.count)
                        if sent < 0 {
                            self.pendingContinuations.removeValue(forKey: reqId)
                            continuation.resume(throwing: NSError(domain: "SynkroIpc", code: -3, userInfo: [NSLocalizedDescriptionKey: "Write failed"]))
                        }
                    }
                }
            }
        }
    }
}
