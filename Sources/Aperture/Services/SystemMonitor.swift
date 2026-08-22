import Foundation

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var uptime = "—"
    @Published private(set) var lowPower = false
    @Published private(set) var thermalLabel = "NOMINAL"
    @Published private(set) var activityBars = 8

    let coreCount = ProcessInfo.processInfo.activeProcessorCount
    private var timer: Timer?

    init() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }

    private func update() {
        let info = ProcessInfo.processInfo
        let hours = Int(info.systemUptime / 3600)
        uptime = hours < 24 ? "\(hours)H" : "\(hours / 24)D"
        lowPower = info.isLowPowerModeEnabled
        thermalLabel = switch info.thermalState {
        case .nominal: "NOMINAL"
        case .fair: "WARM"
        case .serious: "HOT"
        case .critical: "CRITICAL"
        @unknown default: "UNKNOWN"
        }
        activityBars = max(4, min(18, Int.random(in: 6...15)))
    }
}
