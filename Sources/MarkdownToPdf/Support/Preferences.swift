import Foundation

/// Where finished PDFs go.
enum SaveMode: String, CaseIterable {
    /// Show a save dialog (one folder question for several files dropped together).
    case ask
    /// Save next to the Markdown file, without asking.
    case nextToSource
    /// Save into one chosen folder, without asking.
    case folder
}

/// User settings, stored in UserDefaults so they survive restarts.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Key {
        static let saveMode = "saveMode"
        static let saveFolder = "saveFolderPath"
        static let lastSaveFolder = "lastSaveFolderPath"
        static let mergeIntoOne = "mergeIntoOne"
    }

    private let defaults = UserDefaults.standard

    @Published var saveMode: SaveMode {
        didSet { defaults.set(saveMode.rawValue, forKey: Key.saveMode) }
    }

    @Published var saveFolder: URL? {
        didSet { defaults.set(saveFolder?.path, forKey: Key.saveFolder) }
    }

    /// Several files dropped together become one PDF.
    @Published var mergeIntoOne: Bool {
        didSet { defaults.set(mergeIntoOne, forKey: Key.mergeIntoOne) }
    }

    /// Folder of the last saved PDF; dialogs for pasted text open here.
    var lastSaveFolder: URL? {
        get { defaults.string(forKey: Key.lastSaveFolder).map { URL(fileURLWithPath: $0, isDirectory: true) } }
        set { defaults.set(newValue?.path, forKey: Key.lastSaveFolder) }
    }

    private init() {
        saveMode = SaveMode(rawValue: defaults.string(forKey: Key.saveMode) ?? "") ?? .ask
        mergeIntoOne = defaults.bool(forKey: Key.mergeIntoOne)
        saveFolder = defaults.string(forKey: Key.saveFolder).map { URL(fileURLWithPath: $0, isDirectory: true) }
        if saveMode == .folder && saveFolder == nil {
            saveMode = .ask
        }
    }

    /// The chosen folder, if it is still there.
    var existingSaveFolder: URL? {
        guard let folder = saveFolder else { return nil }
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue ? folder : nil
    }
}
