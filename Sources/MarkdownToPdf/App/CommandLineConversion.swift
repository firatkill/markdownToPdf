import Foundation

/// `markdownToPdf --convert input.md output.pdf` converts without showing any UI.
/// Handy for scripts and for testing the renderer.
struct CommandLineConversion {
    let input: URL
    let output: URL

    static func parse(_ arguments: [String]) -> CommandLineConversion? {
        guard let flag = arguments.firstIndex(of: "--convert"), arguments.count > flag + 2 else { return nil }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return CommandLineConversion(
            input: URL(fileURLWithPath: arguments[flag + 1], relativeTo: cwd).standardizedFileURL,
            output: URL(fileURLWithPath: arguments[flag + 2], relativeTo: cwd).standardizedFileURL
        )
    }

    @MainActor
    func run() async -> Int32 {
        do {
            try await PDFRenderer().render(input, to: output)
            print("Saved \(output.path)")
            return 0
        } catch {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            return 1
        }
    }
}
