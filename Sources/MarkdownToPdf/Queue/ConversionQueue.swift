import AppKit
import UniformTypeIdentifiers

struct ConversionJob: Identifiable, Equatable {
    enum Status: Equatable {
        case waiting
        case converting
        case awaitingSave
        case saved(URL)
        case skipped
        case failed(String)

        var isFinished: Bool {
            switch self {
            case .saved, .skipped, .failed: return true
            case .waiting, .converting, .awaitingSave: return false
            }
        }
    }

    let id = UUID()
    let source: URL
    var status: Status = .waiting

    var name: String { source.lastPathComponent }
}

/// Holds dropped files and converts them strictly one after another:
/// render → ask where to save → save → next file.
@MainActor
final class ConversionQueue: ObservableObject {
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn", "txt"]

    @Published private(set) var jobs: [ConversionJob] = []
    @Published private(set) var isProcessing = false
    @Published var notice: String?

    private let renderer = PDFRenderer()
    /// Index (within the current batch) of the file being worked on, for "File 2 of 5".
    private var batchStart = 0

    var activeJob: ConversionJob? {
        jobs.first { $0.status == .converting || $0.status == .awaitingSave }
    }

    /// Position of the active file and size of the current batch.
    var batchProgress: (current: Int, total: Int) {
        let batch = jobs[batchStart...]
        let done = batch.filter { $0.status.isFinished }.count
        return (min(done + 1, batch.count), batch.count)
    }

    var hasFinishedJobs: Bool { jobs.contains { $0.status.isFinished } }

    // MARK: - Adding files

    func add(_ urls: [URL]) {
        let markdown = urls.filter { Self.markdownExtensions.contains($0.pathExtension.lowercased()) }
        notice = markdown.count < urls.count ? L10n.unsupportedFiles : nil
        guard !markdown.isEmpty else { return }

        if !isProcessing {
            batchStart = jobs.count
        }
        jobs.append(contentsOf: markdown.map { ConversionJob(source: $0) })

        if !isProcessing {
            Task { await processQueue() }
        }
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.message = L10n.openPanelMessage
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Self.markdownExtensions.compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK {
            add(panel.urls)
        }
    }

    func clearFinished() {
        jobs.removeAll { $0.status.isFinished }
        batchStart = jobs.firstIndex { !$0.status.isFinished } ?? jobs.count
    }

    // MARK: - Processing

    private func processQueue() async {
        isProcessing = true
        defer { isProcessing = false }

        while let index = jobs.firstIndex(where: { $0.status == .waiting }) {
            await process(at: index)
        }
    }

    private func process(at index: Int) async {
        let source = jobs[index].source
        let id = jobs[index].id
        let temporaryPDF = FileManager.default.temporaryDirectory
            .appendingPathComponent("markdownToPdf-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: temporaryPDF) }

        setStatus(.converting, for: id)
        do {
            let started = Date()
            try await renderer.render(source, to: temporaryPDF)
            // Keep the loading screen up long enough to be read rather than flash.
            let elapsed = Date().timeIntervalSince(started)
            if elapsed < 0.6 {
                try? await Task.sleep(nanoseconds: UInt64((0.6 - elapsed) * 1_000_000_000))
            }
        } catch {
            setStatus(.failed(error.localizedDescription), for: id)
            return
        }

        setStatus(.awaitingSave, for: id)
        guard let destination = await askForDestination(for: source) else {
            setStatus(.skipped, for: id)
            return
        }

        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: temporaryPDF)
            } else {
                try fileManager.moveItem(at: temporaryPDF, to: destination)
            }
            setStatus(.saved(destination), for: id)
        } catch {
            setStatus(.failed(L10n.errorSave), for: id)
        }
    }

    private func askForDestination(for source: URL) async -> URL? {
        let panel = NSSavePanel()
        panel.title = L10n.savePanelTitle
        panel.prompt = L10n.savePanelButton
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.directoryURL = source.deletingLastPathComponent()
        panel.nameFieldStringValue = source.deletingPathExtension().lastPathComponent + ".pdf"

        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
            let response = await panel.beginSheetModal(for: window)
            return response == .OK ? panel.url : nil
        }
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func setStatus(_ status: ConversionJob.Status, for id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].status = status
    }
}
