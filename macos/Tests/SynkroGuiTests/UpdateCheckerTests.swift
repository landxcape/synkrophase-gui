import XCTest
@testable import SynkroGui

final class UpdateCheckerTests: XCTestCase {
    func testVersionComparison() {
        // Newer patch version
        XCTAssertTrue(UpdateChecker.isVersion("0.1.2", newerThan: "0.1.1"))
        // Newer minor version
        XCTAssertTrue(UpdateChecker.isVersion("0.2.0", newerThan: "0.1.1"))
        // Newer major version
        XCTAssertTrue(UpdateChecker.isVersion("1.0.0", newerThan: "0.9.9"))
        // Sub-patch / extra digit
        XCTAssertTrue(UpdateChecker.isVersion("0.1.1.1", newerThan: "0.1.1"))

        // Equal version
        XCTAssertFalse(UpdateChecker.isVersion("0.1.1", newerThan: "0.1.1"))
        // Older patch version
        XCTAssertFalse(UpdateChecker.isVersion("0.1.0", newerThan: "0.1.1"))
        // Older minor version
        XCTAssertFalse(UpdateChecker.isVersion("0.0.9", newerThan: "0.1.0"))
        // Shorter version string
        XCTAssertFalse(UpdateChecker.isVersion("0.1", newerThan: "0.1.1"))
    }

    func testDecodeGitHubRelease() throws {
        let json = """
        {
            "tag_name": "v0.2.0",
            "name": "Synkrophase GUI v0.2.0",
            "html_url": "https://github.com/landxcape/synkrophase-gui/releases/tag/v0.2.0",
            "published_at": "2026-10-19T12:00:00Z"
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        XCTAssertEqual(release.tagName, "v0.2.0")
        XCTAssertEqual(release.name, "Synkrophase GUI v0.2.0")
        XCTAssertEqual(release.htmlUrl, "https://github.com/landxcape/synkrophase-gui/releases/tag/v0.2.0")
        XCTAssertEqual(release.publishedAt, "2026-10-19T12:00:00Z")
    }

    @MainActor
    func testUpdateCheckerInitialization() {
        let checker = UpdateChecker(currentVersion: "0.1.1")
        XCTAssertEqual(checker.currentVersion, "0.1.1")
        XCTAssertEqual(checker.status, .idle)
    }
}
