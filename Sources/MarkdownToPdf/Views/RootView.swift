import SwiftUI
import UniformTypeIdentifiers

/// The window: an optional update bar, then the Convert or the Preview tab,
/// picked with the segmented control at the top right.
struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var updater = UpdateChecker.shared

    var body: some View {
        VStack(spacing: 0) {
            if let release = updater.available {
                UpdateBanner(version: release.version)
                    .padding([.horizontal, .top], 16)
            }
            switch appState.tab {
            case .convert: ConverterView()
            case .preview: PreviewView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("", selection: $appState.tab) {
                    Text(L10n.tabConvert).tag(AppTab.convert)
                    Text(L10n.tabPreview).tag(AppTab.preview)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help("⌘1 / ⌘2")
            }
        }
    }
}

/// The Convert tab: a drop zone, the list of files, and a loading overlay.
struct ConverterView: View {
    @EnvironmentObject private var queue: ConversionQueue
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            DropZone(
                isTargeted: isTargeted,
                chooseFiles: { queue.chooseFiles() },
                paste: { queue.pasteFromClipboard() }
            )

            if let notice = queue.notice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !queue.jobs.isEmpty {
                JobList()
            } else {
                Spacer(minLength: 0)
            }

            Divider()
            OptionsBar()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onDrop(of: [.fileURL, .plainText], isTargeted: $isTargeted, perform: handleDrop)
        .overlay {
            if let job = queue.activeJob {
                LoadingOverlay(job: job, progress: queue.batchProgress)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: queue.activeJob?.id)
        .animation(.easeOut(duration: 0.2), value: queue.activeJob?.status)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        DropLoader.load(providers) { urls, text in
            if let text {
                queue.addText(text)
            } else {
                queue.add(urls)
            }
        }
    }
}

// MARK: - Drop zone

private struct DropZone: View {
    let isTargeted: Bool
    let chooseFiles: () -> Void
    let paste: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : "doc.richtext")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                .symbolRenderingMode(.hierarchical)

            Text(L10n.dropTitle)
                .font(.title3.weight(.semibold))

            Text(L10n.dropSubtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button(L10n.chooseFiles, action: chooseFiles)
                Button(action: paste) {
                    Label(L10n.pasteFromClipboard, systemImage: "doc.on.clipboard")
                }
                .help("⌘V")
            }
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 220)
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
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }
}

// MARK: - Update banner

private struct UpdateBanner: View {
    let version: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(Color.accentColor)
                .font(.title3)
            Text(L10n.updateBanner(version))
                .font(.callout.weight(.medium))
            Spacer()
            Button(L10n.updateDownload) { UpdateChecker.shared.download() }
                .controlSize(.small)
            Button {
                UpdateChecker.shared.skip()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help(L10n.updateSkip)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.1))
        )
    }
}

// MARK: - Options

/// Settings shown at the bottom of the window.
private struct OptionsBar: View {
    @EnvironmentObject private var queue: ConversionQueue
    @ObservedObject private var preferences = Preferences.shared

