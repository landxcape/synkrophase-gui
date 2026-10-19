import Foundation

// MARK: - Generic Dynamic JSON Value (AnyCodable)

public enum AnyCodable: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
        } else if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .double(doubleVal)
        } else if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            self = .array(arrayVal)
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(dictVal)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported AnyCodable value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        match_encode: switch self {
        case .null:
            try container.encodeNil()
        case .bool(let b):
            try container.encode(b)
        case .int(let i):
            try container.encode(i)
        case .double(let d):
            try container.encode(d)
        case .string(let s):
            try container.encode(s)
        case .array(let arr):
            try container.encode(arr)
        case .dictionary(let dict):
            try container.encode(dict)
        }
    }
}

// MARK: - IPC Base Types

public struct IpcRequest: Codable, Sendable {
    public let id: UInt64?
    public let method: String
    public let params: AnyCodable

    public init(id: UInt64? = nil, method: String, params: AnyCodable = .null) {
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct IpcResponse: Codable, Sendable {
    public let id: UInt64?
    public let result: AnyCodable?
    public let error: IpcError?
}

public struct IpcError: Codable, Sendable {
    public let code: Int
    public let message: String
}

public struct IpcEvent: Codable, Sendable {
    public let event: String
    public let data: AnyCodable
}

// MARK: - Domain Models

public enum Role: String, Codable, Sendable {
    case leader = "Leader"
    case moderator = "Moderator"
    case listener = "Listener"
}

public struct TrackMetadata: Codable, Equatable, Sendable {
    public let title: String
    public let artist: String?
    public let album: String?
    public let durationUs: UInt64?

    enum CodingKeys: String, CodingKey {
        case title
        case artist
        case album
        case durationUs = "duration_us"
    }

    public init(title: String, artist: String? = nil, album: String? = nil, durationUs: UInt64? = nil) {
        self.title = title
        self.artist = artist
        self.album = album
        self.durationUs = durationUs
    }
}

public struct PlaybackState: Codable, Equatable, Sendable {
    public let isPlaying: Bool
    public let positionUs: Int64
    public let rate: Float
    public let metadata: TrackMetadata?

    enum CodingKeys: String, CodingKey {
        case isPlaying = "is_playing"
        case positionUs = "position_us"
        case rate
        case metadata
    }

    public init(isPlaying: Bool, positionUs: Int64, rate: Float, metadata: TrackMetadata? = nil) {
        self.isPlaying = isPlaying
        self.positionUs = positionUs
        self.rate = rate
        self.metadata = metadata
    }
}

public struct PeerInfo: Codable, Equatable, Identifiable, Sendable {
    public var id: String { deviceId }
    public let deviceId: String
    public let name: String
    public let role: Role
    public let clockOffsetUs: Int64
    public let lastSeenEpochMs: UInt64?

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case name
        case role
        case clockOffsetUs = "clock_offset_us"
        case lastSeen = "last_seen"
        case lastSeenEpochMs = "last_seen_epoch_ms"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.deviceId = try container.decode(String.self, forKey: .deviceId)
        self.name = try container.decode(String.self, forKey: .name)
        self.role = try container.decode(Role.self, forKey: .role)
        self.clockOffsetUs = try container.decode(Int64.self, forKey: .clockOffsetUs)
        self.lastSeenEpochMs = (try? container.decodeIfPresent(UInt64.self, forKey: .lastSeen))
            ?? (try? container.decodeIfPresent(UInt64.self, forKey: .lastSeenEpochMs))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(name, forKey: .name)
        try container.encode(role, forKey: .role)
        try container.encode(clockOffsetUs, forKey: .clockOffsetUs)
        try container.encodeIfPresent(lastSeenEpochMs, forKey: .lastSeen)
    }

    public init(deviceId: String, name: String, role: Role, clockOffsetUs: Int64, lastSeenEpochMs: UInt64? = nil) {
        self.deviceId = deviceId
        self.name = name
        self.role = role
        self.clockOffsetUs = clockOffsetUs
        self.lastSeenEpochMs = lastSeenEpochMs
    }
}

public struct PeerUpdateWrapper: Codable, Sendable {
    public let peers: [PeerInfo]
    public let role: Role?
    public let isLeader: Bool?

    enum CodingKeys: String, CodingKey {
        case peers
        case role
        case isLeader = "is_leader"
    }
}

public struct DriftMetrics: Codable, Equatable, Sendable {
    public let offsetUs: Int64
    public let status: String
    public let targetPositionUs: Int64?
    public let measuredPositionUs: Int64?

    enum CodingKeys: String, CodingKey {
        case offsetUs = "offset_us"
        case status
        case targetPositionUs = "target_position_us"
        case measuredPositionUs = "measured_position_us"
    }

    public init(offsetUs: Int64, status: String, targetPositionUs: Int64? = nil, measuredPositionUs: Int64? = nil) {
        self.offsetUs = offsetUs
        self.status = status
        self.targetPositionUs = targetPositionUs
        self.measuredPositionUs = measuredPositionUs
    }
}

public struct NetworkStats: Codable, Equatable, Sendable {
    public let rttUs: UInt64?
    public let jitterUs: UInt64?

    enum CodingKeys: String, CodingKey {
        case rttUs = "rtt_us"
        case jitterUs = "jitter_us"
    }

    public init(rttUs: UInt64? = nil, jitterUs: UInt64? = nil) {
        self.rttUs = rttUs
        self.jitterUs = jitterUs
    }
}

public struct DaemonStatusSnapshot: Codable, Sendable {
    public let roomCode: String
    public let role: Role
    public let selfId: String
    public let deviceName: String
    public let leaderId: String?
    public let leaderAddr: String?
    public let isPlaying: Bool
    public let positionSec: Double
    public let trackTitle: String?
    public let trackArtist: String?
    public let trackAlbum: String?
    public let durationSec: Double?
    public let clockOffsetUs: Int64
    public let driftOffsetUs: Int64
    public let driftStatus: String
    public let peers: [PeerInfo]

    enum CodingKeys: String, CodingKey {
        case roomCode = "room_code"
        case role
        case selfId = "self_id"
        case deviceName = "device_name"
        case leaderId = "leader_id"
        case leaderAddr = "leader_addr"
        case isPlaying = "is_playing"
        case positionSec = "position_sec"
        case trackTitle = "track_title"
        case trackArtist = "track_artist"
        case trackAlbum = "track_album"
        case durationSec = "duration_sec"
        case clockOffsetUs = "clock_offset_us"
        case driftOffsetUs = "drift_offset_us"
        case driftStatus = "drift_status"
        case peers
    }
}
