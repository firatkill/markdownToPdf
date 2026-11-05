import Foundation

/// Window-less use, handy for scripts and for testing the renderer:
///
///     markdownToPdf --convert input.md output.pdf
///     markdownToPdf --merge output.pdf first.md second.md …
///     markdownToPdf --check-for-updates
struct CommandLineConversion {
    let inputs: [URL]
    let output: URL
    let merge: Bool
    var checkForUpdates = false

    static func parse(_ arguments: [String]) -> CommandLineConversion? {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        func url(_ path: String) -> URL { URL(fileURLWithPath: path, relativeTo: cwd).standardizedFileURL }

        if arguments.contains("--check-for-updates") {
            return CommandLineConversion(inputs: [], output: cwd, merge: false, checkForUpdates: true)
        }
        if let flag = arguments.firstIndex(of: "--convert"), arguments.count > flag + 2 {
            return CommandLineConversion(inputs: [url(arguments[flag + 1])], output: url(arguments[flag + 2]), merge: false)
        }
        if let flag = arguments.firstIndex(of: "--merge"), arguments.count > flag + 2 {
            let inputs = arguments[(flag + 2)...].map(url)
            return CommandLineConversion(inputs: inputs, output: url(arguments[flag + 1]), merge: true)
        }
        return nil
    }

    @MainActor
    func run() async -> Int32 {
        if checkForUpdates {
            switch await UpdateChecker.shared.check() {
            case .updateAvailable(let release):
                print("Update available: \(release.version) \(release.pageURL.absoluteString)")
            case .upToDate(let version):
                print("Up to date: \(version)")
            case .unknownVersion:
                print("Unknown version (not running from the app bundle)")
            case .failed:
                print("Could not reach GitHub")
                return 1
            }
            return 0
        }

        let renderer = PDFRenderer()
        do {
            if merge {
                var parts: [(title: String, url: URL)] = []
                defer { parts.forEach { try? FileManager.default.removeItem(at: $0.url) } }
                for input in inputs {
                    let part = FileManager.default.temporaryDirectory
                        .appendingPathComponent("markdownToPdf-\(UUID().uuidString).pdf")
                    try await renderer.render(input, to: part)
                    parts.append((input.deletingPathExtension().lastPathComponent, part))
                }
                try PDFMerger.merge(parts, into: output)
            } else {
                try await renderer.render(inputs[0], to: output)
            }
            print("Saved \(output.path)")
            return 0
        } catch {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            return 1
        }
    }
}
