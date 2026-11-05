import AppKit
import SwiftUI

/// A plain-text Markdown editor: monospaced, no smart quotes or autocorrect.
/// Dropping or pasting a Markdown *file* loads its contents instead of inserting its path;
/// text dropped or pasted from other apps goes in as usual.
struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var onOpenFile: (URL) -> Void
    var onUnsupportedFile: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let textView = MarkdownTextView(frame: .zero)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 12, height: 14)
        textView.registerForDraggedTypes([.fileURL, .string])

        textView.delegate = context.coordinator
        textView.onFiles = { urls in context.coordinator.handleFiles(urls) }
        textView.string = text

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else { return }
        let selection = textView.selectedRanges
        textView.string = text
        let length = (text as NSString).length
        textView.selectedRanges = selection.compactMap { value in
            let range = value.rangeValue
            guard range.location <= length else { return nil }
            return NSValue(range: NSRange(location: range.location, length: min(range.length, length - range.location)))
        }
        if textView.selectedRanges.isEmpty {
            textView.setSelectedRange(NSRange(location: length, length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor

        init(_ parent: MarkdownEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        /// Loads the first Markdown file, or reports that none was dropped.
        func handleFiles(_ urls: [URL]) {
            let markdown = urls.first { ConversionQueue.markdownExtensions.contains($0.pathExtension.lowercased()) }
            if let markdown {
                parent.onOpenFile(markdown)
            } else {
                parent.onUnsupportedFile()
            }
        }
    }
}

/// NSTextView that turns dropped or pasted files into "open this file".
final class MarkdownTextView: NSTextView {
    var onFiles: (([URL]) -> Void)?

    private func fileURLs(in pasteboard: NSPasteboard) -> [URL] {
        pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if !fileURLs(in: sender.draggingPasteboard).isEmpty { return .copy }
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if !fileURLs(in: sender.draggingPasteboard).isEmpty { return .copy }
        return super.draggingUpdated(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(in: sender.draggingPasteboard)
        guard !urls.isEmpty else { return super.performDragOperation(sender) }
        onFiles?(urls)
        return true
    }

    override func paste(_ sender: Any?) {
        let urls = fileURLs(in: .general)
        if !urls.isEmpty {
            onFiles?(urls)
        } else {
            pasteAsPlainText(sender)
        }
    }
}
