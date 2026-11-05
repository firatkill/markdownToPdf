import AppKit
import SwiftUI

@main
struct MarkdownToPdfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("markdownToPdf", id: "main") {
            RootView()
                .environmentObject(appDelegate.queue)
                .environmentObject(appDelegate.preview)
                .environmentObject(appDelegate.appState)
                .frame(minWidth: 480, minHeight: 460)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 980, height: 720)
        .commands {
            AppCommands(appState: appDelegate.appState, queue: appDelegate.queue, preview: appDelegate.preview)
        }
    }
}

/// The two tabs at the top of the window.
enum AppTab: Hashable {
    case convert
    case preview
}

@MainActor
final class AppState: ObservableObject {
    /// The app always opens on the Convert tab.
    @Published var tab: AppTab = .convert
}

/// Menu items whose action depends on the selected tab.
struct AppCommands: Commands {
    @ObservedObject var appState: AppState
    let queue: ConversionQueue
    @ObservedObject var preview: PreviewModel

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button(L10n.checkForUpdates) { UpdateChecker.shared.checkNow() }
        }
        CommandGroup(replacing: .newItem) {
            Button(appState.tab == .preview ? L10n.previewOpenFile : L10n.chooseFiles) {
                if appState.tab == .preview { preview.openFile() } else { queue.chooseFiles() }
            }
            .keyboardShortcut("o")
        }
        CommandGroup(replacing: .saveItem) {
            Button(L10n.saveAsPDF + "…") { preview.save() }
                .keyboardShortcut("s")
                .disabled(appState.tab != .preview || !preview.hasContent)
        }
        CommandGroup(before: .toolbar) {
            Button(L10n.tabConvert) { appState.tab = .convert }
                .keyboardShortcut("1")
            Button(L10n.tabPreview) { appState.tab = .preview }
                .keyboardShortcut("2")
            Divider()
        }
    }
}

/// Owns the queue and the preview so files opened from Finder ("Open With", Dock icon) land in them too.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let queue = ConversionQueue()
    let appState = AppState()
    lazy var preview = PreviewModel(queue: queue)
    private var isCommandLineMode = false
    private var pasteMonitor: Any?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Finder › right-click › "Convert to PDF" and the text service land here.
        NSApp.servicesProvider = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let job = CommandLineConversion.parse(CommandLine.arguments) {
            isCommandLineMode = true
            NSApp.setActivationPolicy(.accessory)
            NSApp.windows.forEach { $0.orderOut(nil) }
            Task { exit(await job.run()) }
            return
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        installPasteShortcut()
        NSUpdateDynamicServices()
        UpdateChecker.shared.checkIfDue()
    }

    // MARK: - Services (declared under NSServices in Info.plist)

    /// "Convert to PDF" on Markdown files selected in Finder.
    @objc func convertFiles(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        NSApp.activate(ignoringOtherApps: true)
        appState.tab = .convert
        queue.add(urls)
    }

    /// "Convert Markdown to PDF" on text selected in any app.
    @objc func convertText(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        NSApp.activate(ignoringOtherApps: true)
        appState.tab = .convert
        queue.addText(text)
    }

    /// ⌘V in the main window converts (or, on the Preview tab, previews) the clipboard. Text fields and dialogs
    /// (such as the save dialog's name field) keep their normal paste.
    private func installPasteShortcut() {
        pasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers?.lowercased() == "v",
                  let window = event.window,
                  !(window is NSPanel),
                  window.attachedSheet == nil,
                  !(window.firstResponder is NSText)
            else { return event }
            if self.appState.tab == .preview {
                self.preview.pasteFromClipboard()
            } else {
                self.queue.pasteFromClipboard()
            }
            return nil
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        appState.tab = .convert
        queue.add(urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // In --convert mode there is no window; quitting early would drop the PDF.
        !isCommandLineMode
    }
}
