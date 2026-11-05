import AppKit
import UniformTypeIdentifiers

/// Holds dropped files and pasted text and converts them strictly one after another.
///
/// A single item: render → ask for a file name and place → save.
/// Several files added together: render the first → ask once for a folder →
/// save every file of that batch into it without asking again.
@MainActor
final class ConversionQueue: ObservableObject {
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn", "txt"]

    @Published private(set) var jobs: [ConversionJob] = []
    @Published private(set) var isProcessing = false
    @Published var notice: String?

    private let renderer = PDFRenderer()
    private let preferences = Preferences.shared
    /// Index (within the current batch) of the file being worked on, for "File 2 of 5".
    private var batchStart = 0
    /// Save folder chosen for each multi-file batch.
    private var batchFolders: [UUID: URL] = [:]
    /// Batches whose folder dialog was cancelled; their remaining files are skipped.
    private var cancelledBatches: Set<UUID> = []

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

        let batch = UUID()
        enqueue(markdown.map { ConversionJob.file($0, batch: batch, batchSize: markdown.count) })
    }

    /// Converts Markdown text, e.g. from the clipboard.
    func addText(_ markdown: String) {
        notice = nil
        enqueue([ConversionJob.text(markdown)])
    }

    /// Adds what is on the clipboard: copied Markdown files, or Markdown text.
    func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []

        if !fileURLs.isEmpty {
            add(fileURLs)
        } else if let text = pasteboard.string(forType: .string),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            addText(text)
        } else {
            notice = L10n.clipboardEmpty
        }
    }

    private func enqueue(_ newJobs: [ConversionJob]) {
        if !isProcessing {
            batchStart = jobs.count
        }
        jobs.append(contentsOf: newJobs)
        if !isProcessing {
            Task { await processQueue() }
        }
    }

    /// Lets the user pick the folder for the "always save to this folder" mode.
    func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.message = L10n.chooseSaveFolderMessage
        panel.prompt = L10n.chooseButton
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = preferences.saveFolder
        if panel.runModal() == .OK, let url = panel.url {
            preferences.saveFolder = url
            preferences.saveMode = .folder
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
        batchFolders.removeAll()
        cancelledBatches.removeAll()
    }

    private func process(at index: Int) async {
        let job = jobs[index]
        let id = job.id
        if cancelledBatches.contains(job.batch) {
            setStatus(.skipped, for: id)
            return
        }
        let temporaryPDF = FileManager.default.temporaryDirectory
            .appendingPathComponent("markdownToPdf-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: temporaryPDF) }

        setStatus(.converting, for: id)
        do {
            let started = Date()
            switch job.input {
            case .file(let url):
                try await renderer.render(url, to: temporaryPDF)
            case .text(let markdown):
                try await renderer.render(
                    markdown: markdown,
                    title: job.baseName,
                    baseURL: FileManager.default.homeDirectoryForCurrentUser,
                    to: temporaryPDF
                )
            }
            // Keep the loading screen up long enough to be read rather than flash.
            let elapsed = Date().timeIntervalSince(started)
            if elapsed < 0.6 {
                try? await Task.sleep(nanoseconds: UInt64((0.6 - elapsed) * 1_000_000_000))
            }
        } catch {
            setStatus(.failed(error.localizedDescription), for: id)
            return
        }

        guard let destination = await destination(for: job) else {
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
            preferences.lastSaveFolder = destination.deletingLastPathComponent()
            setStatus(.saved(destination), for: id)
        } catch {
            setStatus(.failed(L10n.errorSave), for: id)
        }
    }

    /// Where the PDF for `job` goes, following the save setting.
    /// In "ask" mode a single file gets a save dialog and a batch is asked for a
    /// folder once; the other modes never ask unless their folder is missing.
    private func destination(for job: ConversionJob) async -> URL? {
        switch preferences.saveMode {
        case .nextToSource:
            // Pasted text has no file to sit next to, so it falls through to asking.
            if let folder = job.sourceFolder {
                return Self.uniquePDFURL(in: folder, named: job.baseName)
            }
        case .folder:
            if let folder = preferences.existingSaveFolder {
                return Self.uniquePDFURL(in: folder, named: job.baseName)
            }
            notice = L10n.saveFolderMissing
        case .ask:
            break
        }

        guard job.isPartOfBatch else {
            setStatus(.awaitingSave, for: job.id)
            return await askForDestination(for: job)
        }

        if let folder = batchFolders[job.batch] {
            return Self.uniquePDFURL(in: folder, named: job.baseName)
        }

        setStatus(.awaitingSave, for: job.id)
        guard let folder = await askForFolder(for: job) else {
            cancelledBatches.insert(job.batch)
            return nil
        }
        batchFolders[job.batch] = folder
        return Self.uniquePDFURL(in: folder, named: job.baseName)
    }

    /// `notes.pdf`, or `notes 2.pdf`, `notes 3.pdf`… so saves without a dialog never overwrite a file.
    static func uniquePDFURL(in folder: URL, named base: String) -> URL {
        var candidate = folder.appendingPathComponent(base).appendingPathExtension("pdf")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(counter)").appendingPathExtension("pdf")
            counter += 1
        }
        return candidate
    }

    private func askForFolder(for job: ConversionJob) async -> URL? {
        let panel = NSOpenPanel()
        panel.title = L10n.folderPanelTitle
        panel.message = L10n.folderPanelMessage(job.batchSize)
        panel.prompt = L10n.savePanelButton
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = startFolder(for: job)
        return await present(panel) == .OK ? panel.url : nil
    }

    /// Where dialogs open: the Markdown file's folder, else the last folder used, else the Desktop.
    private func startFolder(for job: ConversionJob) -> URL? {
        job.sourceFolder
            ?? preferences.lastSaveFolder
            ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }

    private func askForDestination(for job: ConversionJob) async -> URL? {
        let panel = NSSavePanel()
        panel.title = L10n.savePanelTitle
        panel.prompt = L10n.savePanelButton
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.directoryURL = startFolder(for: job)
        panel.nameFieldStringValue = job.baseName + ".pdf"

        return await present(panel) == .OK ? panel.url : nil
    }

    /// Shows a save/open panel as a sheet on the main window (or on its own if there is none).
    private func present(_ panel: NSSavePanel) async -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
            return await panel.beginSheetModal(for: window)
        }
        return panel.runModal()
    }

    private func setStatus(_ status: ConversionJob.Status, for id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].status = status
    }
}
