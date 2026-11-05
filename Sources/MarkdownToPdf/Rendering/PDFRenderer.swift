import AppKit
import WebKit

enum PDFRendererError: LocalizedError {
    case unreadableFile
    case loadFailed(String)
    case printFailed

    var errorDescription: String? {
        switch self {
        case .unreadableFile: return L10n.errorUnreadable
        case .loadFailed(let reason): return reason
        case .printFailed: return L10n.errorPrint
        }
    }
}

/// Renders Markdown files to paginated A4 PDFs using WebKit's print engine.
///
/// A single hidden web view is reused for every document, so files must be
/// rendered one at a time (the conversion queue guarantees this).
@MainActor
final class PDFRenderer: NSObject {
    /// A4 in PostScript points.
    private static let paperSize = NSSize(width: 595.28, height: 841.89)
    private static let margin: CGFloat = 54 // 0.75 inch

    private let window: NSWindow
    private let webView: WKWebView
    private var loadContinuation: CheckedContinuation<Void, Error>?
    private var printContinuation: CheckedContinuation<Bool, Never>?

    override init() {
        let contentWidth = Self.paperSize.width - Self.margin * 2
        let frame = NSRect(x: 0, y: 0, width: contentWidth, height: 800)

        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        webView = WKWebView(frame: frame, configuration: configuration)

        // WebKit only prints from a view that lives in a window, so keep one off-screen.
        window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: frame.width, height: frame.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = webView

        super.init()
        webView.navigationDelegate = self
    }

    /// Converts `source` (a Markdown file) into a PDF written to `destination`.
    func render(_ source: URL, to destination: URL) async throws {
        try await render(
            markdown: try Self.readText(at: source),
            title: source.deletingPathExtension().lastPathComponent,
            baseURL: source.deletingLastPathComponent(),
            to: destination
        )
    }

    /// Converts Markdown text into a PDF. Relative image paths resolve against `baseURL`.
    func render(markdown: String, title: String, baseURL: URL, to destination: URL) async throws {
        let html = MarkdownHTML.document(from: markdown, title: title, baseURL: baseURL)

        let htmlURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("markdownToPdf-\(UUID().uuidString).html")
        try html.write(to: htmlURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        try await load(htmlURL)
        try await printPDF(to: destination)
    }

    // MARK: - Steps

    private static func readText(at url: URL) throws -> String {
        guard let data = try? Data(contentsOf: url) else { throw PDFRendererError.unreadableFile }
        for encoding in [String.Encoding.utf8, .utf16, .windowsCP1254, .isoLatin1] {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        throw PDFRendererError.unreadableFile
    }

    private func load(_ htmlURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            loadContinuation = continuation
            // Read access to the whole disk lets relative and absolute image paths load.
            webView.loadFileURL(htmlURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        }
    }

    private func printPDF(to destination: URL) async throws {
        try? FileManager.default.removeItem(at: destination)

        let printInfo = NSPrintInfo(dictionary: [.jobSavingURL: destination])
        printInfo.jobDisposition = .save
        printInfo.paperSize = Self.paperSize
        printInfo.orientation = .portrait
        printInfo.topMargin = Self.margin
        printInfo.bottomMargin = Self.margin
        printInfo.leftMargin = Self.margin
        printInfo.rightMargin = Self.margin
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        let operation = webView.printOperation(with: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        // Without an explicit frame WebKit produces blank pages.
        operation.view?.frame = webView.bounds

        let success = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            printContinuation = continuation
            operation.runModal(
                for: window,
                delegate: self,
                didRun: #selector(printOperationDidRun(_:success:contextInfo:)),
                contextInfo: nil
            )
        }

        guard success, FileManager.default.fileExists(atPath: destination.path) else {
            throw PDFRendererError.printFailed
        }
    }

    @objc private func printOperationDidRun(
        _ operation: NSPrintOperation,
        success: Bool,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        printContinuation?.resume(returning: success)
        printContinuation = nil
    }

    private func finishLoad(with error: Error?) {
        guard let continuation = loadContinuation else { return }
        loadContinuation = nil
        if let error {
            continuation.resume(throwing: PDFRendererError.loadFailed(error.localizedDescription))
        } else {
            continuation.resume()
        }
    }
}

extension PDFRenderer: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishLoad(with: nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishLoad(with: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishLoad(with: error)
    }

    /// Links inside the document must never navigate the hidden web view away.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(navigationAction.navigationType == .linkActivated ? .cancel : .allow)
    }
}
