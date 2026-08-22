import AppKit
import CoreGraphics
import Foundation

enum ScreenshotMode: String, CaseIterable, Identifiable {
    case area
    case window
    case screen
    case clipboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .area: return "Selection"
        case .window: return "Window"
        case .screen: return "Full Screen"
        case .clipboard: return "Clipboard"
        }
    }

    var icon: String {
        switch self {
        case .area: return "viewfinder"
        case .window: return "macwindow"
        case .screen: return "display"
        case .clipboard: return "doc.on.clipboard"
        }
    }
}

@MainActor
final class ScreenshotController: ObservableObject {
    static let shared = ScreenshotController()

    @Published private(set) var captures: [URL] = []
    @Published private(set) var isCapturing = false
    @Published private(set) var hasScreenAccess = CGPreflightScreenCaptureAccess()
    @Published var statusMessage: String?

    private let fileManager = FileManager.default

    private init() {
        loadRecentCaptures()
    }

    var outputFolder: URL {
        let base = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appending(path: "Pictures")
        return base.appending(path: "Aperture Captures", directoryHint: .isDirectory)
    }

    func capture(_ mode: ScreenshotMode) {
        guard !isCapturing else { return }
        hasScreenAccess = CGPreflightScreenCaptureAccess()
        guard hasScreenAccess else {
            requestScreenAccess()
            return
        }
        isCapturing = true
        statusMessage = mode == .screen ? "Capturing display…" : "Choose what to capture…"

        Task {
            try? await Task.sleep(for: .milliseconds(320))
            let result = await runCapture(mode)
            isCapturing = false

            switch result {
            case .success(let url):
                if let url {
                    captures.removeAll { $0 == url }
                    captures.insert(url, at: 0)
                    if captures.count > 8 { captures.removeLast(captures.count - 8) }
                    statusMessage = "Saved to Pictures"
                    ApertureNotificationCenter.shared.post(
                        title: "Screenshot Saved",
                        body: url.lastPathComponent
                    )
                } else {
                    statusMessage = "Copied to the clipboard"
                    ApertureNotificationCenter.shared.post(
                        title: "Screenshot Copied",
                        body: "The capture is ready to paste."
                    )
                }
            case .failure(let error):
                statusMessage = error.localizedDescription
            }
        }
    }

    func refreshAccess() {
        hasScreenAccess = CGPreflightScreenCaptureAccess()
    }

    func requestScreenAccess() {
        Task.detached(priority: .userInitiated) {
            let granted = CGRequestScreenCaptureAccess()
            await MainActor.run {
                self.hasScreenAccess = granted || CGPreflightScreenCaptureAccess()
                if self.hasScreenAccess {
                    self.statusMessage = "Screen access enabled"
                } else {
                    self.statusMessage = "Allow Aperture in Privacy & Security → Screen & System Audio Recording"
                    self.openScreenRecordingSettings()
                }
            }
        }
    }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func reveal(_ url: URL? = nil) {
        if let url {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            try? fileManager.createDirectory(at: outputFolder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(outputFolder)
        }
    }

    private func loadRecentCaptures() {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: outputFolder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        captures = urls
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { lhs, rhs in
                let left = try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                let right = try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                return (left ?? .distantPast) > (right ?? .distantPast)
            }
            .prefix(8)
            .map { $0 }
    }

    private func runCapture(_ mode: ScreenshotMode) async -> Result<URL?, Error> {
        let folder = outputFolder
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return .failure(error)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = folder.appending(path: "Aperture \(formatter.string(from: Date())).png")
        let arguments: [String]
        switch mode {
        case .area: arguments = ["-i", "-s", url.path]
        case .window: arguments = ["-i", "-w", url.path]
        case .screen: arguments = ["-x", url.path]
        case .clipboard: arguments = ["-i", "-c"]
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = arguments
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume(returning: .success(mode == .clipboard ? nil : url))
                } else {
                    continuation.resume(returning: .failure(NSError(
                        domain: "Aperture.Screenshot",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: "Capture was cancelled or macOS denied screen access."]
                    )))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: .failure(error))
            }
        }
    }
}
