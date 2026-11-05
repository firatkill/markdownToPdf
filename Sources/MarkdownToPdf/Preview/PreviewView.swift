import PDFKit
import SwiftUI

/// The Preview tab: a Markdown editor on the left, its live PDF on the right.
/// The PDF pane appears once there is text and can expand over the editor.
struct PreviewView: View {
    @EnvironmentObject private var model: PreviewModel

    var body: some View {
        GeometryReader { geometry in
            let half = (geometry.size.width / 2).rounded()
            ZStack(alignment: .topLeading) {
                // The editor stays in place (keeping focus and undo); the PDF pane covers part of it.
                EditorPane()
                    .frame(width: model.hasContent ? half : geometry.size.width)

                if model.hasContent {
                    PDFPane()
                        .frame(width: model.isExpanded ? geometry.size.width : geometry.size.width - half)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .transition(.move(edge: .trailing))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .animation(.easeInOut(duration: 0.22), value: model.isExpanded)
        .animation(.easeInOut(duration: 0.22), value: model.hasContent)
    }
}

// MARK: - Editor

private struct EditorPane: View {
    @EnvironmentObject private var model: PreviewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: model.sourceURL == nil ? "square.and.pencil" : "doc.text")
                    .foregroundStyle(.secondary)
                Text(model.hasContent ? model.title : L10n.editorTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(L10n.previewOpenFile) { model.openFile() }
                if model.hasContent {
                    Button {
                        model.clear()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help(L10n.editorClear)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)

            Divider()

            ZStack(alignment: .topLeading) {
                MarkdownEditor(
                    text: $model.text,
                    onOpenFile: { model.open($0) },
                    onUnsupportedFile: { model.notice = L10n.unsupportedFiles }
                )

                if !model.hasContent {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text(L10n.editorPlaceholderTitle)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(L10n.editorPlaceholder)
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 360)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }
            }

            if let notice = model.notice {
                Divider()
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - PDF

private struct PDFPane: View {
    @EnvironmentObject private var model: PreviewModel
    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            Divider()
            VStack(spacing: 0) {
                header
                Divider()
                ZStack {
                    Color(nsColor: .underPageBackgroundColor)
                    if let pdf = model.pdf {
                        PDFKitView(document: pdf, isExpanded: model.isExpanded)
                    } else if let error = model.renderError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ProgressView()
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [.fileURL, .plainText], isTargeted: $isTargeted) { providers in
            DropLoader.load(providers) { urls, text in
                if let text {
                    model.insert(text: text)
                } else {
                    model.load(urls: urls)
                }
            }
        }
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("PDF").font(.headline)
                Group {
                    if let saved = model.lastSaved {
                        Button(L10n.previewSaved(saved.lastPathComponent)) {
                            NSWorkspace.shared.activateFileViewerSelecting([saved])
                        }
                        .buttonStyle(.link)
                        .help(L10n.menuShowInFinder)
                    } else if let pdf = model.pdf {
                        Text(L10n.pageCount(pdf.pageCount)).foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .lineLimit(1)
            }
            if model.isRendering {
                ProgressView().controlSize(.small)
            }
            Spacer()
            Button {
                model.save()
            } label: {
                Label(L10n.saveAsPDF, systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .help("⌘S")
            Button {
                model.isExpanded.toggle()
            } label: {
                Image(systemName: model.isExpanded
                      ? "arrow.down.right.and.arrow.up.left"
                      : "arrow.up.left.and.arrow.down.right")
            }
            .help(model.isExpanded ? L10n.previewCollapse : L10n.previewExpand)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }
}

/// PDFKit's viewer: scrollable pages, zoom with pinch or ⌘+/⌘−, text selection and copy.
/// When the document is replaced (after an edit) or the pane is resized (expand/collapse),
/// it stays on the same page and position.
struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument
    let isExpanded: Bool

    final class Coordinator {
        var isExpanded = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.backgroundColor = .underPageBackgroundColor
        view.document = document
        context.coordinator.isExpanded = isExpanded
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if context.coordinator.isExpanded != isExpanded {
            context.coordinator.isExpanded = isExpanded
            keepPosition(of: view)
        }
        guard view.document !== document else { return }

        let oldDocument = view.document
        let pageIndex = view.currentPage.flatMap { oldDocument?.index(for: $0) } ?? 0
        let point = view.currentDestination?.point
        let scale = view.scaleFactor
        let autoScales = view.autoScales

        view.document = document
        if autoScales {
            view.autoScales = true
        } else {
            view.scaleFactor = scale
        }
        if document.pageCount > 0, let point,
           let page = document.page(at: min(pageIndex, document.pageCount - 1)) {
            view.go(to: PDFDestination(page: page, at: point))
        }
    }

    /// Autoscaling after a width change zooms around the centre; jump back to what was at the top.
    private func keepPosition(of view: PDFView) {
        guard let page = view.currentPage, let point = view.currentDestination?.point else { return }
        let destination = PDFDestination(page: page, at: point)
        // After the expand/collapse animation has resized the view.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            view.go(to: destination)
        }
    }
}