    var body: some View {
        HStack(spacing: 8) {
            Text(L10n.saveLabel).foregroundStyle(.secondary)
            Menu {
                Picker(L10n.saveLabel, selection: $preferences.saveMode) {
                    Text(L10n.saveModeAsk).tag(SaveMode.ask)
                    Text(L10n.saveModeNextToSource).tag(SaveMode.nextToSource)
                    if let folder = preferences.saveFolder {
                        Text(L10n.saveModeFolder(folder.lastPathComponent)).tag(SaveMode.folder)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Divider()
                Button(L10n.chooseSaveFolder) { queue.chooseSaveFolder() }
            } label: {
                Text(currentModeTitle)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(preferences.saveMode == .folder ? (preferences.saveFolder?.path ?? "") : "")
            Spacer()
            Toggle(L10n.mergeIntoOne, isOn: $preferences.mergeIntoOne)
                .toggleStyle(.checkbox)
                .help(L10n.mergeHelp)
        }
        .font(.callout)
    }

    private var currentModeTitle: String {
        switch preferences.saveMode {
        case .ask: return L10n.saveModeAsk
        case .nextToSource: return L10n.saveModeNextToSource
        case .folder: return L10n.saveModeFolder(preferences.saveFolder?.lastPathComponent ?? "")
        }
    }
}

// MARK: - File list

private struct JobList: View {
    @EnvironmentObject private var queue: ConversionQueue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.queueTitle).font(.headline)
                Spacer()
                if queue.hasFinishedJobs {
                    Button(L10n.clearFinished) { queue.clearFinished() }
                        .buttonStyle(.link)
                }
            }

            ScrollViewReader { proxy in
                List(queue.jobs) { job in
                    JobRow(job: job) { queue.remove(job.id) }
                        .id(job.id)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onAppear { scrollToEnd(proxy) }
                .onChange(of: queue.jobs.count) { _ in scrollToEnd(proxy) }
            }
        }
    }

    /// Newest items are at the bottom; keep them in view.
    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        guard let last = queue.jobs.last?.id else { return }
        DispatchQueue.main.async { proxy.scrollTo(last, anchor: .bottom) }
    }
}

private struct JobRow: View {
    let job: ConversionJob
    let remove: () -> Void

    /// For saved items: whether the PDF is still on disk.
    private var savedFileExists: Bool {
        guard case .saved(let url) = job.status else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: job.isPasted ? "doc.on.clipboard" : "doc.text")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(job.name).lineLimit(1).truncationMode(.middle)
                    if job.isPasted {
                        Text(L10n.pastedBadge).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if case .failed(let reason) = job.status {
                    Text(reason).font(.caption).foregroundStyle(.red).lineLimit(2)
                } else if let date = job.finishedAt {
                    Text(date.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            status
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .contextMenu {
            if case .saved(let url) = job.status {
                Button(L10n.menuOpen) { NSWorkspace.shared.open(url) }
                    .disabled(!savedFileExists)
                Button(L10n.menuShowInFinder) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    .disabled(!savedFileExists)
            }
            if job.status.isFinished {
                Divider()
                Button(L10n.menuRemoveFromList, action: remove)
            }
        }
    }

    @ViewBuilder private var status: some View {
        switch job.status {
        case .waiting:
            Text(L10n.statusWaiting).foregroundStyle(.secondary).font(.callout)
        case .converting:
            ProgressView().controlSize(.small)
        case .awaitingSave:
            Text(L10n.statusAwaitingSave).foregroundStyle(.secondary).font(.callout)
        case .converted:
            Text(L10n.statusConverted).foregroundStyle(.secondary).font(.callout)
        case .saved where !savedFileExists:
            Label(L10n.fileMissing, systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
                .font(.callout)
        case .saved(let url):
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Label(L10n.statusSaved, systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.green)
            .help(url.path)
        case .skipped:
            Label(L10n.statusSkipped, systemImage: "minus.circle").foregroundStyle(.secondary).font(.callout)
        case .failed:
            Label(L10n.statusFailed, systemImage: "xmark.octagon.fill").foregroundStyle(.red).font(.callout)
        }
    }
}

// MARK: - Loading screen

private struct LoadingOverlay: View {
    let job: ConversionJob
    let progress: (current: Int, total: Int)

    private var isConverting: Bool { job.status == .converting }

    private var title: String {
        if isConverting { return L10n.loadingConverting }
        if job.merge { return L10n.loadingSavingMerged }
        return job.isPartOfBatch ? L10n.loadingChooseFolder : L10n.loadingSaving
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)

            VStack(spacing: 18) {
                if isConverting {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(job.name)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if progress.total > 1 {
                    VStack(spacing: 6) {
                        ProgressView(value: Double(progress.current - 1), total: Double(progress.total))
                            .frame(width: 220)
                        Text(L10n.progress(progress.current, progress.total))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .padding(32)
        }
    }
}
