import Foundation
import Darwin

public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
}

public actor DaemonIpcClient {
    public static let defaultSocketPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.synkrophase/synkro.sock"
    }()

    private let socketPath: String
    private var socketFd: Int32 = -1
    private var isRunning: Bool = false
    private var nextRequestId: UInt64 = 10
    private var pendingContinuations: [UInt64: CheckedContinuation<IpcResponse, Error>] = [:]

    private var onEventCallback: (@Sendable (IpcEvent) -> Void)?
    private var onStateChangeCallback: (@Sendable (ConnectionState) -> Void)?

    public init(socketPath: String = DaemonIpcClient.defaultSocketPath) {
        self.socketPath = socketPath
    }

    public func setCallbacks(
        onEvent: @escaping @Sendable (IpcEvent) -> Void,
        onStateChange: @escaping @Sendable (ConnectionState) -> Void
    ) {
        self.onEventCallback = onEvent
        self.onStateChangeCallback = onStateChange
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        Task { [weak self] in
            await self?.connectionLoop()
        }
    }

    public func stop() {
        isRunning = false
        closeSocket()
        notifyState(.disconnected)
    }

    private func notifyState(_ state: ConnectionState) {
        onStateChangeCallback?(state)
    }

    private func connectionLoop() async {
        while isRunning {
            if FileManager.default.fileExists(atPath: socketPath) {
                notifyState(.connecting)
                if connectSocket() {
                    notifyState(.connected)

                    // Send initial subscription handshake
                    _ = try? await sendRequest(method: "subscribe")

                    // Read lines until disconnection
                    await readLoop()
                    notifyState(.disconnected)
                }
            } else {
                notifyState(.disconnected)
            }

            guard isRunning else { break }
            try? await Task.sleep(nanoseconds: 500 * 1_000_000)
        }
    }

    private func connectSocket() -> Bool {
        closeSocket()

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = socketPath.utf8CString
        guard pathBytes.count < MemoryLayout.size(ofValue: addr.sun_path) else {
            close(fd)
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
                connect(fd, saPtr, addrLen)
            }
        }

        if connectResult == 0 {
            self.socketFd = fd
            return true
        } else {
            close(fd)
            return false
        }
    }

    private func closeSocket() {
        if socketFd >= 0 {
            close(socketFd)
            socketFd = -1
        }
        for (_, cont) in pendingContinuations {
            cont.resume(throwing: NSError(domain: "SynkroIpc", code: -1, userInfo: [NSLocalizedDescriptionKey: "Socket closed"]))
        }
        pendingContinuations.removeAll()
    }

    private func readLoop() async {
        var readBuffer = Data()
        let chunkCapacity = 4096
        let tempBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkCapacity)
        defer { tempBuffer.deallocate() }

        while isRunning && socketFd >= 0 {
            let bytesRead = read(socketFd, tempBuffer, chunkCapacity)
            if bytesRead <= 0 {
                // Connection closed or error
                break
            }

            readBuffer.append(tempBuffer, count: bytesRead)

            // Split buffer on newline ('\n' = 0x0A)
            while let newlineIndex = readBuffer.firstIndex(of: 0x0A) {
                let lineData = readBuffer.subdata(in: 0..<newlineIndex)
                readBuffer.removeSubrange(0...newlineIndex)

                if !lineData.isEmpty {
                    handleIncomingLine(lineData)
                }
            }
        }

        closeSocket()
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
        guard socketFd >= 0 else {
            throw NSError(domain: "SynkroIpc", code: -2, userInfo: [NSLocalizedDescriptionKey: "Socket not connected"])
        }

        let reqId = nextRequestId
        nextRequestId += 1

        let request = IpcRequest(id: reqId, method: method, params: params)
        var data = try JSONEncoder().encode(request)
        data.append(0x0A) // Append newline delimiter

        return try await withCheckedThrowingContinuation { continuation in
            pendingContinuations[reqId] = continuation

            data.withUnsafeBytes { rawBuffer in
                if let ptr = rawBuffer.baseAddress {
                    let sent = write(socketFd, ptr, data.count)
                    if sent < 0 {
                        pendingContinuations.removeValue(forKey: reqId)
                        continuation.resume(throwing: NSError(domain: "SynkroIpc", code: -3, userInfo: [NSLocalizedDescriptionKey: "Write failed"]))
                    }
                }
            }
        }
    }
}
