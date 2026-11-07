import Foundation
import Observation
import AppKit

@Observable
@MainActor
public final class SynkroViewModel {
    public var connectionState: ConnectionState = .disconnected
    public var roomCode: String = ""
    public var role: Role = .listener
    public var isPlaying: Bool = false
    public var trackTitle: String = "No Track Active"
    public var trackArtist: String = ""
    public var trackAlbum: String = ""
    public var positionSec: Double = 0.0
    public var durationSec: Double = 0.0
    public var volume: Double = 80.0
    public var driftOffsetUs: Int64 = 0
    public var driftStatus: String = "Idle"
    public var peers: [PeerInfo] = []
    public var leaderAddr: String? = nil

    public var isScrubbing: Bool = false
    public var copiedRoomCode: Bool = false
    public var isStartingDaemon: Bool = false
    public var launchErrorMessage: String? = nil
    public var isRunningDoctor: Bool = false
    public var doctorReport: DoctorReport? = nil
    public var autoRepairMessage: String? = nil

    public struct JoinCredentials: Equatable, Sendable {
        public let roomCode: String
        public let leaderAddr: String?

        public init(roomCode: String, leaderAddr: String? = nil) {
            self.roomCode = roomCode
            self.leaderAddr = leaderAddr
        }

        public static func parse(_ rawInput: String) -> JoinCredentials {
            let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)

            // 1. Check for CLI command: synkro join <ROOM> [--leader-addr <ADDR>]
            if trimmed.contains("synkro join") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                var extractedRoom = ""
                var extractedAddr: String? = nil
                var i = 0
                while i < parts.count {
                    if parts[i] == "join" && i + 1 < parts.count {
                        extractedRoom = parts[i + 1]
                        i += 2
                        continue
                    }
                    if parts[i] == "--leader-addr" && i + 1 < parts.count {
                        extractedAddr = parts[i + 1]
                        i += 2
                        continue
                    }
                    i += 1
                }
                if !extractedRoom.isEmpty {
                    return JoinCredentials(roomCode: extractedRoom.uppercased(), leaderAddr: extractedAddr)
                }
            }

            // 2. Check for URI: synkro://<ROOM>/join?leader=<ADDR>
            if trimmed.hasPrefix("synkro://") {
                if let url = URL(string: trimmed), let host = url.host {
                    let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                    let leader = queryItems?.first(where: { $0.name == "leader" })?.value
                    return JoinCredentials(roomCode: host.uppercased(), leaderAddr: leader)
                }
            }

            // 3. Check for shorthand: <ROOM>@<ADDR>
            if trimmed.contains("@") {
                let split = trimmed.split(separator: "@", maxSplits: 1).map(String.init)
                if split.count == 2 {
                    let room = split[0].trimmingCharacters(in: .whitespaces).uppercased()
                    let addr = split[1].trimmingCharacters(in: .whitespaces)
                    return JoinCredentials(roomCode: room, leaderAddr: addr.isEmpty ? nil : addr)
                }
            }

