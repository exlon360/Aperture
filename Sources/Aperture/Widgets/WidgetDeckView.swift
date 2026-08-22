import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WidgetDeckView: View {
    @ObservedObject var model: AppModel
    @State private var showingGallery = false

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("THE DECK").apertureLabel()
                    Text("Small tools for the moment you’re in.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AperturePalette.text)
                }
                Spacer()
                Button {
                    showingGallery = true
                } label: {
                    Label("Customize", systemImage: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AperturePalette.text)
            }
            .padding(.horizontal, 4)

            ScrollView(.vertical) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(model.enabledWidgets) { kind in
                        DetachableWidgetCard(kind: kind)
                            .frame(height: 134)
                    }
                }
                .padding(.bottom, 2)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showingGallery) {
            WidgetGallery(model: model)
        }
    }
}

private struct DetachableWidgetCard: View {
    let kind: WidgetKind
    @State private var isHovering = false
    @State private var isDragging = false

    var body: some View {
        ZStack {
            WidgetContainer(kind: kind)
                .opacity(isDragging ? 0.55 : 1)

            if isDragging {
                Label("Release on desktop", systemImage: "arrow.down.to.line.compact")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .frame(height: 28)
                    .background(.ultraThinMaterial, in: Capsule())
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            desktopHandle
                .opacity(isHovering || isDragging ? 1 : 0.22)
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button {
                DesktopWidgetManager.shared.place(kind)
            } label: {
                Label("Add to Desktop", systemImage: "arrow.down.to.line.compact")
            }
        }
    }

    private var desktopHandle: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down.to.line.compact")
            if isHovering || isDragging { Text("Desktop") }
        }
        .font(.system(size: 7, weight: .bold, design: .rounded))
        .foregroundStyle(.white.opacity(0.82))
        .padding(.horizontal, 7)
        .frame(height: 17)
        .background(.black.opacity(0.38), in: Capsule())
        .contentShape(Capsule())
        .offset(y: 4)
        .gesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .global)
                .onChanged { _ in
                    isDragging = true
                    DesktopWidgetManager.shared.isDraggingWidget = true
                }
                .onEnded { _ in
                    DesktopWidgetManager.shared.place(kind, at: NSEvent.mouseLocation)
                    DesktopWidgetManager.shared.isDraggingWidget = false
                    isDragging = false
                }
        )
        .onTapGesture {
            DesktopWidgetManager.shared.place(kind)
        }
        .help("Drag to the desktop")
    }
}

struct WidgetContainer: View {
    let kind: WidgetKind

    var body: some View {
        ApertureCard(tint: Color(hex: kind.tint)) {
            Group {
                switch kind {
                case .focus: FocusWidget()
                case .clipboard: ClipboardWidget()
                case .pulse: PulseWidget()
                case .quickLaunch: QuickLaunchWidget()
                case .dropShelf: DropShelfWidget()
                case .dayline: DaylineWidget()
                }
            }
        }
    }
}

private struct WidgetTitle: View {
    let kind: WidgetKind
    var trailing: String? = nil

    var body: some View {
        HStack {
            Label(kind.title, systemImage: kind.icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AperturePalette.text.opacity(0.84))
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AperturePalette.secondary)
            }
        }
        .padding(.trailing, 17)
    }
}

@MainActor
private final class FocusTimerModel: ObservableObject {
    static let shared = FocusTimerModel()
    @Published var remaining = 25 * 60
    @Published var isRunning = false
    private var timer: Timer?

    var formatted: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    func toggle() {
        isRunning.toggle()
        timer?.invalidate()
        guard isRunning else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.remaining > 0 {
                    self.remaining -= 1
                } else {
                    self.isRunning = false
                    self.timer?.invalidate()
                    NSSound.beep()
                    ApertureNotificationCenter.shared.post(
                        title: "Focus Complete",
                        body: "Your 25-minute Aperture session is complete."
                    )
                }
            }
        }
    }

    func reset() {
        timer?.invalidate()
        isRunning = false
        remaining = 25 * 60
    }
}

private struct FocusWidget: View {
    @ObservedObject private var timer = FocusTimerModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetTitle(kind: .focus, trailing: timer.isRunning ? "IN FLOW" : "25 MIN")
            HStack(alignment: .lastTextBaseline) {
                Text(timer.formatted)
                    .font(.system(size: 32, weight: .light, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Button(action: timer.reset) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AperturePalette.secondary)
                Button(action: timer.toggle) {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AperturePalette.ink)
                        .frame(width: 30, height: 30)
                        .background(Color(hex: WidgetKind.focus.tint), in: Circle())
                }
                .buttonStyle(.plain)
            }
            ProgressView(value: Double(25 * 60 - timer.remaining), total: Double(25 * 60))
                .tint(Color(hex: WidgetKind.focus.tint))
        }
        .foregroundStyle(AperturePalette.text)
    }
}

private struct ClipboardWidget: View {
    @State private var clipboardText = "Copy text anywhere and it will wait here."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetTitle(kind: .clipboard, trailing: "LATEST")
            Text(clipboardText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AperturePalette.text)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            Button("Refresh") { refresh() }
                .font(.system(size: 10, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Color(hex: WidgetKind.clipboard.tint))
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        if let value = NSPasteboard.general.string(forType: .string), !value.isEmpty {
            clipboardText = value
        }
    }
}

