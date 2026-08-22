import AppKit
import CoreGraphics
import SwiftUI

struct DesktopWidgetRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let kind: WidgetKind
    var originX: Double
    var originY: Double
}

private final class DesktopWidgetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class DesktopWidgetManager: ObservableObject {
    static let shared = DesktopWidgetManager()

    @Published private(set) var records: [DesktopWidgetRecord]
    @Published var isDraggingWidget = false

    private var panels: [UUID: NSPanel] = [:]
    private var moveObservers: [UUID: NSObjectProtocol] = [:]
    private var pointerMonitors: [Any] = []
    private var editingWidgetIDs: Set<UUID> = []
    private let defaults = UserDefaults.standard
    private let storageKey = "desktopWidgetPlacements"
    private let widgetSize = CGSize(width: 270, height: 154)
    // Sit just above Finder's desktop-icon surface so widgets receive pointer
    // events, while remaining far below ordinary application windows.
    private let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

    private init() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([DesktopWidgetRecord].self, from: data) {
            records = decoded
        } else {
            records = []
        }
        startPointerTracking()
    }

    var count: Int { records.count }

    func restore() {
        for record in records where panels[record.id] == nil {
            makePanel(for: record)
        }
    }

    func place(_ kind: WidgetKind, at screenPoint: CGPoint? = nil) {
        let screen = screenForPoint(screenPoint) ?? NSScreen.main
        guard let screen else { return }

        let center = screenPoint ?? nextDefaultCenter(on: screen)
        let proposed = CGPoint(x: center.x - widgetSize.width / 2, y: center.y - widgetSize.height / 2)
        let origin = clampedOrigin(proposed, on: screen)
        let record = DesktopWidgetRecord(
            id: UUID(),
            kind: kind,
            originX: origin.x,
            originY: origin.y
        )
        records.append(record)
        persist()
        makePanel(for: record)
    }

    func remove(_ id: UUID) {
        editingWidgetIDs.remove(id)
        panels[id]?.orderOut(nil)
        panels[id]?.close()
        panels.removeValue(forKey: id)
        if let observer = moveObservers.removeValue(forKey: id) {
            NotificationCenter.default.removeObserver(observer)
        }
        records.removeAll { $0.id == id }
        persist()
    }

    func remove(kind: WidgetKind) {
        let ids = records.filter { $0.kind == kind }.map(\.id)
        for id in ids { remove(id) }
    }

    func removeAll() {
        for id in Array(panels.keys) {
            panels[id]?.orderOut(nil)
            panels[id]?.close()
        }
        for observer in moveObservers.values {
            NotificationCenter.default.removeObserver(observer)
        }
        panels.removeAll()
        moveObservers.removeAll()
        editingWidgetIDs.removeAll()
        records.removeAll()
        persist()
    }

    private func makePanel(for record: DesktopWidgetRecord) {
        let panel = DesktopWidgetPanel(
            contentRect: NSRect(
                x: record.originX,
                y: record.originY,
                width: widgetSize.width,
                height: widgetSize.height
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = false
        panel.level = desktopLevel
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isExcludedFromWindowsMenu = true
        panel.contentView = NSHostingView(rootView: DesktopWidgetView(
            record: record,
            onBeginEditing: { [weak self] in
                self?.beginEditing(record.id)
            },
            onEndEditing: { [weak self] in
                self?.endEditing(record.id)
            },
            onRemove: { [weak self] in self?.remove(record.id) }
        ))

        panels[record.id] = panel
        moveObservers[record.id] = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self, weak panel] _ in
            guard let panel else { return }
            let origin = panel.frame.origin
            Task { @MainActor [weak self] in
                self?.savePosition(id: record.id, origin: origin)
            }
        }
        panel.orderFrontRegardless()
    }

    private func startPointerTracking() {
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { [weak self] _ in
            Task { @MainActor [weak self] in self?.updatePointerState() }
        }) {
            pointerMonitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { [weak self] event in
            Task { @MainActor [weak self] in self?.updatePointerState() }
            return event
        }) {
            pointerMonitors.append(monitor)
        }
    }

    private func updatePointerState() {
        let pointer = NSEvent.mouseLocation
        for (id, panel) in panels {
            let shouldElevate = panel.frame.insetBy(dx: -4, dy: -4).contains(pointer) || editingWidgetIDs.contains(id)
            let desiredLevel: NSWindow.Level = shouldElevate ? .floating : desktopLevel
            guard panel.level != desiredLevel else { continue }
            panel.level = desiredLevel
            if shouldElevate { panel.orderFrontRegardless() }
        }
    }

    private func beginEditing(_ id: UUID) {
        editingWidgetIDs.insert(id)
        updatePointerState()
    }

    private func endEditing(_ id: UUID) {
        editingWidgetIDs.remove(id)
        updatePointerState()
    }

    private func savePosition(id: UUID, origin: CGPoint) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].originX = origin.x
        records[index].originY = origin.y
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func screenForPoint(_ point: CGPoint?) -> NSScreen? {
        guard let point else { return NSScreen.main }
        return NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
    }

    private func nextDefaultCenter(on screen: NSScreen) -> CGPoint {
        let offset = CGFloat(records.count % 5) * 24
        return CGPoint(
            x: screen.visibleFrame.maxX - widgetSize.width / 2 - 28 - offset,
            y: screen.visibleFrame.maxY - widgetSize.height / 2 - 34 - offset
        )
    }

    private func clampedOrigin(_ origin: CGPoint, on screen: NSScreen) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, screen.visibleFrame.minX + 12), screen.visibleFrame.maxX - widgetSize.width - 12),
            y: min(max(origin.y, screen.visibleFrame.minY + 12), screen.visibleFrame.maxY - widgetSize.height - 12)
        )
    }
}

private struct DesktopWidgetView: View {
    let record: DesktopWidgetRecord
    let onBeginEditing: () -> Void
    let onEndEditing: () -> Void
    let onRemove: () -> Void
    @State private var isHovering = false
    @State private var isEditing = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WidgetContainer(kind: record.kind)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 22, height: 22)
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(7)
            .opacity(isHovering || isEditing ? 1 : 0.52)
            .accessibilityLabel("Remove \(record.kind.title) from Desktop")
            .help("Remove from Desktop")
        }
        .padding(2)
        .onHover { isHovering = $0 }
        .onTapGesture {
            if isEditing {
                isEditing = false
                onEndEditing()
            } else {
                isEditing = true
                onBeginEditing()
            }
        }
        .onExitCommand {
            isEditing = false
            onEndEditing()
        }
        .contextMenu {
            Button("Remove from Desktop", role: .destructive, action: onRemove)
        }
    }
}
