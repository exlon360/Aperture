import AppKit
import Foundation

@MainActor
final class MusicController: ObservableObject {
    static let shared = MusicController()

    @Published private(set) var title = "Nothing Playing"
    @Published private(set) var artist = "Open Music to begin"
    @Published private(set) var album = ""
    @Published private(set) var isPlaying = false
    @Published private(set) var isRunning = false
    @Published private(set) var artwork: NSImage?

    private var timer: Timer?

    private init() {}

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func togglePlayback() {
        if isRunning {
            run(command: "playpause")
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, _ in }
        }
        refresh(after: 0.35)
    }

    func next() {
        run(command: "next track")
        refresh(after: 0.25)
    }

    func previous() {
        run(command: "back track")
        refresh(after: 0.25)
    }

    func openMusic() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, _ in }
    }

    func refresh() {
        isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
        guard isRunning else {
            title = "Nothing Playing"
            artist = "Open Music to begin"
            album = ""
            isPlaying = false
            artwork = nil
            return
        }

        let separator = "¬"
        let source = """
        tell application "Music"
            if player state is stopped then return "stopped\(separator)Nothing Playing\(separator)Music\(separator)"
            set t to current track
            return (player state as text) & "\(separator)" & (name of t) & "\(separator)" & (artist of t) & "\(separator)" & (album of t)
        end tell
        """
        guard let value = execute(source)?.stringValue else { return }
        let parts = value.components(separatedBy: separator)
        guard parts.count >= 4 else { return }
        isPlaying = parts[0] == "playing"
        title = parts[1]
        artist = parts[2]
        album = parts[3]
        refreshArtwork()
    }

    private func refreshArtwork() {
        let source = """
        tell application "Music"
            if player state is stopped then return missing value
            if (count of artworks of current track) is 0 then return missing value
            return data of artwork 1 of current track
        end tell
        """
        if let descriptor = execute(source), let image = NSImage(data: descriptor.data) {
            artwork = image
        } else {
            artwork = nil
        }
    }

    private func run(command: String) {
        guard isRunning else { return }
        _ = execute("tell application \"Music\" to \(command)")
    }

    private func refresh(after delay: Double) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            refresh()
        }
    }

    private func execute(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }
}

