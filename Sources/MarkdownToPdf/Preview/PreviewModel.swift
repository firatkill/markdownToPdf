import AppKit
import PDFKit
import UniformTypeIdentifiers

/// The Preview tab: renders one Markdown file or pasted text to a PDF and shows it,
/// without saving anything until the user clicks "Save as PDF".
@MainActor
final class PreviewModel: ObservableObject {
    struct Document {
        let title: String
        let sourceURL: URL?
        let markdown: String?
        let pdfURL: URL
        let pdf: PDFDocument

        var isPasted: Bool { sourceURL == nil }
    }

    enum State {
        case empty
        case loading(String)
        case ready(Document)
        case failed(String)
    }

    @Published private(set) var state: State = .empty
    @Published var notice: String?
    /// The last PDF saved from the preview, for the "Show in Finder" link.
    @Published private(set) var lastSaved: URL?

    private let renderer = PDFRenderer()
    private let preferences = Preferences.shared
    private weak var queue: ConversionQueue?
    /// Renders run one after another on the shared web view; only the newest result is shown.
    private var renderTask: Task<Void, Never>?
    private var latestRequest = UUID()

    init(queue: ConversionQueue) {
        self.queue = queue
    }

    var document: Document? {
        if case .ready(let document) = state { return document }
        return nil
    }

    // MARK: - Loading

    func load(urls: [URL]) {
        let markdown = urls.filter { ConversionQueue.markdownExtensions.contains($0.pathExtension.lowercased()) }
        guard let first = markdown.first else {
            notice = L10n.unsupportedFiles
            return
        }
        notice = markdown.count > 1 ? L10n.previewShowsOne : nil
        let title = first.deletingPathExtension().lastPathComponent
        render(title: title, sourceURL: first, markdown: nil) { renderer, output in
            try await renderer.render(first, to: output)
        }
    }

    func load(text: String) {
        notice = nil
        let title = ConversionJob.suggestedTitle(for: text)
        render(title: title, sourceURL: nil, markdown: text) { renderer, output in
            try await renderer.render(
                markdown: text,
                title: title,
                baseURL: FileManager.default.homeDirectoryForCurrentUser,
                to: output
            )
        }
    }

    /// Shows what is on the clipboard: a copied Markdown file, or Markdown text.
    func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []

        if !fileURLs.isEmpty {
            load(urls: fileURLs)
        } else if let text = pasteboard.string(forType: .string),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            load(text: text)
        } else {
            notice = L10n.clipboardEmpty
        }
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.message = L10n.previewOpenMessage
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = ConversionQueue.markdownExtensions.compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK {
            load(urls: panel.urls)
        }
    }

    /// Renders the same file again, e.g. after editing it.
    func reload() {
        guard let document else { return }
        if let url = document.sourceURL {
            load(urls: [url])
        } else if let text = document.markdown {
            load(text: text)
        }
    }

    func close() {
        latestRequest = UUID()
        removeTemporaryFile()
        state = .empty
        notice = nil
        lastSaved = nil
    }

    private func render(
        title: String,
        sourceURL: URL?,
        markdown: String?,
        work: @escaping @MainActor (PDFRenderer, URL) async throws -> Void
    ) {
        let request = UUID()
        latestRequest = request
        lastSaved = nil
        state = .loading(title)

        let previous = renderTask
        renderTask = Task { [weak self] in
            await previous?.value
            guard let self, self.latestRequest == request else { return }

            let output = FileManager.default.temporaryDirectory
                .appendingPathComponent("markdownToPdf-preview-\(UUID().uuidString).pdf")
            do {
                try await work(self.renderer, output)
                guard let pdf = PDFDocument(url: output) else { throw PDFRendererError.printFailed }
                guard self.latestRequest == request else {
                    try? FileManager.default.removeItem(at: output)
                    return
                }
                self.removeTemporaryFile()
                self.state = .ready(Document(
                    title: title,
                    sourceURL: sourceURL,
                    markdown: markdown,
                    pdfURL: output,
                    pdf: pdf
                ))
            } catch {
                try? FileManager.default.removeItem(at: output)
                guard self.latestRequest == request else { return }
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    private func removeTemporaryFile() {
        if let document {
            try? FileManager.default.removeItem(at: document.pdfURL)
        }
    }

    // MARK: - Saving

    /// Asks where to save and copies the previewed PDF there.
    func save() {
        guard let document else { return }

        let panel = NSSavePanel()
        panel.title = L10n.savePanelTitle
        panel.prompt = L10n.savePanelButton
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = document.title + ".pdf"
        panel.directoryURL = document.sourceURL?.deletingLastPathComponent()
            ?? preferences.lastSaveFolder
            ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first

        Task {
            let response: NSApplication.ModalResponse
            if let window = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
                response = await panel.beginSheetModal(for: window)
            } else {
                response = panel.runModal()
            }
            guard response == .OK, let destination = panel.url else { return }

            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: document.pdfURL, to: destination)
                preferences.lastSaveFolder = destination.deletingLastPathComponent()
                lastSaved = destination
                notice = nil
                queue?.recordSaved(
                    name: document.sourceURL?.lastPathComponent ?? document.title,
                    pdf: destination,
                    isPasted: document.isPasted
                )
            } catch {
                notice = L10n.errorSave
            }
        }
    }
}
