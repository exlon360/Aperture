import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var assistantController: AssistantController
    @ObservedObject private var browseController: BrowseController
    @ObservedObject private var desktopWidgets = DesktopWidgetManager.shared
    @ObservedObject private var loginItem = LoginItemController.shared

    init(model: AppModel) {
        self.model = model
        self.assistantController = model.assistant
        self.browseController = model.browser
    }

    var body: some View {
        TabView {
            general
                .tabItem { Label("General", systemImage: "capsule.inset.filled") }
            assistant
                .tabItem { Label("Local AI", systemImage: "sparkles") }
            browse
                .tabItem { Label("Browse", systemImage: "safari.fill") }
            widgets
                .tabItem { Label("Widgets", systemImage: "square.grid.2x2") }
        }
        .padding(20)
        .frame(width: 580, height: 450)
    }

    private var general: some View {
        Form {
            Section("Aperture behavior") {
                LabeledContent("Activation") {
                    Text("Hover over hardware notch")
                }
                Toggle("Collapse after the pointer leaves", isOn: $model.collapseAfterHover)
                Toggle("Show the clock in compact mode", isOn: $model.compactClock)
                Toggle("Launch Aperture automatically at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                if loginItem.statusMessage != "Enabled" && loginItem.statusMessage != "Off" {
                    HStack {
                        Text(loginItem.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") { loginItem.openSettings() }
                    }
                }
            }

            Section("Feature toggles") {
                ForEach(model.featureOrder) { feature in
                    Toggle(feature.title, isOn: Binding(
                        get: { model.enabledFeatures.contains(feature) },
                        set: { model.setFeature(feature, enabled: $0, select: false) }
                    ))
                }
            }

            Section("Placement") {
                LabeledContent("Display") {
                    Text(model.notchMetrics.hasHardwareNotch ? "Built-in camera housing" : "Floating fallback")
                }
                Text("Aperture prefers the built-in hardware notch. On a display without one, it becomes a centered floating aperture.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Label("Local inference stays on this Mac. Only an explicit Web Search sends the query to Ollama’s search service.", systemImage: "lock.shield.fill")
                    .foregroundStyle(.secondary)
            }

            Section("System access") {
                LabeledContent("Notifications") {
                    Text(model.notifications.authorizationLabel)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Enable Notifications") {
                        model.notifications.requestAuthorization()
                    }
                    Button("Screen Recording Settings") {
                        model.screenshots.openScreenRecordingSettings()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            model.notifications.refreshAuthorization()
            loginItem.refresh()
        }
    }

    private var assistant: some View {
        Form {
            Section("Local inference model") {
                Picker("Engine", selection: $model.localAIEngine) {
                    Text("Apple On-Device").tag(LocalAIEngine.apple)
                    Text("Ollama").tag(LocalAIEngine.ollama)
                }
                .onChange(of: model.localAIEngine) { assistantController.probe() }

                if model.localAIEngine == .ollama {
                    Picker("Installed model", selection: $model.ollamaModel) {
                        if !assistantController.availableModels.contains(model.ollamaModel) {
                            Text(model.ollamaModel).tag(model.ollamaModel)
                        }
                        ForEach(assistantController.availableModels, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .onChange(of: model.ollamaModel) { assistantController.probe() }
                    TextField("Ollama endpoint", text: $model.ollamaEndpoint)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Button("Refresh Models") { assistantController.probe() }
                    Circle()
                        .fill(assistantController.status == .ready ? AperturePalette.mint : AperturePalette.accent)
                        .frame(width: 7, height: 7)
                    Text(assistantController.status.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let reason = assistantController.failureReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Aperture uses exactly the model you select. It does not silently switch engines.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.localAIEngine == .ollama {
                Section("Get local models") {
                    Text("Choose a model to download directly through Ollama. Downloads are opt-in and stay on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(OllamaModelPreset.catalog) { preset in
                        modelCatalogRow(preset)
                    }

                    if let notice = assistantController.modelInstallNotice {
                        Label(notice, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AperturePalette.mint)
                    }
                    if let error = assistantController.modelInstallError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(AperturePalette.accent)
                    }

                    HStack {
                        Link("Install Ollama", destination: URL(string: "https://ollama.com/download")!)
                        Spacer()
                        Text("Models are provided under their publishers’ terms.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Section("Optional Web Search") {
                SecureField("Ollama API key", text: $model.ollamaWebSearchKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Label(model.ollamaWebSearchKey.isEmpty ? "Key required" : "Stored in Keychain", systemImage: model.ollamaWebSearchKey.isEmpty ? "key" : "checkmark.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Link("Web Search setup", destination: URL(string: "https://ollama.com/blog/web-search")!)
                }
                Text("The Web button beside the composer is off by default. When enabled, your query and the returned result text use Ollama’s web API; the selected model still writes the answer locally.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { assistantController.probe() }
    }

    @ViewBuilder
    private func modelCatalogRow(_ preset: OllamaModelPreset) -> some View {
        HStack(spacing: 12) {
            Image(systemName: preset.systemImage)
                .foregroundStyle(AperturePalette.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.title)
                    .font(.callout.weight(.semibold))
                Text("\(preset.detail) · \(preset.downloadSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if assistantController.downloadingModel == preset.id {
                VStack(alignment: .trailing, spacing: 4) {
                    if let progress = assistantController.downloadProgress {
                        ProgressView(value: progress)
                            .frame(width: 92)
                        Text("\(Int(progress * 100))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                    if let status = assistantController.downloadStatus {
                        Text(status)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else if assistantController.availableModels.contains(preset.id) {
                Button(model.ollamaModel == preset.id ? "Selected" : "Use") {
                    model.selectOllamaModel(preset.id)
                }
                .disabled(model.ollamaModel == preset.id && model.localAIEngine == .ollama)
            } else {
                Button("Download") {
                    assistantController.install(preset, endpoint: model.ollamaEndpoint) {
                        model.selectOllamaModel(preset.id)
                    }
                }
                .disabled(assistantController.downloadingModel != nil)
            }
        }
    }

    private var widgets: some View {
        Form {
            Section("Desktop widgets") {
                LabeledContent("Placed") {
                    Text("\(desktopWidgets.count)")
                }
                Menu("Add Widget to Desktop") {
                    ForEach(WidgetKind.allCases) { kind in
                        Button(kind.title) { desktopWidgets.place(kind) }
                    }
                }
                if desktopWidgets.count > 0 {
                    ForEach(desktopWidgets.records) { record in
                        HStack {
                            Label(record.kind.title, systemImage: record.kind.icon)
                            Spacer()
                            Button("Remove") { desktopWidgets.remove(record.id) }
                        }
                    }
                    Button("Remove All", role: .destructive) {
                        desktopWidgets.removeAll()
                    }
                }
            }

            Section("Visible in the deck") {
                ForEach(WidgetKind.allCases) { kind in
                    Toggle(isOn: Binding(
                        get: { model.enabledWidgets.contains(kind) },
                        set: { enabled in
                            if enabled != model.enabledWidgets.contains(kind) {
                                model.toggleWidget(kind)
                            }
                        }
                    )) {
                        Label(kind.title, systemImage: kind.icon)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var browse: some View {
        Form {
            Section("Web browser") {
                Picker("Search provider", selection: $browseController.searchProvider) {
                    ForEach(WebSearchProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                HStack {
                    Button("Open Browse Window") { browseController.openWeb() }
                    Button("Browse Music") { browseController.openMusic() }
                    Button("Open YouTube") { browseController.openYouTube() }
                }
                Text("Browse is a normal web window and does not require your AI search key. Choose Browse from the notch to search without starting an AI chat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Control Center layout") {
                Text("Use Aperture’s three-dot menu → Customize Controls to reorder modules, hide them, or switch each tile between compact and wide.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Customize Now") {
                    model.showCustomization()
                }
            }
        }
        .formStyle(.grouped)
    }
}
