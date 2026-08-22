import SwiftUI

struct NotchRootView: View {
    @ObservedObject var model: AppModel
    @State private var hoverTask: Task<Void, Never>?
    @State private var pointerIsInside = false

    var body: some View {
        ZStack(alignment: .top) {
            if model.isExpanded {
                expandedView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.90, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
                    ))
            } else {
                compactView
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.48, dampingFraction: 0.78, blendDuration: 0.12), value: model.isExpanded)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: model.selectedFeature)
        .preferredColorScheme(.dark)
        .tint(AperturePalette.accent)
        .onHover(perform: handleHover)
    }

    private var compactView: some View {
        Group {
            if model.notchMetrics.hasHardwareNotch {
                realNotchAffordance
            } else {
                fallbackNotch
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityLabel("Hover to open Aperture")
        .help("Hover to open Aperture")
    }

    private var fallbackNotch: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle().fill(AperturePalette.iris.opacity(0.28)).frame(width: 18, height: 18)
                Circle().fill(AperturePalette.sky).frame(width: 6, height: 6)
                    .shadow(color: AperturePalette.sky.opacity(0.8), radius: 6)
            }

            Text("Aperture")
                .font(.system(size: 11, weight: .bold, design: .rounded))

            Spacer(minLength: 4)

            if model.compactClock {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(.white.opacity(0.6))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(width: 250, height: 38)
        .background(Color.black.opacity(0.92), in: UnevenRoundedRectangle(bottomLeadingRadius: 17, bottomTrailingRadius: 17))
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(LinearGradient(colors: [.clear, AperturePalette.sky, AperturePalette.iris, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: 92, height: 1)
        }
    }

    private var expandedView: some View {
        ZStack(alignment: .top) {
            LiquidControlCenter(model: model)
                .padding(.top, model.notchMetrics.height - 1)

            if !model.notchMetrics.hasHardwareNotch {
                fallbackNotch
                    .zIndex(2)
            }
        }
        .padding(.horizontal, 4)
    }

    private var realNotchAffordance: some View {
        Color.clear
            .frame(width: model.notchMetrics.width, height: model.notchMetrics.height)
    }

    private func handleHover(_ hovering: Bool) {
        pointerIsInside = hovering
        hoverTask?.cancel()

        if hovering && !model.isExpanded {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(90))
                guard !Task.isCancelled, pointerIsInside else { return }
                await MainActor.run { model.isExpanded = true }
            }
        } else if !hovering && model.collapseAfterHover && model.isExpanded && !DesktopWidgetManager.shared.isDraggingWidget {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(780))
                guard !Task.isCancelled, !pointerIsInside else { return }
                await MainActor.run {
                    model.isExpanded = false
                    model.showHome()
                }
            }
        }
    }
}