private struct PulseWidget: View {
    @StateObject private var monitor = SystemMonitor()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetTitle(kind: .pulse, trailing: monitor.thermalLabel)
            HStack(spacing: 20) {
                Metric(value: "\(monitor.coreCount)", label: "CORES")
                Metric(value: monitor.uptime, label: "UPTIME")
                Metric(value: monitor.lowPower ? "ON" : "OFF", label: "LOW POWER")
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                ForEach(0..<18, id: \.self) { index in
                    Capsule()
                        .fill(index < monitor.activityBars ? Color(hex: WidgetKind.pulse.tint) : Color.white.opacity(0.08))
                        .frame(height: CGFloat(4 + (index % 5) * 2))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct Metric: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(AperturePalette.text)
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(AperturePalette.secondary)
        }
    }
}

private struct QuickLaunchWidget: View {
    private let apps = [
        ("Safari", "safari.fill", "5AC8FA", "com.apple.Safari"),
        ("Messages", "message.fill", "65D36E", "com.apple.MobileSMS"),
        ("Music", "music.note", "FA4B62", "com.apple.Music"),
        ("Calendar", "calendar", "FF6659", "com.apple.iCal")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            WidgetTitle(kind: .quickLaunch, trailing: "Favorites")
            HStack(spacing: 15) {
                ForEach(apps, id: \.0) { app in
                    Button {
                        launch(app.3)
                    } label: {
                        VStack(spacing: 7) {
                            appIcon(bundleIdentifier: app.3, fallback: app.1, tint: app.2)
                            Text(app.0)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(AperturePalette.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func launch(_ bundleIdentifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            NSSound.beep()
            AppModel.shared.featureNotice = "That application isn’t installed."
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            if let error {
                Task { @MainActor in
                    AppModel.shared.featureNotice = "Couldn’t open the app: \(error.localizedDescription)"
                }
            }
        }
    }

    @ViewBuilder
    private func appIcon(bundleIdentifier: String, fallback: String, tint: String) -> some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .interpolation(.high)
                .frame(width: 36, height: 36)
        } else {
            Image(systemName: fallback)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: tint))
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
        }
    }
}

private struct DropShelfWidget: View {
    @ObservedObject private var pocket = PocketController.shared
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetTitle(kind: .dropShelf, trailing: pocket.items.isEmpty ? "NOTCH SYNC" : "\(pocket.items.count) ITEMS")
            if pocket.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 18, weight: .light))
                    Text("Drop files here between tasks")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(isTargeted ? Color(hex: WidgetKind.dropShelf.tint) : AperturePalette.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(isTargeted ? 0.08 : 0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                HStack(spacing: -6) {
                    ForEach(pocket.items.prefix(5)) { item in
                        Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                            .resizable()
                            .frame(width: 36, height: 36)
                            .background(AperturePalette.raised, in: RoundedRectangle(cornerRadius: 8))
                    }
                    Spacer()
                    Button("Clear") { pocket.clear() }
                        .font(.system(size: 10, weight: .semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(AperturePalette.secondary)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL?
                    if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else {
                        url = item as? URL
                    }
                    if let url {
                        Task { @MainActor in _ = pocket.add([url]) }
                    }
                }
            }
            return true
        }
    }
}

private struct DaylineWidget: View {
    private var dayProgress: Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: Date())
        return Double((components.hour ?? 0) * 60 + (components.minute ?? 0)) / 1440
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 13) {
                WidgetTitle(kind: .dayline, trailing: context.date.formatted(.dateTime.weekday(.wide)))
                Text(context.date, format: .dateTime.month(.wide).day())
                    .font(.system(size: 25, weight: .light, design: .rounded))
                    .foregroundStyle(AperturePalette.text)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: WidgetKind.dayline.tint), AperturePalette.accent], startPoint: .leading, endPoint: .trailing))
                            .frame(width: proxy.size.width * dayProgress)
                        Circle()
                            .fill(AperturePalette.text)
                            .frame(width: 8, height: 8)
                            .offset(x: max(0, proxy.size.width * dayProgress - 4))
                    }
                }
                .frame(height: 8)
                Text("\(Int(dayProgress * 100))% of today has unfolded")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AperturePalette.secondary)
            }
        }
    }
}

private struct WidgetGallery: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Widget Gallery")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Choose what earns a place in your aperture.")
                        .foregroundStyle(AperturePalette.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(WidgetKind.allCases) { kind in
                    Button { model.toggleWidget(kind) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: kind.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(hex: kind.tint))
                                .frame(width: 38, height: 38)
                                .background(Color(hex: kind.tint).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(kind.title).font(.system(size: 13, weight: .semibold))
                                Text(kind.subtitle).font(.system(size: 10)).foregroundStyle(AperturePalette.secondary)
                            }
                            Spacer()
                            Image(systemName: model.enabledWidgets.contains(kind) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(model.enabledWidgets.contains(kind) ? AperturePalette.accent : AperturePalette.secondary)
                        }
                        .padding(12)
                        .background(AperturePalette.card, in: RoundedRectangle(cornerRadius: 15))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .foregroundStyle(AperturePalette.text)
        .padding(22)
        .frame(width: 600)
        .background(AperturePalette.ink)
    }
}
