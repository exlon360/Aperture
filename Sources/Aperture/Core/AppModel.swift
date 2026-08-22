import AppKit
import Combine
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var isExpanded = false
    @Published var activeSection: ApertureSection = .widgets
    @Published var assistantIsOpen = false
    @Published var selectedFeature: ApertureFeature?
    @Published var isCustomizing = false
    @Published var notchMetrics = NotchMetrics.fallback
    @Published var featureNotice: String?
    @Published var enabledFeatures: Set<ApertureFeature> {
        didSet { persistFeatures() }
    }
    @Published var featureOrder: [ApertureFeature] {
        didSet { persistFeatureOrder() }
    }
    @Published var featureSizes: [ApertureFeature: ControlModuleSize] {
        didSet { persistFeatureSizes() }
    }
    @Published var expandOnHover: Bool {
        didSet { defaults.set(expandOnHover, forKey: Keys.expandOnHover) }
    }
    @Published var collapseAfterHover: Bool {
        didSet { defaults.set(collapseAfterHover, forKey: Keys.collapseAfterHover) }
    }
    @Published var compactClock: Bool {
        didSet { defaults.set(compactClock, forKey: Keys.compactClock) }
    }
    @Published var enabledWidgets: [WidgetKind] {
        didSet { persistWidgets() }
    }
    @Published var ollamaEndpoint: String {
        didSet { defaults.set(ollamaEndpoint, forKey: Keys.endpoint) }
    }
    @Published var ollamaModel: String {
        didSet { defaults.set(ollamaModel, forKey: Keys.model) }
    }
    @Published var localAIEngine: LocalAIEngine {
        didSet { defaults.set(localAIEngine.rawValue, forKey: Keys.localAIEngine) }
    }
    @Published var ollamaWebSearchKey: String {
        didSet { SecureStore.save(ollamaWebSearchKey, account: Keys.webSearchKey) }
    }

    let assistant = AssistantController()
    let browser = BrowseController.shared
    let dock = DockController()
    let music = MusicController.shared
    let screenshots = ScreenshotController.shared
    let notifications = ApertureNotificationCenter.shared
    let pocket = PocketController.shared
    let loginItem = LoginItemController.shared

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let expandOnHover = "expandOnHover"
        static let collapseAfterHover = "collapseAfterHover"
        static let compactClock = "compactClock"
        static let enabledWidgets = "enabledWidgets"
        static let enabledFeatures = "enabledFeatures"
        static let featureOrder = "featureOrder"
        static let featureSizes = "featureSizes"
        static let endpoint = "ollamaEndpoint"
        static let model = "ollamaModel"
        static let localAIEngine = "localAIEngine"
        static let webSearchKey = "ollamaWebSearchKey"
        static let behaviorVersion = "behaviorVersion"
        static let featureToggleVersion = "featureToggleVersion"
    }

    private init() {
        let isNewHoverBehavior = defaults.integer(forKey: Keys.behaviorVersion) < 2
        expandOnHover = isNewHoverBehavior ? true : (defaults.object(forKey: Keys.expandOnHover) as? Bool ?? true)
        collapseAfterHover = defaults.object(forKey: Keys.collapseAfterHover) as? Bool ?? true
        compactClock = defaults.object(forKey: Keys.compactClock) as? Bool ?? true
        ollamaEndpoint = defaults.string(forKey: Keys.endpoint) ?? "http://127.0.0.1:11434"
        ollamaModel = defaults.string(forKey: Keys.model) ?? "llama3.2:3b"
        localAIEngine = LocalAIEngine(rawValue: defaults.string(forKey: Keys.localAIEngine) ?? "") ?? .apple
        ollamaWebSearchKey = SecureStore.read(account: Keys.webSearchKey) ?? ""
        selectedFeature = nil

        if let data = defaults.data(forKey: Keys.featureOrder),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            let valid = decoded.compactMap(ApertureFeature.init(rawValue:))
            featureOrder = valid + ApertureFeature.allCases.filter { !valid.contains($0) }
        } else {
            featureOrder = ApertureFeature.allCases
        }

        if let data = defaults.data(forKey: Keys.featureSizes),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            featureSizes = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
                guard let feature = ApertureFeature(rawValue: key),
                      let size = ControlModuleSize(rawValue: value) else { return nil }
                return (feature, size)
            })
        } else {
            featureSizes = [.music: .wide, .browse: .wide]
        }

        if let data = defaults.data(forKey: Keys.enabledFeatures),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            enabledFeatures = Set(decoded.compactMap(ApertureFeature.init(rawValue:)))
        } else {
            // Local AI stays intentionally off until the person enables it.
            enabledFeatures = [.music, .screenshots, .notifications, .widgets, .browse, .dock, .focus, .clipboard, .dropShelf]
        }
        if let data = defaults.data(forKey: Keys.enabledWidgets),
           let decoded = try? JSONDecoder().decode([WidgetKind].self, from: data) {
            enabledWidgets = decoded
        } else {
            enabledWidgets = [.focus, .pulse, .clipboard, .quickLaunch, .dropShelf, .dayline]
        }
        if defaults.integer(forKey: Keys.featureToggleVersion) < 1 {
            enabledFeatures.remove(.assistant)
            defaults.set(1, forKey: Keys.featureToggleVersion)
        }
        if defaults.integer(forKey: Keys.featureToggleVersion) < 2 {
            enabledFeatures.formUnion([.music, .screenshots, .notifications])
            defaults.set(2, forKey: Keys.featureToggleVersion)
        }
        if defaults.integer(forKey: Keys.featureToggleVersion) < 3 {
            enabledFeatures.formUnion([.browse, .dock])
            defaults.set(3, forKey: Keys.featureToggleVersion)
        }

        defaults.set(true, forKey: Keys.expandOnHover)
        defaults.set(2, forKey: Keys.behaviorVersion)

        assistant.configurationProvider = { [weak self] in
            guard let self else { return .fallback }
            return AssistantConfiguration(
                endpoint: self.ollamaEndpoint,
                model: self.ollamaModel,
                engine: self.localAIEngine,
                webSearchKey: self.ollamaWebSearchKey
            )
        }

        // Useful for previews, UI tests, and launchers that want to open a destination directly.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--expanded") {
            isExpanded = true
        }
        if let sectionValue = arguments.first(where: { $0.hasPrefix("--section=") })?.split(separator: "=").last,
           let section = ApertureSection.allCases.first(where: { $0.rawValue.lowercased().replacingOccurrences(of: " ", with: "-") == sectionValue.lowercased() }) {
            activeSection = section
            assistantIsOpen = section == .assistant
            selectedFeature = switch section {
            case .widgets: .widgets
            case .assistant: .assistant
            case .browse: .browse
            case .dock: .dock
            }
            enabledFeatures.insert(selectedFeature!)
            isExpanded = true
        }
        if let featureValue = arguments.first(where: { $0.hasPrefix("--feature=") })?.split(separator: "=").last,
           let feature = ApertureFeature(rawValue: String(featureValue)) {
            enabledFeatures.insert(feature)
            selectedFeature = feature
            switch feature {
            case .assistant: activeSection = .assistant; assistantIsOpen = true
            case .browse: activeSection = .browse; assistantIsOpen = false
            case .dock: activeSection = .dock; assistantIsOpen = false
            default: activeSection = .widgets; assistantIsOpen = false
            }
            isExpanded = true
        }
        if arguments.contains("--customize") {
            isCustomizing = true
            selectedFeature = nil
            isExpanded = true
        }
    }

    var desiredPanelSize: CGSize {
        guard isExpanded else {
            if notchMetrics.hasHardwareNotch {
                return CGSize(width: notchMetrics.width, height: notchMetrics.height)
            }
            return CGSize(width: 250, height: 42)
        }
        if isCustomizing {
            return CGSize(width: 620, height: notchMetrics.height + 570)
        }
        let width: CGFloat = switch selectedFeature {
        case .assistant: 670
        case .music: 680
        case .screenshots, .notifications: 640
        case .widgets: 700
        case .browse: 790
        case .dock: 700
        case .focus, .clipboard, .dropShelf: 560
        case nil: 560
        }
        let menuHeight: CGFloat = switch selectedFeature {
        case .assistant: 500
        case .music: 500
        case .screenshots, .notifications: 440
        case .widgets: 570
        case .browse: 605
        case .dock: 510
        case .focus, .clipboard, .dropShelf: 410
        case nil: 255
        }
        return CGSize(width: width, height: notchMetrics.height + menuHeight)
    }

    func open(_ section: ApertureSection) {
        activeSection = section
        assistantIsOpen = section == .assistant
        let feature: ApertureFeature = switch section {
        case .widgets: .widgets
        case .assistant: .assistant
        case .browse: .browse
        case .dock: .dock
        }
        enabledFeatures.insert(feature)
        selectedFeature = feature
        isExpanded = true
    }

    var orderedEnabledFeatures: [ApertureFeature] {
        featureOrder.filter { enabledFeatures.contains($0) }
    }

    func showHome() {
        selectedFeature = nil
        isCustomizing = false
    }

    func showCustomization() {
        selectedFeature = nil
        isCustomizing = true
        isExpanded = true
    }

    func setFeature(_ feature: ApertureFeature, enabled: Bool, select: Bool = true) {
        if enabled {
            enabledFeatures.insert(feature)
            if select { selectedFeature = feature }
            if select { isCustomizing = false }
            switch feature {
            case .assistant:
                activeSection = .assistant
                assistantIsOpen = true
            case .music, .screenshots, .notifications:
                activeSection = .widgets
                assistantIsOpen = false
            case .browse:
                activeSection = .browse
                assistantIsOpen = false
            case .dock:
                activeSection = .dock
                assistantIsOpen = false
            default:
                activeSection = .widgets
                assistantIsOpen = false
            }
        } else {
            enabledFeatures.remove(feature)
            if selectedFeature == feature { selectedFeature = nil }
            if feature == .assistant { assistantIsOpen = false }
        }
    }

    func selectFeature(_ feature: ApertureFeature) {
        guard enabledFeatures.contains(feature) else { return }
        selectedFeature = feature
        isCustomizing = false
        switch feature {
        case .assistant: activeSection = .assistant; assistantIsOpen = true
        case .music, .screenshots, .notifications: activeSection = .widgets; assistantIsOpen = false
        case .browse: activeSection = .browse; assistantIsOpen = false
        case .dock: activeSection = .dock; assistantIsOpen = false
        default: activeSection = .widgets; assistantIsOpen = false
        }
    }

    func updateNotchMetrics(_ metrics: NotchMetrics) {
        guard notchMetrics != metrics else { return }
        notchMetrics = metrics
    }

    func toggleWidget(_ kind: WidgetKind) {
        if let index = enabledWidgets.firstIndex(of: kind) {
            guard enabledWidgets.count > 1 else { return }
            enabledWidgets.remove(at: index)
        } else {
            enabledWidgets.append(kind)
        }
    }

    func moveFeature(_ feature: ApertureFeature, by offset: Int) {
        guard let index = featureOrder.firstIndex(of: feature) else { return }
        let destination = min(max(0, index + offset), featureOrder.count - 1)
        guard destination != index else { return }
        featureOrder.move(fromOffsets: IndexSet(integer: index), toOffset: destination > index ? destination + 1 : destination)
    }

    func resetFeatureLayout() {
        featureOrder = ApertureFeature.allCases
        featureSizes = [.music: .wide, .browse: .wide]
        enabledFeatures = [.music, .screenshots, .notifications, .widgets, .browse, .dock, .focus, .clipboard, .dropShelf]
        showHome()
    }

    func setModuleSize(_ size: ControlModuleSize, for feature: ApertureFeature) {
        featureSizes[feature] = size
    }

    func moduleSize(for feature: ApertureFeature) -> ControlModuleSize {
        featureSizes[feature] ?? .compact
    }

    func selectAppleModel() {
        localAIEngine = .apple
        assistant.probe()
    }

    func selectOllamaModel(_ name: String) {
        ollamaModel = name
        localAIEngine = .ollama
        assistant.probe()
    }

    private func persistWidgets() {
        guard let data = try? JSONEncoder().encode(enabledWidgets) else { return }
        defaults.set(data, forKey: Keys.enabledWidgets)
    }

    private func persistFeatures() {
        guard let data = try? JSONEncoder().encode(enabledFeatures) else { return }
        defaults.set(data, forKey: Keys.enabledFeatures)
    }

    private func persistFeatureOrder() {
        guard let data = try? JSONEncoder().encode(featureOrder) else { return }
        defaults.set(data, forKey: Keys.featureOrder)
    }

    private func persistFeatureSizes() {
        let raw = Dictionary(uniqueKeysWithValues: featureSizes.map { ($0.key.rawValue, $0.value.rawValue) })
        guard let data = try? JSONEncoder().encode(raw) else { return }
        defaults.set(data, forKey: Keys.featureSizes)
    }
}
