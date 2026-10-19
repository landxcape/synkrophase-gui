import Foundation
import Observation

public struct GitHubRelease: Codable, Sendable {
    public let tagName: String
    public let name: String?
    public let htmlUrl: String
    public let publishedAt: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
    }

    public init(tagName: String, name: String? = nil, htmlUrl: String, publishedAt: String? = nil) {
        self.tagName = tagName
        self.name = name
        self.htmlUrl = htmlUrl
        self.publishedAt = publishedAt
    }
}

public enum UpdateStatus: Sendable, Equatable {
    case idle
    case checking
    case upToDate(currentVersion: String)
    case updateAvailable(currentVersion: String, latestVersion: String, releaseUrl: URL)
    case error(message: String)
}

@Observable
@MainActor
public final class UpdateChecker {
    public var status: UpdateStatus = .idle
    public let currentVersion: String

    public init(currentVersion: String? = nil) {
        if let current = currentVersion {
            self.currentVersion = current
        } else {
            let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            self.currentVersion = bundleVersion ?? "0.1.1"
        }
    }

    public func checkForUpdates() async {
        status = .checking
        guard let url = URL(string: "https://api.github.com/repos/landxcape/synkrophase-gui/releases/latest") else {
            status = .error(message: "Invalid update URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Synkrophase-GUI/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                status = .error(message: "Network response error")
                return
            }

            if httpResponse.statusCode == 200 {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let latestTag = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                let currentClean = currentVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

                if Self.isVersion(latestTag, newerThan: currentClean) {
                    let releaseUrl = URL(string: release.htmlUrl) ?? url
                    status = .updateAvailable(
                        currentVersion: currentVersion,
                        latestVersion: latestTag,
                        releaseUrl: releaseUrl
                    )
                } else {
                    status = .upToDate(currentVersion: currentVersion)
                }
            } else if httpResponse.statusCode == 404 {
                status = .upToDate(currentVersion: currentVersion)
            } else if httpResponse.statusCode == 403 {
                status = .error(message: "GitHub API rate limit exceeded. Try again later.")
            } else {
                status = .error(message: "HTTP Error \(httpResponse.statusCode)")
            }
        } catch {
            status = .error(message: error.localizedDescription)
        }
    }

    nonisolated public static func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let v1Components = v1.split(separator: ".").compactMap { Int($0) }
        let v2Components = v2.split(separator: ".").compactMap { Int($0) }

        let count = max(v1Components.count, v2Components.count)
        for i in 0..<count {
            let num1 = i < v1Components.count ? v1Components[i] : 0
            let num2 = i < v2Components.count ? v2Components[i] : 0
            if num1 > num2 { return true }
            if num1 < num2 { return false }
        }
        return false
    }
}
