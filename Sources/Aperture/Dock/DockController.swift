import AppKit
import Foundation

enum DockPosition: String, CaseIterable, Identifiable {
    case left
    case bottom
    case right

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

@MainActor
final class DockController: ObservableObject {
    @Published var position: DockPosition = .bottom
    @Published var tileSize = 48.0
    @Published var magnification = true
    @Published var magnifiedSize = 72.0
    @Published var autoHide = false
    @Published var showRecents = true
    @Published var isApplying = false
    @Published var resultMessage: String?

    func apply() {
        guard !isApplying else { return }
        isApplying = true
        resultMessage = nil
        let configuration = DockConfiguration(
            position: position,
            tileSize: tileSize,
            magnification: magnification,
            magnifiedSize: magnifiedSize,
            autoHide: autoHide,
            showRecents: showRecents
        )
        Task {
            do {
                try DockWriter.apply(configuration)
                resultMessage = "Dock updated"
                ApertureNotificationCenter.shared.post(title: "Dock Updated", body: "Your Dock layout is active.")
            } catch {
                resultMessage = "Couldn’t update Dock"
            }
            isApplying = false
        }
    }

    func resetPreview() {
        position = .bottom
        tileSize = 48
        magnification = true
        magnifiedSize = 72
        autoHide = false
        showRecents = true
        resultMessage = nil
    }
}

private struct DockConfiguration {
    let position: DockPosition
    let tileSize: Double
    let magnification: Bool
    let magnifiedSize: Double
    let autoHide: Bool
    let showRecents: Bool
}

private enum DockWriter {
    static func apply(_ configuration: DockConfiguration) throws {
        let commands = [
            ["write", "com.apple.dock", "orientation", "-string", configuration.position.rawValue],
            ["write", "com.apple.dock", "tilesize", "-float", String(Int(configuration.tileSize))],
            ["write", "com.apple.dock", "magnification", "-bool", configuration.magnification ? "true" : "false"],
            ["write", "com.apple.dock", "largesize", "-float", String(Int(configuration.magnifiedSize))],
            ["write", "com.apple.dock", "autohide", "-bool", configuration.autoHide ? "true" : "false"],
            ["write", "com.apple.dock", "show-recents", "-bool", configuration.showRecents ? "true" : "false"]
        ]
        for arguments in commands {
            try run("/usr/bin/defaults", arguments: arguments)
        }
        try run("/usr/bin/killall", arguments: ["Dock"])
    }

    private static func run(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "Aperture.Dock", code: Int(process.terminationStatus))
        }
    }
}
