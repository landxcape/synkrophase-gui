import Foundation

public enum DoctorCheckStatus: String, Codable, Sendable {
    case passed = "Passed"
    case warning = "Warning"
    case failed = "Failed"
}

public struct DoctorCheck: Codable, Identifiable, Equatable, Sendable {
    public var id: String { name }
    public let name: String
    public let category: String
    public let status: DoctorCheckStatus
    public let message: String
    public let details: String?
    public let remediation: String?
    public let isFixable: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case category
        case status
        case message
        case details
        case remediation
        case isFixable = "is_fixable"
    }
}

public struct DoctorReport: Codable, Equatable, Sendable {
    public let version: String
    public let allPassed: Bool
    public let checks: [DoctorCheck]
    public let fixableCount: Int
    public let repairsApplied: [String]

    enum CodingKeys: String, CodingKey {
        case version
        case allPassed = "all_passed"
        case checks
        case fixableCount = "fixable_count"
        case repairsApplied = "repairs_applied"
    }

    public var hasFailures: Bool {
        checks.contains { $0.status == .failed }
    }

    public var hasWarnings: Bool {
        checks.contains { $0.status == .warning }
    }

    public var firstRemediation: String? {
        checks.first { $0.status == .failed && $0.remediation != nil }?.remediation
            ?? checks.first { $0.status == .warning && $0.remediation != nil }?.remediation
    }
}
