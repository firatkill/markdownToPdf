import AppKit

/// Asks GitHub for the latest release and tells the user when it is newer
/// than the running version. Checks at most once a day on its own; the
/// "Check for Updates…" menu item checks right away.
@MainActor
final class UpdateChecker: ObservableObject {
    struct Release: Equatable {
        let version: String
        let pageURL: URL
    }

    enum CheckResult {
        case updateAvailable(Release)
        case upToDate(String)
        case unknownVersion
        case failed
    }

    static let shared = UpdateChecker()

    nonisolated static let repository = "firatkill/markdownToPdf"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    private enum Key {
        static let lastCheck = "lastUpdateCheck"
        static let skippedVersion = "skippedUpdateVersion"
    }

    @Published private(set) var available: Release?

    private let defaults = UserDefaults.standard

    /// Version of the running app; `nil` when not running from an app bundle (e.g. `swift run`).
    var currentVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    /// Called at launch: checks quietly if the last check was more than a day ago.
    func checkIfDue() {
        guard currentVersion != nil else { return }
        if let last = defaults.object(forKey: Key.lastCheck) as? Date,
           Date().timeIntervalSince(last) < Self.checkInterval {
            return
        }
        Task {
            let result = await check()
            if case .updateAvailable(let release) = result,
               release.version != defaults.string(forKey: Key.skippedVersion) {
                available = release
            }
        }
    }

    /// From the menu: always checks and always answers.
    func checkNow() {
        Task {
            let result = await check()
            let alert = NSAlert()
            switch result {
            case .updateAvailable(let release):
                available = release
                alert.messageText = L10n.updateAvailableTitle(release.version)
                alert.informativeText = L10n.updateAvailableBody(currentVersion ?? "?")
                alert.addButton(withTitle: L10n.updateDownload)
                alert.addButton(withTitle: L10n.updateLater)
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(release.pageURL)
                }
                return
            case .upToDate(let version):
                alert.messageText = L10n.upToDateTitle
                alert.informativeText = L10n.upToDateBody(version)
            case .unknownVersion:
                alert.messageText = L10n.updateCheckFailed
                alert.informativeText = L10n.updateUnknownVersion
            case .failed:
                alert.messageText = L10n.updateCheckFailed
                alert.informativeText = L10n.updateCheckFailedBody
            }
            alert.runModal()
        }
    }

    func download() {
        guard let release = available else { return }
        NSWorkspace.shared.open(release.pageURL)
    }

    /// Hides the banner and stays quiet about this version.
    func skip() {
        defaults.set(available?.version, forKey: Key.skippedVersion)
        available = nil
    }

    func check() async -> CheckResult {
        guard let current = currentVersion else { return .unknownVersion }
        guard let latest = await Self.fetchLatestRelease(currentVersion: current) else { return .failed }
        defaults.set(Date(), forKey: Key.lastCheck)
        return Self.isVersion(latest.version, newerThan: current) ? .updateAvailable(latest) : .upToDate(current)
    }

    nonisolated static func fetchLatestRelease(currentVersion: String) async -> Release? {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("markdownToPdf/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        struct Payload: Decodable {
            let tag_name: String
            let html_url: URL
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return nil }

        let version = payload.tag_name.hasPrefix("v") ? String(payload.tag_name.dropFirst()) : payload.tag_name
        return Release(version: version, pageURL: payload.html_url)
    }

    /// Compares dotted version numbers: "1.10.0" is newer than "1.9.2".
    nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left > right }
        }
        return false
    }
}
