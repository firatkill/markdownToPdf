import AppKit
import SwiftUI

@main
struct MarkdownToPdfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("markdownToPdf", id: "main") {
            ContentView()
                .environmentObject(appDelegate.queue)
                .frame(minWidth: 460, minHeight: 420)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 520, height: 520)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L10n.chooseFiles) { appDelegate.queue.chooseFiles() }
                    .keyboardShortcut("o")
            }
        }
    }
}

/// Owns the queue so files opened from Finder ("Open With", Dock icon) land in it too.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let queue = ConversionQueue()
    private var isCommandLineMode = false
    private var pasteMonitor: Any?

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
    }

    /// ⌘V in the main window converts the clipboard. Text fields and dialogs
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
            self.queue.pasteFromClipboard()
            return nil
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        queue.add(urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // In --convert mode there is no window; quitting early would drop the PDF.
        !isCommandLineMode
    }
}
