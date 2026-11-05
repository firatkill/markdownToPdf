import AppKit
import PDFKit
import UniformTypeIdentifiers

/// The Preview tab: a Markdown editor on the left and its live PDF on the right.
/// The editor text is the source; every change re-renders the PDF shortly after typing stops.
/// Nothing is written to disk until the user clicks "Save as PDF".
@MainActor
final class PreviewModel: ObservableObject {
    /// What is being edited. Changing it schedules a new render.
    @Published var text = "" {
        didSet {
            guard text != oldValue else { return }
            scheduleRender()
        }
    }

    /// The Markdown file the text was loaded from, if any. Its folder resolves relative
    /// image paths and is where the save dialog opens. The file itself is never changed.
    @Published private(set) var sourceURL: URL?
    @Published private(set) var pdf: PDFDocument?
    @Published private(set) var isRendering = false
    @Published private(set) var renderError: String?
    /// The PDF pane covers the editor.
    @Published var isExpanded = false
    @Published var notice: String?
    /// The last PDF saved from the preview, for the "Show in Finder" link.
    @Published private(set) var lastSaved: URL?

    private let renderer = PDFRenderer()
    private let preferences = Preferences.shared
    private weak var queue: ConversionQueue?

    private var pdfURL: URL?
    /// The text the current `pdf` was made from.
    private var renderedText: String?
    private var debounceTask: Task<Void, Never>?
    /// Renders run one after another on the shared web view.
    private var renderTask: Task<Void, Never>?

    private static let debounce: UInt64 = 450_000_000

    init(queue: ConversionQueue) {
        self.queue = queue
    }

    var hasContent: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Name for the PDF: the file's name, or the first heading of the text.
    var title: String {
        if let sourceURL { return sourceURL.deletingPathExtension().lastPathComponent }
        return ConversionJob.suggestedTitle(for: text)
    }

    // MARK: - Input

    func open(_ url: URL) {
        do {
            let content = try PDFRenderer.readText(at: url)
            sourceURL = url
            notice = nil
            lastSaved = nil
            text = content
            renderSoon(immediately: true)
        } catch {
            notice = error.localizedDescription
        }
    }

    func load(urls: [URL]) {
        guard let markdown = urls.first(where: {
            ConversionQueue.markdownExtensions.contains($0.pathExtension.lowercased())
        }) else {
            notice = L10n.unsupportedFiles
            return
        }
        open(markdown)
        if urls.count > 1 { notice = L10n.previewShowsOne }
    }

    /// Text dropped or pasted outside the editor: replaces an empty editor, otherwise is added at the end.
    func insert(text newText: String) {
        notice = nil
        if hasContent {
            text += (text.hasSuffix("\n") ? "\n" : "\n\n") + newText
        } else {
            sourceURL = nil
            text = newText
            renderSoon(immediately: true)
        }
    }

    /// ⌘V while the editor does not have focus.
    func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []

        if !fileURLs.isEmpty {
            load(urls: fileURLs)
        } else if let clip = pasteboard.string(forType: .string),
                  !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            insert(text: clip)
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
        if panel.runModal() == .OK, let url = panel.url {
            open(url)
        }
    }

    /// Empties the editor and hides the PDF.
    func clear() {
        sourceURL = nil
        notice = nil
        lastSaved = nil
        isExpanded = false
        text = ""
    }

    // MARK: - Rendering

    private func scheduleRender() {
        lastSaved = nil
        renderSoon(immediately: false)
    }

    private func renderSoon(immediately: Bool) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            if !immediately {
                try? await Task.sleep(nanoseconds: Self.debounce)
            }
            guard !Task.isCancelled else { return }
            await self?.renderNow()
        }
    }

    /// Renders the current text, after any render already running.
    func renderNow() async {
        let snapshot = text
        let previous = renderTask
        let task = Task { [weak self] in
            await previous?.value
            await self?.render(snapshot)
        }
        renderTask = task
        await task.value
    }

    private func render(_ snapshot: String) async {
        // A newer edit already queued its own render; skip this one.
        guard snapshot == text, snapshot != renderedText else { return }

        guard hasContent else {
            replacePDF(with: nil, url: nil, text: snapshot)
            renderError = nil
            return
        }

        isRendering = true
        defer { isRendering = false }

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("markdownToPdf-preview-\(UUID().uuidString).pdf")
        do {
            try await renderer.render(
                markdown: snapshot,
                title: title,
                baseURL: sourceURL?.deletingLastPathComponent() ?? FileManager.default.homeDirectoryForCurrentUser,
                to: output
            )
            guard let document = PDFDocument(url: output) else { throw PDFRendererError.printFailed }
            replacePDF(with: document, url: output, text: snapshot)
            renderError = nil
        } catch {
            try? FileManager.default.removeItem(at: output)
            renderError = error.localizedDescription
        }
    }

    private func replacePDF(with document: PDFDocument?, url: URL?, text: String) {
        if let old = pdfURL { try? FileManager.default.removeItem(at: old) }
        pdf = document
        pdfURL = url
        renderedText = text
    }

    // MARK: - Saving

    /// Makes sure the PDF matches the editor, asks where to save and copies it there.
    func save() {
        guard hasContent else { return }
        Task {
            debounceTask?.cancel()
            await renderNow()
            guard let pdfURL, renderedText == text else { return }

            let panel = NSSavePanel()
            panel.title = L10n.savePanelTitle
            panel.prompt = L10n.savePanelButton
            panel.allowedContentTypes = [.pdf]
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            panel.nameFieldStringValue = title + ".pdf"
            panel.directoryURL = sourceURL?.deletingLastPathComponent()
                ?? preferences.lastSaveFolder
                ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first

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
                try fileManager.copyItem(at: pdfURL, to: destination)
                preferences.lastSaveFolder = destination.deletingLastPathComponent()
                lastSaved = destination
                notice = nil
                queue?.recordSaved(
                    name: sourceURL?.lastPathComponent ?? title,
                    pdf: destination,
                    isPasted: sourceURL == nil
                )
            } catch {
                notice = L10n.errorSave
            }
        }
    }
}
