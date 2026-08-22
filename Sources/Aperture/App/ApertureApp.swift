import SwiftUI

@main
struct ApertureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra("Aperture", systemImage: "capsule.inset.filled") {
            ApertureMenu(model: model)
        }

        Settings {
            SettingsView(model: model)
        }
    }
}

private struct ApertureMenu: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var desktopWidgets = DesktopWidgetManager.shared

    var body: some View {
        Button(model.isExpanded ? "Collapse Aperture" : "Open Aperture") {
            model.isExpanded.toggle()
        }
        .keyboardShortcut("a")

        Divider()

        Button("Widgets") {
            model.open(.widgets)
        }
        Button("Local AI") {
            model.open(.assistant)
        }
        Button("Music") {
            model.setFeature(.music, enabled: true)
            model.isExpanded = true
        }
        Button("Screenshot Tools") {
            model.setFeature(.screenshots, enabled: true)
            model.isExpanded = true
        }
        Button("Notifications") {
            model.setFeature(.notifications, enabled: true)
            model.isExpanded = true
        }
        Button("Browse") {
            model.open(.browse)
        }
        Button("YouTube") {
            model.browser.activateInline(.youtube)
            model.open(.browse)
        }
        Button("Dock") {
            model.open(.dock)
        }
        Button("Pocket") {
            model.setFeature(.dropShelf, enabled: true)
            model.isExpanded = true
        }
        Menu("Add Widget to Desktop") {
            ForEach(WidgetKind.allCases) { kind in
                Button {
                    desktopWidgets.place(kind)
                } label: {
                    Label(kind.title, systemImage: kind.icon)
                }
            }
        }
        if desktopWidgets.count > 0 {
            Menu("Remove Desktop Widget") {
                ForEach(desktopWidgets.records) { record in
                    Button {
                        desktopWidgets.remove(record.id)
                    } label: {
                        Label(record.kind.title, systemImage: record.kind.icon)
                    }
                }
                Divider()
                Button("Remove All", role: .destructive) {
                    desktopWidgets.removeAll()
                }
            }
        }

        Divider()

        SettingsLink {
            Text("Settings…")
        }
        Button("Quit Aperture") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
