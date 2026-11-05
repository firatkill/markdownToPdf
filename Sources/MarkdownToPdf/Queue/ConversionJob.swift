import Foundation

/// One thing to turn into a PDF: a Markdown file, or Markdown text from the clipboard.
struct ConversionJob: Identifiable, Equatable {
    enum Input: Equatable {
        case file(URL)
        case text(String)
        /// Loaded from the history list; there is nothing left to convert.
        case history
    }

    enum Status: Equatable {
        case waiting
        case converting
        case awaitingSave
        /// Converted and waiting for the other files it will be merged with.
        case converted
        case saved(URL)
        case skipped
        case failed(String)

        var isFinished: Bool {
            switch self {
            case .saved, .skipped, .failed: return true
            case .waiting, .converting, .awaitingSave, .converted: return false
            }
        }
    }

    let id = UUID()
    let input: Input
    /// Shown in the list.
    let name: String
    /// File name of the PDF without extension.
    let baseName: String
    /// Items added together (one drop, one Open panel) share a batch and a save folder.
    let batch: UUID
    let batchSize: Int
    /// Came from the clipboard or a text service rather than a file.
    let isPasted: Bool
    /// Part of a batch that becomes a single PDF.
    var merge = false
    var status: Status = .waiting
    /// When the PDF was saved.
    var finishedAt: Date?

    var isPartOfBatch: Bool { batchSize > 1 }

    var sourceURL: URL? {
        if case .file(let url) = input { return url }
        return nil
    }

    /// Folder of the Markdown file; `nil` for pasted text.
    var sourceFolder: URL? { sourceURL?.deletingLastPathComponent() }

    static func file(_ url: URL, batch: UUID, batchSize: Int) -> ConversionJob {
        ConversionJob(
            input: .file(url),
            name: url.lastPathComponent,
            baseName: url.deletingPathExtension().lastPathComponent,
            batch: batch,
            batchSize: batchSize,
            isPasted: false
        )
    }

    static func restored(name: String, pdf: URL, date: Date, isPasted: Bool) -> ConversionJob {
        ConversionJob(
            input: .history,
            name: name,
            baseName: pdf.deletingPathExtension().lastPathComponent,
            batch: UUID(),
            batchSize: 1,
            isPasted: isPasted,
            status: .saved(pdf),
            finishedAt: date
        )
    }

    static func text(_ markdown: String) -> ConversionJob {
        let title = suggestedTitle(for: markdown)
        return ConversionJob(
            input: .text(markdown),
            name: title,
            baseName: title,
            batch: UUID(),
            batchSize: 1,
            isPasted: true
        )
    }

    /// The first heading (or first line) of the text, usable as a file name.
    static func suggestedTitle(for markdown: String) -> String {
        let lines = markdown.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        let heading = lines.first { $0.hasPrefix("#") }.map { $0.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces) }
        let candidate = heading ?? lines.first { !$0.isEmpty } ?? ""

        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        var cleaned = candidate.unicodeScalars.map { forbidden.contains($0) ? " " : String($0) }.joined()
        cleaned = cleaned.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        if cleaned.count > 60 {
            cleaned = String(cleaned.prefix(60)).trimmingCharacters(in: .whitespaces)
        }
        return cleaned.isEmpty ? L10n.pastedTextName : cleaned
    }
}
