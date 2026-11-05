import Foundation

/// Saved PDFs, kept in `~/Library/Application Support/markdownToPdf/history.json`
/// so the list survives restarts. Only the paths are stored, never the documents.
struct HistoryStore {
    struct Entry: Codable {
        let name: String
        let pdfPath: String
        let date: Date
        let isPasted: Bool
    }

    static let limit = 100

    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        fileURL = support.appendingPathComponent("markdownToPdf/history.json")
    }

    func load() -> [ConversionJob] {
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder.history.decode([Entry].self, from: data) else { return [] }
        return entries.map {
            ConversionJob.restored(
                name: $0.name,
                pdf: URL(fileURLWithPath: $0.pdfPath),
                date: $0.date,
                isPasted: $0.isPasted
            )
        }
    }

    func save(_ jobs: [ConversionJob]) {
        let entries: [Entry] = jobs.compactMap { job in
            guard case .saved(let url) = job.status else { return nil }
            return Entry(name: job.name, pdfPath: url.path, date: job.finishedAt ?? Date(), isPasted: job.isPasted)
        }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.history.encode(Array(entries.suffix(Self.limit)))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // History is a convenience; a failed write must never stop a conversion.
        }
    }
}

private extension JSONEncoder {
    static var history: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var history: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
