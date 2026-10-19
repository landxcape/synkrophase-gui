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

    public var isScrubbing: Bool = false
    public var copiedRoomCode: Bool = false
    public var isStartingDaemon: Bool = false

    private let ipcClient: DaemonIpcClient
    private var timelineTimer: Timer?

    public init(ipcClient: DaemonIpcClient = DaemonIpcClient()) {
        self.ipcClient = ipcClient
        setupClient()
        startTimelineTimer()
    }

    private func setupClient() {
        Task { [weak self] in
            await self?.ipcClient.setCallbacks(
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
            await self?.ipcClient.start()
        }
    }

    private func handleStateChange(_ state: ConnectionState) {
        self.connectionState = state
        if state == .connected {
            self.isStartingDaemon = false
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
            if let data = try? JSONEncoder().encode(event.data),
               let peerList = try? decoder.decode([PeerInfo].self, from: data) {
                self.peers = peerList
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
            if let result = response.result,
               let data = try? JSONEncoder().encode(result),
               let snapshot = try? JSONDecoder().decode(DaemonStatusSnapshot.self, from: data) {
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
            }
        } catch {
            // Socket error or disconnected
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
        NSPasteboard.general.setString(roomCode, forType: .string)

        copiedRoomCode = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.copiedRoomCode = false
        }
    }

    public func launchDaemon() {
        isStartingDaemon = true
        let synkroBin = findSynkroBinary()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: synkroBin)
        process.arguments = ["daemon", "start"]

        do {
            try process.run()
        } catch {
            isStartingDaemon = false
        }
    }

    private func findSynkroBinary() -> String {
        let candidates = [
            "/opt/homebrew/bin/synkro",
            "/usr/local/bin/synkro",
            FileManager.default.homeDirectoryForCurrentUser.path + "/.cargo/bin/synkro"
        ]
        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return "synkro"
    }
}
