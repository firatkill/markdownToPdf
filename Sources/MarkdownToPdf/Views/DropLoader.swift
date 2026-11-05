import AppKit

/// Reads what was dropped on a view: Markdown files, or text dragged from another app.
enum DropLoader {
    /// Calls `completion` on the main thread with the dropped file URLs (in drop order)
    /// or, when no files were dropped, the dropped text.
    static func load(
        _ providers: [NSItemProvider],
        completion: @escaping @MainActor (_ urls: [URL], _ text: String?) -> Void
    ) -> Bool {
        guard !providers.isEmpty else { return false }
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [(Int, URL)] = []
        var texts: [(Int, String)] = []

        for (order, provider) in providers.enumerated() {
            if provider.canLoadObject(ofClass: URL.self) {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url, url.isFileURL {
                        lock.lock(); urls.append((order, url)); lock.unlock()
                    }
                    group.leave()
                }
            } else if provider.canLoadObject(ofClass: String.self) {
                group.enter()
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    if let text {
                        lock.lock(); texts.append((order, text)); lock.unlock()
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            let sortedURLs = urls.sorted { $0.0 < $1.0 }.map(\.1)
            let text = texts.sorted { $0.0 < $1.0 }.map(\.1).joined(separator: "\n\n")
            MainActor.assumeIsolated {
                completion(sortedURLs, sortedURLs.isEmpty && !text.isEmpty ? text : nil)
            }
        }
        return true
    }
}