private struct LiquidControlCenter: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var loginItem = LoginItemController.shared

    var body: some View {
        VStack(spacing: 12) {
            liquidHeader
            if !model.isCustomizing {
                featureStrip
            }
            if let notice = model.featureNotice {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(notice).lineLimit(1)
                    Spacer()
                    Button {
                        model.featureNotice = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
                .padding(.horizontal, 10)
                .frame(height: 27)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            }
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(hex: "141416").opacity(0.975))
                .overlay {
                    LinearGradient(
                        colors: [.white.opacity(0.045), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.26), .white.opacity(0.07)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.7
                )
        }
        .shadow(color: .black.opacity(0.30), radius: 18, y: 10)
    }

    private var liquidHeader: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AperturePalette.accent)
            }
            .frame(width: 32, height: 32)

            Text("Aperture")
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
                    .monospacedDigit()
            }

            Menu {
                Button("Home", systemImage: "house") {
                    model.showHome()
                }
                Button("Customize Controls", systemImage: "slider.horizontal.3") {
                    model.showCustomization()
                }
                Divider()
                Menu("Take Screenshot", systemImage: "viewfinder") {
                    ForEach(ScreenshotMode.allCases) { mode in
                        Button(mode.title, systemImage: mode.icon) {
                            model.isExpanded = false
                            model.screenshots.capture(mode)
                        }
                    }
                }
                SettingsLink {
                    Label("Settings…", systemImage: "gearshape")
                }
                Toggle("Launch at Login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                Divider()
                Button("Collapse", systemImage: "chevron.up") {
                    model.isExpanded = false
                    model.showHome()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .apertureGlass(cornerRadius: 15, interactive: true, clear: true)
            .help("More")

            Button {
                model.isExpanded = false
                model.selectedFeature = nil
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .apertureGlass(cornerRadius: 13, interactive: true, clear: true)
            .help("Close Aperture")
        }
        .foregroundStyle(.white)
        .frame(height: 34)
    }

    private var featureStrip: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Array(featureRows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row) { feature in
                        FeatureLaunchButton(
                            feature: feature,
                            size: model.moduleSize(for: feature),
                            model: model
                        )
                        .gridCellColumns(model.moduleSize(for: feature).columnSpan)
                    }
                }
            }
        }
    }

    private var featureRows: [[ApertureFeature]] {
        var rows: [[ApertureFeature]] = []
        var current: [ApertureFeature] = []
        var columns = 0
        for feature in model.orderedEnabledFeatures {
            let span = model.moduleSize(for: feature).columnSpan
            if columns + span > 6, !current.isEmpty {
                rows.append(current)
                current = []
                columns = 0
            }
            current.append(feature)
            columns += span
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }

    @ViewBuilder
    private var detail: some View {
        if model.isCustomizing {
            FeatureCustomizationView(model: model)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        } else if let feature = model.selectedFeature, model.enabledFeatures.contains(feature) {
            Group {
                switch feature {
                case .assistant:
                    CompactAssistantPanel(model: model)
                case .music:
                    MusicNotchView(controller: model.music)
                case .screenshots:
                    ScreenshotNotchView(controller: model.screenshots)
                case .notifications:
                    NotificationNotchView(center: model.notifications)
                case .widgets:
                    WidgetDeckView(model: model)
                case .browse:
                    BrowseNotchView(controller: model.browser)
                case .dock:
                    DockStudioView(controller: model.dock)
                case .focus:
                    SoloFeatureView(kind: .focus, title: "Flow chamber", caption: "One timer. One intention.")
                case .clipboard:
                    SoloFeatureView(kind: .clipboard, title: "Clipboard lens", caption: "The last thing you copied, held close.")
                case .dropShelf:
                    PocketNotchView(controller: model.pocket)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        } else {
            ApertureHome(model: model)
                .transition(.opacity)
        }
    }
}

private struct FeatureLaunchButton: View {
    let feature: ApertureFeature
    let size: ControlModuleSize
    @ObservedObject var model: AppModel
    @State private var isHovering = false

    private var isSelected: Bool { model.selectedFeature == feature }
    var body: some View {
        Button {
            if isSelected { model.showHome() } else { model.selectFeature(feature) }
        } label: {
            Group {
                if size == .wide {
                    HStack(spacing: 9) {
                        moduleIcon
                        VStack(alignment: .leading, spacing: 1) {
                            Text(feature.title)
                                .font(.system(size: 10, weight: .semibold))
                            Text(feature.subtitle)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 11)
                } else {
                    VStack(spacing: 4) {
                        moduleIcon
                        Text(compactTitle)
                            .font(.system(size: 8, weight: .medium))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(isSelected ? AperturePalette.accent.opacity(0.16) : Color.white.opacity(isHovering ? 0.075 : 0.038))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(isSelected ? AperturePalette.accent.opacity(0.28) : Color.white.opacity(0.07), lineWidth: 0.6)
        }
        .scaleEffect(isHovering ? 1.012 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.78), value: isHovering)
        .onHover { isHovering = $0 }
    }

    private var moduleIcon: some View {
        Image(systemName: feature.icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isSelected ? .white : AperturePalette.accent)
            .frame(width: size == .wide ? 28 : nil, height: size == .wide ? 28 : nil)
            .background(size == .wide ? AperturePalette.accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 9))
    }

    private var compactTitle: String {
        switch feature {
        case .assistant: return "AI"
        case .screenshots: return "Capture"
        case .notifications: return "Alerts"
        case .widgets: return "Deck"
        case .browse: return "Browse"
        case .dock: return "Dock"
        case .clipboard: return "Clip"
        case .dropShelf: return "Pocket"
        default: return feature.title
        }
    }
}

private struct FeatureCustomizationView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Customize Controls")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Choose what appears and arrange the launcher.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reset", action: model.resetFeatureLayout)
                    .buttonStyle(.borderless)
                    .font(.system(size: 10))
                Button("Done", action: model.showHome)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(model.featureOrder.enumerated()), id: \.element) { index, feature in
                        HStack(spacing: 10) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(model.enabledFeatures.contains(feature) ? AperturePalette.accent : .secondary)
                                .frame(width: 28, height: 28)
                                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(feature.title).font(.system(size: 11, weight: .semibold))
                                Text(feature.subtitle).font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { model.moveFeature(feature, by: -1) } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)
                            Button { model.moveFeature(feature, by: 1) } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.plain)
                            .disabled(index == model.featureOrder.count - 1)
                            Picker("Size", selection: Binding(
                                get: { model.moduleSize(for: feature) },
                                set: { model.setModuleSize($0, for: feature) }
                            )) {
                                ForEach(ControlModuleSize.allCases) { size in
                                    Image(systemName: size == .wide ? "rectangle" : "square").tag(size)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 64)
                            Toggle("", isOn: Binding(
                                get: { model.enabledFeatures.contains(feature) },
                                set: { model.setFeature(feature, enabled: $0, select: false) }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(AperturePalette.accent)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 48)
                        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.primary)
        .padding(14)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct MusicNotchView: View {
    @ObservedObject var controller: MusicController
    @ObservedObject private var catalog = BrowseController.shared.music
    @State private var isBrowsing = false

    var body: some View {
        Group {
            if isBrowsing {
                VStack(spacing: 10) {
                    HStack {
                        Button {
                            isBrowsing = false
                        } label: {
                            Label("Now Playing", systemImage: "chevron.left")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        Spacer()
                        Button("Pop Out") { BrowseController.shared.openMusic(query: catalog.query) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    MusicCatalogView(controller: catalog, compact: true)
                }
                .padding(14)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                nowPlaying
            }
        }
        .foregroundStyle(.primary)
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
    }

    private var nowPlaying: some View {
        HStack(spacing: 18) {
            artwork
                .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 6) {
                Text(controller.title)
                    .font(.system(size: 19, weight: .semibold))
                    .lineLimit(1)
                Text(controller.artist)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !controller.album.isEmpty {
                    Text(controller.album)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 3)

                HStack(spacing: 18) {
                    musicButton("backward.fill", action: controller.previous)
                    Button(action: controller.togglePlayback) {
                        Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                    musicButton("forward.fill", action: controller.next)
                    Spacer()
                    Button("Browse Music") {
                        isBrowsing = true
                        if catalog.results.isEmpty { catalog.search("new music") }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button("Open Music", action: controller.openMusic)
                        .buttonStyle(.borderless)
                        .font(.system(size: 10, weight: .medium))
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(16)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = controller.artwork {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func musicButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}

private struct ScreenshotNotchView: View {
    @ObservedObject var controller: ScreenshotController

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ScreenshotMode.allCases) { mode in
                    Button {
                        AppModel.shared.isExpanded = false
                        controller.capture(mode)
                    } label: {
                        VStack(spacing: 9) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 20, weight: .medium))
                            Text(mode.title)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 76)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(controller.isCapturing)
                }
            }

            HStack {
                Text(controller.statusMessage ?? "Screenshots save to Pictures/Aperture Captures")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Show in Finder") { controller.reveal() }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10, weight: .medium))
            }

            if !controller.hasScreenAccess {
                HStack(spacing: 9) {
                    Image(systemName: "lock.shield")
                    Text("macOS screen access is required for captures.")
                        .font(.system(size: 10, weight: .medium))
                    Spacer()
                    Button("Open Settings", action: controller.openScreenRecordingSettings)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .foregroundStyle(.secondary)
            }

            if !controller.captures.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 9) {
                        ForEach(controller.captures.prefix(6), id: \.self) { url in
                            ScreenshotThumbnail(url: url) { controller.reveal(url) }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .foregroundStyle(.primary)
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onAppear { controller.refreshAccess() }
    }
}

private struct ScreenshotThumbnail: View {
    let url: URL
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let image = NSImage(contentsOf: url) {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .frame(width: 92, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

private struct NotificationNotchView: View {
    @ObservedObject var center: ApertureNotificationCenter

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aperture Activity")
                        .font(.system(size: 16, weight: .semibold))
                    Text("System notifications: \(center.authorizationLabel)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if center.authorizationLabel != "Allowed" {
                    Button("Enable", action: center.requestAuthorization)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                Button("Clear", action: center.clear)
                    .buttonStyle(.borderless)
                    .font(.system(size: 10))
            }

            if center.notices.isEmpty {
                ContentUnavailableView(
                    "No Recent Activity",
                    systemImage: "bell.slash",
                    description: Text("Screenshots, timers, and Aperture actions will appear here.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(center.notices) { notice in
                            HStack(spacing: 11) {
                                Image(systemName: "bell.fill")
                                    .foregroundStyle(AperturePalette.accent)
                                    .frame(width: 28, height: 28)
                                    .background(AperturePalette.accent.opacity(0.10), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(notice.title).font(.system(size: 11, weight: .semibold))
                                    Text(notice.body).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer()
                                Text(notice.date, style: .time)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(10)
                            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .foregroundStyle(.primary)
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onAppear { center.refreshAuthorization() }
    }
}

private struct ApertureHome: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var music = MusicController.shared
    @ObservedObject private var notifications = ApertureNotificationCenter.shared
    @StateObject private var monitor = SystemMonitor()

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 40, weight: .light))
                        .monospacedDigit()
                    Text(context.date, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(width: 1, height: 42)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle().fill(AperturePalette.mint).frame(width: 5, height: 5)
                    Text(monitor.thermalLabel.capitalized)
                        .font(.system(size: 11, weight: .semibold))
                }
                Label("\(model.enabledFeatures.count) features on", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Label(music.title, systemImage: "music.note")
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Label("\(notifications.notices.count) recent alerts", systemImage: "bell")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 160, alignment: .trailing)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onAppear { music.start() }
        .onDisappear { music.stop() }
    }
}

private struct SoloFeatureView: View {
    let kind: WidgetKind
    let title: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(caption)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.52))
                }
                Spacer()
                Image(systemName: kind.icon)
                    .foregroundStyle(Color(hex: kind.tint))
            }
            WidgetContainer(kind: kind)
                .frame(maxHeight: .infinity)
        }
        .foregroundStyle(.white)
    }
}
