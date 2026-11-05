import Foundation

/// Files from `Resources/Web` (highlight.js and its theme).
///
/// In the app bundle they live in `Contents/Resources`; when running from
/// `swift run` or `.build/` they are read from the repository instead.
enum WebResources {
    static let highlightScript = text(named: "highlight.min.js")
    static let highlightStylesheet = text(named: "highlight-github.min.css")

    private static func text(named name: String) -> String {
        let repositoryFolder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Rendering
            .deletingLastPathComponent() // MarkdownToPdf
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // repository root
            .appendingPathComponent("Resources/Web")

        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(name),
            repositoryFolder.appendingPathComponent(name),
        ]
        for case let url? in candidates {
            if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        }
        return ""
    }
}
