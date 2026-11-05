import PDFKit
import SwiftUI

/// The Preview tab: shows a Markdown file or pasted text as the PDF it would become.
struct PreviewView: View {
    @EnvironmentObject private var model: PreviewModel
    @State private var isTargeted = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.fileURL, .plainText], isTargeted: $isTargeted) { providers in
                DropLoader.load(providers) { urls, text in
                    if let text {
                        model.load(text: text)
                    } else {
                        model.load(urls: urls)
                    }
                }
            }
            .overlay {
                if isTargeted, model.document != nil {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                        .padding(8)
                        .allowsHitTesting(false)
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .empty:
            emptyState
        case .loading(let title):
            VStack(spacing: 14) {
                ProgressView().controlSize(.large)
                Text(L10n.previewLoading).font(.title3.weight(.semibold))
                Text(title).font(.callout).foregroundStyle(.secondary).lineLimit(1)
            }
        case .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.orange)
                Text(L10n.previewFailed).font(.title3.weight(.semibold))
                Text(message).font(.callout).foregroundStyle(.secondary)
                Button(L10n.previewStartOver) { model.close() }
            }
            .padding(20)
        case .ready(let document):
            VStack(spacing: 0) {
                PreviewHeader(document: document)
                Divider()
                PDFKitView(document: document.pdf)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: isTargeted ? "arrow.down.doc.fill" : "doc.text.magnifyingglass")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                    .symbolRenderingMode(.hierarchical)
                Text(L10n.previewDropTitle).font(.title3.weight(.semibold))
                Text(L10n.previewDropSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    Button(L10n.previewOpenFile) { model.openFile() }
                    Button {
                        model.pasteFromClipboard()
                    } label: {
                        Label(L10n.pasteFromClipboard, systemImage: "doc.on.clipboard")
                    }
                    .help("⌘V")
                }
                .controlSize(.large)
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                    )
            )

            if let notice = model.notice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }
}

/// Title, page count and actions above the previewed PDF.
private struct PreviewHeader: View {
    @EnvironmentObject private var model: PreviewModel
    let document: PreviewModel.Document

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: document.isPasted ? "doc.on.clipboard" : "doc.text")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(document.title)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(L10n.pageCount(document.pdf.pageCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    model.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help(L10n.previewReload)
                Button {
                    model.close()
                } label: {
                    Image(systemName: "xmark")
                }
                .help(L10n.previewClose)
                Button {
                    model.save()
                } label: {
                    Label(L10n.saveAsPDF, systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .help("⌘S")
            }

            if let saved = model.lastSaved {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(L10n.previewSaved(saved.lastPathComponent)).lineLimit(1).truncationMode(.middle)
                    Button(L10n.menuShowInFinder) {
                        NSWorkspace.shared.activateFileViewerSelecting([saved])
                    }
                    .buttonStyle(.link)
                }
                .font(.callout)
            } else if let notice = model.notice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

/// PDFKit's viewer: scrollable pages, zoom with pinch or ⌘+/⌘−, text selection and copy.
struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.backgroundColor = .underPageBackgroundColor
        view.document = document
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
            view.autoScales = true
        }
    }
}
