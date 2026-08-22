import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        AppModel.shared.loginItem.enableByDefaultIfNeeded()
        panelController = NotchPanelController(model: .shared)
        panelController?.show()
        let desktopWidgets = DesktopWidgetManager.shared
        desktopWidgets.restore()

        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--clear-desktop-widgets") {
            desktopWidgets.removeAll()
        }
        if let value = arguments.first(where: { $0.hasPrefix("--desktop-widget=") })?.split(separator: "=").last,
           let kind = WidgetKind(rawValue: String(value)) {
            desktopWidgets.place(kind)
        }
        let pocketFiles = arguments.compactMap { argument -> URL? in
            guard argument.hasPrefix("--pocket-file=") else { return nil }
            let path = String(argument.dropFirst("--pocket-file=".count))
            return path.isEmpty ? nil : URL(fileURLWithPath: path)
        }
        if !pocketFiles.isEmpty {
            AppModel.shared.pocket.add(pocketFiles)
            AppModel.shared.setFeature(.dropShelf, enabled: true)
            AppModel.shared.isExpanded = true
        }
        if let value = arguments.first(where: { $0.hasPrefix("--capture=") })?.split(separator: "=").last,
           let mode = ScreenshotMode(rawValue: String(value)) {
            AppModel.shared.isExpanded = false
            AppModel.shared.screenshots.capture(mode)
        }
        if arguments.contains("--browse-window") {
            AppModel.shared.browser.openWeb()
        }
        if arguments.contains("--browse-music") {
            AppModel.shared.browser.openMusic()
        }
        if arguments.contains("--youtube") {
            AppModel.shared.browser.openYouTube()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