            return JoinCredentials(roomCode: trimmed.uppercased(), leaderAddr: nil)
        }
    }

    public enum DaemonLaunchMode: Sendable, Equatable {
        case host(roomCode: String? = nil)
        case join(roomCode: String, leaderAddr: String? = nil)

        public var arguments: [String] {
            var args = ["daemon", "start"]
            switch self {
            case .host(let roomCode):
                args.append("host")
                if let code = roomCode, !code.trimmingCharacters(in: .whitespaces).isEmpty {
                    args.append(code.trimmingCharacters(in: .whitespaces))
                }
            case .join(let roomCode, let leaderAddr):
                args.append("join")
                args.append(roomCode.trimmingCharacters(in: .whitespaces))
                if let addr = leaderAddr, !addr.trimmingCharacters(in: .whitespaces).isEmpty {
                    args.append("--leader-addr")
                    args.append(addr.trimmingCharacters(in: .whitespaces))
                }
            }
            return args
        }
    }

    private let ipcClient: DaemonIpcClient
    private var timelineTimer: Timer?
    private var launchWatchdogTask: Task<Void, Never>?

    public init(ipcClient: DaemonIpcClient = DaemonIpcClient()) {
        self.ipcClient = ipcClient
        setupClient()
        startTimelineTimer()
    }

    private func setupClient() {
        ipcClient.setCallbacks(
            onEvent: { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleEvent(event)
                }
            },
            onStateChange: { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleStateChange(state)
                }
            }
        )
        ipcClient.start()
    }

    private func handleStateChange(_ state: ConnectionState) {
        self.connectionState = state
        if state == .connected {
            self.isStartingDaemon = false
            self.launchErrorMessage = nil
            self.autoRepairMessage = nil
            self.launchWatchdogTask?.cancel()
            self.launchWatchdogTask = nil
            Task {
                await fetchStatus()
            }
        } else if state == .disconnected {
            self.isPlaying = false
        }
    }

    private func handleEvent(_ event: IpcEvent) {
        let decoder = JSONDecoder()

        switch event.event {
        case "playback_update":
            if let data = try? JSONEncoder().encode(event.data),
               let state = try? decoder.decode(PlaybackState.self, from: data) {
                self.isPlaying = state.isPlaying
                if !self.isScrubbing {
                    self.positionSec = Double(state.positionUs) / 1_000_000.0
                }
                if let meta = state.metadata {
                    self.trackTitle = meta.title
                    self.trackArtist = meta.artist ?? ""
                    self.trackAlbum = meta.album ?? ""
                    if let durUs = meta.durationUs {
                        self.durationSec = Double(durUs) / 1_000_000.0
                    }
                }
            }

        case "peer_update":
            if let data = try? JSONEncoder().encode(event.data) {
                if let peerList = try? decoder.decode([PeerInfo].self, from: data) {
                    self.peers = peerList
                } else if let wrapper = try? decoder.decode(PeerUpdateWrapper.self, from: data) {
                    self.peers = wrapper.peers
                    if let newRole = wrapper.role {
                        self.role = newRole
                    }
                }
            }

        case "drift_update":
            if let data = try? JSONEncoder().encode(event.data),
               let drift = try? decoder.decode(DriftMetrics.self, from: data) {
                self.driftOffsetUs = drift.offsetUs
                self.driftStatus = drift.status
            }

        default:
            break
        }
    }

    public func fetchStatus() async {
        do {
            let response = try await ipcClient.sendRequest(method: "status")
            if let result = response.result {
                let data = try JSONEncoder().encode(result)
                let snapshot = try JSONDecoder().decode(DaemonStatusSnapshot.self, from: data)
                self.roomCode = snapshot.roomCode
                self.role = snapshot.role
                self.isPlaying = snapshot.isPlaying
                self.positionSec = snapshot.positionSec
                self.durationSec = snapshot.durationSec ?? 0.0
                self.trackTitle = snapshot.trackTitle ?? "No Track Active"
                self.trackArtist = snapshot.trackArtist ?? ""
                self.trackAlbum = snapshot.trackAlbum ?? ""
                self.driftOffsetUs = snapshot.driftOffsetUs
                self.driftStatus = snapshot.driftStatus
                self.peers = snapshot.peers
                self.leaderAddr = snapshot.leaderAddr
            }
        } catch {
            // Failed to fetch status
        }
    }

    private func startTimelineTimer() {
        timelineTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlaying, !self.isScrubbing else { return }
                if self.durationSec > 0 {
                    self.positionSec = min(self.positionSec + 0.1, self.durationSec)
                } else {
                    self.positionSec += 0.1
                }
            }
        }
    }

    // MARK: - User Commands

    public func togglePlayPause() {
        guard role != .listener else { return }
        let nextPlaying = !isPlaying
        self.isPlaying = nextPlaying // Optimistic UI update

        Task {
            let method = nextPlaying ? "play" : "pause"
            _ = try? await ipcClient.sendRequest(method: method)
        }
    }

    public func skipNext() {
        guard role != .listener else { return }
        Task {
            _ = try? await ipcClient.sendRequest(method: "next")
        }
    }

    public func skipPrev() {
        guard role != .listener else { return }
        Task {
            _ = try? await ipcClient.sendRequest(method: "prev")
        }
    }

    public func seek(to seconds: Double) {
        guard role != .listener else { return }
        self.positionSec = seconds
        self.isScrubbing = false

        Task {
            let params = AnyCodable.dictionary(["position_sec": .double(seconds)])
            _ = try? await ipcClient.sendRequest(method: "seek", params: params)
        }
    }

    public func setVolume(_ newVolume: Double) {
        self.volume = newVolume
        let intVol = Int(newVolume.rounded())

        Task {
            let params = AnyCodable.dictionary(["level": .int(intVol)])
            _ = try? await ipcClient.sendRequest(method: "volume", params: params)
        }
    }

    public func copyRoomCode() {
        guard !roomCode.isEmpty else { return }
        NSPasteboard.general.clearContents()

        let copyString: String
        if let addr = leaderAddr, !addr.isEmpty {
            copyString = "synkro join \(roomCode) --leader-addr \(addr)"
        } else {
            copyString = "synkro join \(roomCode)"
        }
        NSPasteboard.general.setString(copyString, forType: .string)

        copiedRoomCode = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.copiedRoomCode = false
        }
    }

    public func launchDaemon(mode: DaemonLaunchMode = .host(roomCode: nil), isAutoRetry: Bool = false) {
        self.isStartingDaemon = true
        self.launchErrorMessage = nil
        if !isAutoRetry {
            self.autoRepairMessage = nil
        }

        let synkroBin = findSynkroBinary()
        let process = Process()
        if synkroBin == "synkro" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["synkro"] + mode.arguments
        } else {
            process.executableURL = URL(fileURLWithPath: synkroBin)
            process.arguments = mode.arguments
        }

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if proc.terminationStatus != 0 {
                    self.handleLaunchFailure(mode: mode, exitCode: proc.terminationStatus, isAutoRetry: isAutoRetry)
                }
            }
        }

        do {
            try process.run()
        } catch {
            self.isStartingDaemon = false
            self.launchErrorMessage = "Failed to launch daemon: \(error.localizedDescription)"
            return
        }

        // Start 7.0s watchdog to prevent "stuck on starting"
        launchWatchdogTask?.cancel()
        launchWatchdogTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            guard let self = self, !Task.isCancelled else { return }
            if self.isStartingDaemon && self.connectionState != .connected {
                self.handleLaunchTimeout(mode: mode, isAutoRetry: isAutoRetry)
            }
        }
    }

    private func handleLaunchFailure(mode: DaemonLaunchMode, exitCode: Int32, isAutoRetry: Bool) {
        self.launchWatchdogTask?.cancel()
        self.launchWatchdogTask = nil

        if !isAutoRetry {
            self.autoRepairMessage = "Daemon exited (\(exitCode)). Running auto-repair..."
            Task {
                let report = await self.runDoctor(fix: true)
                if let report = report, !report.repairsApplied.isEmpty {
                    self.autoRepairMessage = "Repaired: \(report.repairsApplied.joined(separator: ", ")). Retrying launch..."
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    self.autoRepairMessage = nil
                    self.launchDaemon(mode: mode, isAutoRetry: true)
                    return
                }

                self.isStartingDaemon = false
                self.autoRepairMessage = nil
                let remediation = self.doctorReport?.firstRemediation
                self.launchErrorMessage = remediation ?? "Daemon exited with status \(exitCode). Run diagnostics below."
            }
        } else {
            self.isStartingDaemon = false
            self.autoRepairMessage = nil
            let remediation = self.doctorReport?.firstRemediation
            self.launchErrorMessage = remediation ?? "Daemon failed to start after auto-repair. Status \(exitCode)."
        }
    }

    private func handleLaunchTimeout(mode: DaemonLaunchMode, isAutoRetry: Bool) {
        if !isAutoRetry {
            self.autoRepairMessage = "Launch timed out. Running auto-repair..."
            Task {
                let report = await self.runDoctor(fix: true)
                if let report = report, !report.repairsApplied.isEmpty {
                    self.autoRepairMessage = "Repaired: \(report.repairsApplied.joined(separator: ", ")). Retrying launch..."
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    self.autoRepairMessage = nil
                    self.launchDaemon(mode: mode, isAutoRetry: true)
                    return
                }

                self.isStartingDaemon = false
                self.autoRepairMessage = nil
                let remediation = self.doctorReport?.firstRemediation
                self.launchErrorMessage = remediation ?? "Launch timed out. Run diagnostics below."
            }
        } else {
            self.isStartingDaemon = false
            self.autoRepairMessage = nil
            let remediation = self.doctorReport?.firstRemediation
            self.launchErrorMessage = remediation ?? "Launch timed out after auto-repair. Check diagnostics."
        }
    }

    @discardableResult
    public func runDoctor(fix: Bool = true) async -> DoctorReport? {
        self.isRunningDoctor = true
        defer { self.isRunningDoctor = false }

        var args = ["doctor", "--json"]
        if fix {
            args.insert("--fix", at: 1)
        }

        let result = await executeSynkro(arguments: args)
        guard let data = result.stdout.data(using: .utf8) else {
            return nil
        }

        do {
            let report = try JSONDecoder().decode(DoctorReport.self, from: data)
            self.doctorReport = report
            return report
        } catch {
            return nil
        }
    }

    public func clearDoctorReport() {
        self.doctorReport = nil
    }

    public func stopDaemon() {
        Task {
            _ = try? await ipcClient.sendRequest(method: "stop")
            _ = await executeSynkro(arguments: ["daemon", "stop"])
        }
    }

    private func executeSynkro(arguments: [String]) async -> (status: Int32, stdout: String, stderr: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                let binary = self.findSynkroBinary()
                if binary == "synkro" {
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = ["synkro"] + arguments
                } else {
                    process.executableURL = URL(fileURLWithPath: binary)
                    process.arguments = arguments
                }

                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stdoutStr = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""
                    continuation.resume(returning: (process.terminationStatus, stdoutStr, stderrStr))
                } catch {
                    continuation.resume(returning: (-1, "", error.localizedDescription))
                }
            }
        }
    }

    nonisolated private func findSynkroBinary() -> String {
        var candidates = [
            "/opt/homebrew/bin/synkro",
            "/usr/local/bin/synkro",
            FileManager.default.homeDirectoryForCurrentUser.path + "/.cargo/bin/synkro"
        ]

        let currentDir = FileManager.default.currentDirectoryPath
        candidates.append(contentsOf: [
            currentDir + "/synkrophase/target/release/synkro",
            currentDir + "/synkrophase/target/debug/synkro",
            currentDir + "/../synkrophase/target/release/synkro",
            currentDir + "/../synkrophase/target/debug/synkro"
        ])

        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return "synkro"
    }
}
