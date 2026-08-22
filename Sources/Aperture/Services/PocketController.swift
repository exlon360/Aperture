import AppKit
import Foundation

struct PocketItem: Codable, Hashable, Identifiable {
    let id: UUID
    let url: URL
    let addedAt: Date

    init(url: URL) {
        id = UUID()
        self.url = url.standardizedFileURL
        addedAt = Date()
    }
}

@MainActor
final class PocketController: ObservableObject {
    static let shared = PocketController()

    @Published private(set) var items: [PocketItem]

    private let defaults = UserDefaults.standard
    private let storageKey = "aperturePocketItems"

    private init() {
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([PocketItem].self, from: data) {
            items = saved.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        } else {
            items = []
        }
    }

    @discardableResult
    func add(_ urls: [URL]) -> Bool {
        let valid = urls
            .filter(\.isFileURL)
            .map(\.standardizedFileURL)
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !valid.isEmpty else { return false }

        for url in valid.reversed() {
            items.removeAll { $0.url == url }
            items.insert(PocketItem(url: url), at: 0)
        }
        persist()
        return true
    }

    func remove(_ item: PocketItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clear() {
        items.removeAll()
        persist()
    }

    func open(_ item: PocketItem) {
        NSWorkspace.shared.open(item.url)
    }

    func reveal(_ item: PocketItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func copyPath(_ item: PocketItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.url.path, forType: .string)
    }

    func detail(for item: PocketItem) -> String {
        let values = try? item.url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        if values?.isDirectory == true { return "FOLDER" }
        if let size = values?.fileSize {
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
        let suffix = item.url.pathExtension
        return suffix.isEmpty ? "FILE" : suffix.uppercased()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
