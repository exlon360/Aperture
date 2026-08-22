import Foundation

enum ApertureSection: String, CaseIterable, Identifiable {
    case widgets = "Widgets"
    case assistant = "Local AI"
    case browse = "Browse"
    case dock = "Dock"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .widgets: return "square.grid.2x2"
        case .assistant: return "sparkles"
        case .browse: return "safari.fill"
        case .dock: return "dock.rectangle"
        }
    }
}

struct NotchMetrics: Equatable {
    var width: CGFloat
    var height: CGFloat
    var hasHardwareNotch: Bool

    static let fallback = NotchMetrics(width: 190, height: 32, hasHardwareNotch: false)
}

enum ApertureFeature: String, CaseIterable, Codable, Identifiable {
    case assistant
    case music
    case screenshots
    case notifications
    case widgets
    case browse
    case dock
    case focus
    case clipboard
    case dropShelf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .assistant: return "Local AI"
        case .music: return "Music"
        case .screenshots: return "Capture"
        case .notifications: return "Alerts"
        case .widgets: return "Widgets"
        case .browse: return "Browse"
        case .dock: return "Dock"
        case .focus: return "Focus"
        case .clipboard: return "Clipboard"
        case .dropShelf: return "Pocket"
        }
    }

    var subtitle: String {
        switch self {
        case .assistant: return "Private sidekick"
        case .music: return "Now playing"
        case .screenshots: return "Screenshot tools"
        case .notifications: return "Recent activity"
        case .widgets: return "Your glance deck"
        case .browse: return "Web, music and video"
        case .dock: return "System layout"
        case .focus: return "25 minute flow"
        case .clipboard: return "Latest copied text"
        case .dropShelf: return "Drag files to the notch"
        }
    }

    var icon: String {
        switch self {
        case .assistant: return "apple.intelligence"
        case .music: return "music.note"
        case .screenshots: return "viewfinder"
        case .notifications: return "bell.fill"
        case .widgets: return "square.grid.2x2.fill"
        case .browse: return "safari.fill"
        case .dock: return "dock.rectangle"
        case .focus: return "timer"
        case .clipboard: return "doc.on.clipboard.fill"
        case .dropShelf: return "tray.full.fill"
        }
    }

    var tint: String {
        switch self {
        case .assistant: return "8E8E93"
        case .music: return "8E8E93"
        case .screenshots: return "8E8E93"
        case .notifications: return "8E8E93"
        case .widgets: return "7D7D82"
        case .browse: return "C4C7CD"
        case .dock: return "98989D"
        case .focus: return "77777B"
        case .clipboard: return "85858A"
        case .dropShelf: return "929297"
        }
    }
}

enum ControlModuleSize: String, CaseIterable, Codable, Identifiable {
    case compact
    case wide

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var columnSpan: Int { self == .wide ? 2 : 1 }
}

enum WidgetKind: String, CaseIterable, Codable, Identifiable {
    case focus
    case clipboard
    case pulse
    case quickLaunch
    case dropShelf
    case dayline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "Flow"
        case .clipboard: return "Clipboard"
        case .pulse: return "Pulse"
        case .quickLaunch: return "Quick Launch"
        case .dropShelf: return "Pocket"
        case .dayline: return "Dayline"
        }
    }

    var subtitle: String {
        switch self {
        case .focus: return "A calm focus timer"
        case .clipboard: return "Your latest copied thought"
        case .pulse: return "A quiet system health check"
        case .quickLaunch: return "Four apps, one click away"
        case .dropShelf: return "The notch shelf, on your desktop"
        case .dayline: return "See the shape of today"
        }
    }

    var icon: String {
        switch self {
        case .focus: return "circle.dashed.inset.filled"
        case .clipboard: return "doc.on.clipboard"
        case .pulse: return "waveform.path.ecg"
        case .quickLaunch: return "square.grid.2x2.fill"
        case .dropShelf: return "tray.and.arrow.down.fill"
        case .dayline: return "sun.horizon.fill"
        }
    }

    var tint: String {
        switch self {
        case .focus: return "FF7A45"
        case .clipboard: return "9D8CFF"
        case .pulse: return "65D1B5"
        case .quickLaunch: return "FFCB66"
        case .dropShelf: return "72A8FF"
        case .dayline: return "FF9F9F"
        }
    }
}

struct ChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
