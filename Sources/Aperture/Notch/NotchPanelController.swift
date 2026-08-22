import AppKit
import Combine
import SwiftUI

private final class ApertureNotchPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // AppKit normally pushes borderless windows below the display safe area.
        // Aperture intentionally owns the camera-housing region and positions its
        // visible content immediately beneath it.
        frameRect
    }

    override func accessibilityPerformShowMenu() -> Bool { false }

    // The hover surface stays nonactivating, but text fields and sliders need the
    // panel to accept key status when the person explicitly interacts with them.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate animateFlag: Bool) {
        super.setFrame(frameRect, display: flag, animate: false)
    }
}

@MainActor
final class NotchPanelController: NSWindowController {
    private let model: AppModel
    private var cancellables = Set<AnyCancellable>()
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var hoverTask: Task<Void, Never>?

    init(model: AppModel) {
        self.model = model
        let panel = ApertureNotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)

        panel.isOpaque = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isFloatingPanel = true
        panel.animationBehavior = .none
        panel.becomesKeyOnlyIfNeeded = true
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false
        panel.contentView = NSHostingView(rootView: NotchRootView(model: model))

        Publishers.CombineLatest4(model.$isExpanded, model.$selectedFeature, model.$notchMetrics, model.$isCustomizing)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _, _ in self?.updateFrame(animated: true) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateFrame(animated: false) }
            .store(in: &cancellables)

        installNotchHoverMonitor()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        hoverTask?.cancel()
    }

    func show() {
        updateFrame(animated: false)
        DispatchQueue.main.async { [weak self] in
            self?.updateFrame(animated: false)
        }
    }

    private func updateFrame(animated: Bool) {
        guard let panel = window, let screen = targetScreen() else { return }
        let metrics = notchMetrics(for: screen)
        model.updateNotchMetrics(metrics)

        // On a notched Mac the physical black camera housing is the entire
        // collapsed UI. No transparent or decorative window remains beneath it.
        if metrics.hasHardwareNotch && !model.isExpanded {
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
            return
        }

        let size = model.desiredPanelSize
        let frame = NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )

        panel.hasShadow = model.isExpanded
        panel.ignoresMouseEvents = false
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    private func targetScreen() -> NSScreen? {
        // Prefer the display that actually has a camera housing. An external display
        // gets a compact floating fallback instead of a simulated hardware notch.
        if let notchedScreen = NSScreen.screens.first(where: {
            $0.safeAreaInsets.top > 0 && $0.auxiliaryTopLeftArea != nil && $0.auxiliaryTopRightArea != nil
        }) {
            return notchedScreen
        }
        if let screenWithMouse = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) {
            return screenWithMouse
        }
        return NSScreen.main
    }

    private func notchMetrics(for screen: NSScreen) -> NotchMetrics {
        guard screen.safeAreaInsets.top > 0,
              let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea else {
            return .fallback
        }

        let cameraHousingWidth = rightArea.minX - leftArea.maxX
        guard cameraHousingWidth > 80 else { return .fallback }
        return NotchMetrics(
            width: cameraHousingWidth,
            height: max(28, screen.safeAreaInsets.top),
            hasHardwareNotch: true
        )
    }

    private func installNotchHoverMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            Task { @MainActor [weak self] in self?.evaluatePointerLocation() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            Task { @MainActor [weak self] in self?.evaluatePointerLocation() }
            return event
        }
    }

    private func evaluatePointerLocation() {
        guard let panel = window, let screen = targetScreen() else { return }
        let pointer = NSEvent.mouseLocation
        let isOverNotch = notchHoverRect(for: screen).contains(pointer)
        let isOverExpandedPanel = model.isExpanded && panel.frame.insetBy(dx: -4, dy: -4).contains(pointer)

        hoverTask?.cancel()
        if !model.isExpanded && isOverNotch {
            hoverTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(90))
                guard let self, !Task.isCancelled, let screen = self.targetScreen() else { return }
                guard self.notchHoverRect(for: screen).contains(NSEvent.mouseLocation) else { return }
                if self.isFileDragActive {
                    self.model.setFeature(.dropShelf, enabled: true)
                }
                self.model.isExpanded = true
            }
        } else if model.isExpanded && model.collapseAfterHover && !DesktopWidgetManager.shared.isDraggingWidget && !isOverNotch && !isOverExpandedPanel {
            hoverTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(780))
                guard let self, !Task.isCancelled, let panel = self.window, let screen = self.targetScreen() else { return }
                let pointer = NSEvent.mouseLocation
                guard !self.notchHoverRect(for: screen).contains(pointer), !panel.frame.contains(pointer) else { return }
                self.model.isExpanded = false
                self.model.showHome()
            }
        }
    }

    private var isFileDragActive: Bool {
        NSPasteboard(name: .drag).canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
    }

    private func notchHoverRect(for screen: NSScreen) -> NSRect {
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea,
           screen.safeAreaInsets.top > 0 {
            return NSRect(
                x: leftArea.maxX - 14,
                y: screen.frame.maxY - screen.safeAreaInsets.top - 12,
                width: rightArea.minX - leftArea.maxX + 28,
                height: screen.safeAreaInsets.top + 12
            )
        }

        let metrics = NotchMetrics.fallback
        return NSRect(
            x: screen.frame.midX - (metrics.width + 80) / 2,
            y: screen.frame.maxY - metrics.height - 14,
            width: metrics.width + 80,
            height: metrics.height + 14
        )
    }
}
