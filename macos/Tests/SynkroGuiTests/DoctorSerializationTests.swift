import Testing
import Foundation
@testable import SynkroGui

@Suite("Doctor Serialization Tests")
struct DoctorSerializationTests {

    @Test("Decode clean doctor report")
    func testDecodeCleanReport() throws {
        let json = """
        {
          "version": "0.8.5",
          "all_passed": true,
          "checks": [
            {
              "name": "Network Interface",
              "category": "Network & Monotonic Clock",
              "status": "Passed",
              "message": "Primary LAN IPv4: 192.168.1.100",
              "details": null,
              "remediation": null,
              "is_fixable": false
            }
          ],
          "fixable_count": 0,
          "repairs_applied": []
        }
        """.data(using: .utf8)!

        let report = try JSONDecoder().decode(DoctorReport.self, from: json)
        #expect(report.version == "0.8.5")
        #expect(report.allPassed == true)
        #expect(report.hasFailures == false)
        #expect(report.hasWarnings == false)
        #expect(report.checks.count == 1)
        #expect(report.checks[0].name == "Network Interface")
        #expect(report.checks[0].status == .passed)
        #expect(report.repairsApplied.isEmpty)
    }

    @Test("Decode report with failures and applied repairs")
    func testDecodeReportWithFailuresAndRepairs() throws {
        let json = """
        {
          "version": "0.8.5",
          "all_passed": false,
          "checks": [
            {
              "name": "Media Player",
              "category": "Media Controller & Permissions",
              "status": "Failed",
              "message": "Automation permission denied (-1743)",
              "details": null,
              "remediation": "Open System Settings > Privacy & Security > Automation",
              "is_fixable": false
            },
            {
              "name": "Background Daemon",
              "category": "Background Daemon & IPC",
              "status": "Passed",
              "message": "Idle (stale socket cleaned)",
              "details": null,
              "remediation": null,
              "is_fixable": false
            }
          ],
          "fixable_count": 0,
          "repairs_applied": [
            "Removed stale socket: ~/.synkrophase/synkro.sock"
          ]
        }
        """.data(using: .utf8)!

        let report = try JSONDecoder().decode(DoctorReport.self, from: json)
        #expect(report.allPassed == false)
        #expect(report.hasFailures == true)
        #expect(report.checks.count == 2)
        #expect(report.checks[0].status == .failed)
        #expect(report.firstRemediation == "Open System Settings > Privacy & Security > Automation")
        #expect(report.repairsApplied.count == 1)
        #expect(report.repairsApplied[0].contains("Removed stale socket"))
    }

    @Test("Decode report with warnings only")
    func testDecodeReportWithWarnings() throws {
        let json = """
        {
          "version": "0.8.5",
          "all_passed": true,
          "checks": [
            {
              "name": "Media Player",
              "category": "Media Controller & Permissions",
              "status": "Warning",
              "message": "No active track playing",
              "details": "Controller latency: 85.4ms",
              "remediation": "Play a track in Spotify or Apple Music",
              "is_fixable": false
            }
          ],
          "fixable_count": 0,
          "repairs_applied": []
        }
        """.data(using: .utf8)!

        let report = try JSONDecoder().decode(DoctorReport.self, from: json)
        #expect(report.hasFailures == false)
        #expect(report.hasWarnings == true)
        #expect(report.firstRemediation == "Play a track in Spotify or Apple Music")
    }

    @Test("ViewModel runDoctor execution and state management")
    @MainActor
    func testViewModelRunDoctor() async throws {
        let vm = SynkroViewModel()
        let report = await vm.runDoctor(fix: false)
        if let report = report {
            #expect(!report.version.isEmpty)
            #expect(!report.checks.isEmpty)
            #expect(vm.doctorReport != nil)
            vm.clearDoctorReport()
            #expect(vm.doctorReport == nil)
        }
    }
}
