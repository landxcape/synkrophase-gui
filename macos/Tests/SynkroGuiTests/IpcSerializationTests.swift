import XCTest
@testable import SynkroGui

final class IpcSerializationTests: XCTestCase {
    func testDecodePlaybackState() throws {
        let json = """
        {
            "is_playing": true,
            "position_us": 45500000,
            "rate": 1.0,
            "metadata": {
                "title": "Midnight City",
                "artist": "M83",
                "album": "Hurry Up, We're Dreaming",
                "duration_us": 243000000
            }
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(PlaybackState.self, from: json)
        XCTAssertTrue(state.isPlaying)
        XCTAssertEqual(state.positionUs, 45500000)
        XCTAssertEqual(state.rate, 1.0)
        XCTAssertEqual(state.metadata?.title, "Midnight City")
        XCTAssertEqual(state.metadata?.artist, "M83")
        XCTAssertEqual(state.metadata?.durationUs, 243000000)
    }

    func testDecodePeerInfo() throws {
        let json = """
        [
            {
                "device_id": "a3f290d1-0000-0000-0000-000000000000",
                "name": "MacBook-Air",
                "role": "Moderator",
                "clock_offset_us": 12,
                "last_seen_epoch_ms": 1729312000000
            }
        ]
        """.data(using: .utf8)!

        let peers = try JSONDecoder().decode([PeerInfo].self, from: json)
        XCTAssertEqual(peers.count, 1)
        XCTAssertEqual(peers[0].name, "MacBook-Air")
        XCTAssertEqual(peers[0].role, .moderator)
        XCTAssertEqual(peers[0].clockOffsetUs, 12)
    }

    func testDecodeDriftMetrics() throws {
        let json = """
        {
            "offset_us": -150,
            "status": "InSync",
            "target_position_us": 45500000,
            "measured_position_us": 45500150
        }
        """.data(using: .utf8)!

        let drift = try JSONDecoder().decode(DriftMetrics.self, from: json)
        XCTAssertEqual(drift.offsetUs, -150)
        XCTAssertEqual(drift.status, "InSync")
        XCTAssertEqual(drift.targetPositionUs, 45500000)
    }

    func testDecodeDaemonStatusSnapshot() throws {
        let json = """
        {
            "room_code": "ALPHA9",
            "role": "Leader",
            "self_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
            "device_name": "Host-Mac",
            "leader_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
            "leader_addr": "192.168.1.100:5871",
            "is_playing": false,
            "position_sec": 12.5,
            "track_title": "Intro",
            "track_artist": "The xx",
            "track_album": "xx",
            "duration_sec": 127.0,
            "clock_offset_us": 0,
            "drift_offset_us": 0,
            "drift_status": "Idle",
            "peers": []
        }
        """.data(using: .utf8)!

        let status = try JSONDecoder().decode(DaemonStatusSnapshot.self, from: json)
        XCTAssertEqual(status.roomCode, "ALPHA9")
        XCTAssertEqual(status.role, .leader)
        XCTAssertFalse(status.isPlaying)
        XCTAssertEqual(status.positionSec, 12.5)
        XCTAssertEqual(status.trackTitle, "Intro")
    }

    func testEncodeIpcRequest() throws {
        let request = IpcRequest(
            id: 42,
            method: "seek",
            params: .dictionary(["position_sec": .double(30.5)])
        )

        let data = try JSONEncoder().encode(request)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"id\":42"))
        XCTAssertTrue(jsonString.contains("\"method\":\"seek\""))
        XCTAssertTrue(jsonString.contains("30.5"))
    }

    func testDaemonLaunchModeArguments() {
        let hostDefault = SynkroViewModel.DaemonLaunchMode.host(roomCode: nil)
        XCTAssertEqual(hostDefault.arguments, ["daemon", "start", "host"])

        let hostWithCode = SynkroViewModel.DaemonLaunchMode.host(roomCode: "DEMO9")
        XCTAssertEqual(hostWithCode.arguments, ["daemon", "start", "host", "DEMO9"])

        let joinMode = SynkroViewModel.DaemonLaunchMode.join(roomCode: "ROOM12")
        XCTAssertEqual(joinMode.arguments, ["daemon", "start", "join", "ROOM12"])
    }

    func testDecodeIpcResponseStatus() throws {
        let json = """
        {
            "id": 10,
            "result": {
                "room_code": "ROOM34C2",
                "role": "Leader",
                "self_id": "34c2dfe5-462d-4914-92a7-b05af8c74ced",
                "device_name": "shakyapurna",
                "leader_id": "34c2dfe5-462d-4914-92a7-b05af8c74ced",
                "leader_addr": null,
                "is_playing": true,
                "position_sec": 122.486,
                "track_title": "The Kill (Bury Me)",
                "track_artist": "Thirty Seconds to Mars",
                "track_album": "A Beautiful Lie",
                "duration_sec": 233.391006,
                "clock_offset_us": 0,
                "drift_offset_us": 0,
                "drift_status": "Locked (<80ms)",
                "peers": []
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(IpcResponse.self, from: json)
        guard let result = response.result else {
            XCTFail("result is nil")
            return
        }
        let encoded = try JSONEncoder().encode(result)
        let snapshot = try JSONDecoder().decode(DaemonStatusSnapshot.self, from: encoded)
        XCTAssertEqual(snapshot.roomCode, "ROOM34C2")
        XCTAssertEqual(snapshot.role, .leader)
        XCTAssertTrue(snapshot.isPlaying)
    }
}
