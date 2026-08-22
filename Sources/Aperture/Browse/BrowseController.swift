import AppKit
import Foundation
import SwiftUI
import WebKit

enum BrowseMode: String, CaseIterable, Identifiable {
    case web = "Web"
    case music = "Music"
    case youtube = "YouTube"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .web: return "safari.fill"
        case .music: return "music.note"
        case .youtube: return "play.rectangle.fill"
        }
    }
}

enum WebSearchProvider: String, CaseIterable, Identifiable {
    case duckDuckGo = "DuckDuckGo"
    case google = "Google"
    case bing = "Bing"

    var id: String { rawValue }

    func searchURL(for query: String) -> URL? {
        var components: URLComponents
        switch self {
        case .duckDuckGo: components = URLComponents(string: "https://duckduckgo.com/")!
        case .google: components = URLComponents(string: "https://www.google.com/search")!
        case .bing: components = URLComponents(string: "https://www.bing.com/search")!
        }
        components.queryItems = [URLQueryItem(name: self == .duckDuckGo ? "q" : "q", value: query)]
        return components.url
    }
}

@MainActor
final class BrowseController: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = BrowseController()

    @Published var mode: BrowseMode = .web
    @Published var searchProvider: WebSearchProvider {
        didSet { UserDefaults.standard.set(searchProvider.rawValue, forKey: "webSearchProvider") }
    }

    // The notch and optional pop-out window need separate WKWebViews. AppKit can
    // only attach a view to one hierarchy at a time.
    let browser = BrowserSession()
    let youtube = BrowserSession()
    let windowBrowser = BrowserSession()
    let windowYouTube = BrowserSession()
    let music = MusicCatalogController()
    private var window: NSWindow?

    private override init() {
        searchProvider = WebSearchProvider(rawValue: UserDefaults.standard.string(forKey: "webSearchProvider") ?? "") ?? .duckDuckGo
        super.init()
        youtube.prepareForYouTube()
        windowYouTube.prepareForYouTube()
    }

    func activateInline(_ newMode: BrowseMode) {
        mode = newMode
        switch newMode {
        case .web:
            if browser.webView.url == nil {
                browser.load(URL(string: "https://duckduckgo.com")!)
            }
        case .music:
            if music.results.isEmpty { music.search("new music") }
        case .youtube:
            if youtube.webView.url == nil {
                youtube.load(URL(string: "https://m.youtube.com")!)
            }
        }
    }

    func searchInlineWeb(_ query: String) {
        mode = .web
        browser.navigate(query, provider: searchProvider)
    }

    func searchInlineYouTube(_ query: String) {
        mode = .youtube
        let request = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty else {
            activateInline(.youtube)
            return
        }
        var components = URLComponents(string: "https://m.youtube.com/results")!
        components.queryItems = [URLQueryItem(name: "search_query", value: request)]
        youtube.load(components.url!)
    }

    func popOutCurrentMode() {
        switch mode {
        case .web:
            showWindow()
            windowBrowser.load(browser.webView.url ?? URL(string: "https://duckduckgo.com")!)
        case .music:
            openMusic(query: music.query)
        case .youtube:
            showWindow()
            windowYouTube.load(youtube.webView.url ?? URL(string: "https://m.youtube.com")!)
        }
    }

    func openWeb(query: String = "") {
        mode = .web
        showWindow()
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if windowBrowser.webView.url == nil {
                windowBrowser.load(URL(string: "https://duckduckgo.com")!)
            }
        } else {
            windowBrowser.navigate(query, provider: searchProvider)
        }
    }

    func openMusic(query: String = "") {
        mode = .music
        showWindow()
        let request = query.trimmingCharacters(in: .whitespacesAndNewlines)
        music.search(request.isEmpty ? "new music" : request)
    }

    func openYouTube(query: String = "") {
        mode = .youtube
        showWindow()
        let request = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if request.isEmpty {
            if windowYouTube.webView.url == nil {
                windowYouTube.load(URL(string: "https://m.youtube.com")!)
            }
        } else {
            var components = URLComponents(string: "https://m.youtube.com/results")!
            components.queryItems = [URLQueryItem(name: "search_query", value: request)]
            windowYouTube.load(components.url!)
        }
    }

    func showWindow() {
        let preferredSize = preferredWindowSize(for: mode)
        if window == nil {
            let content = BrowseWindowView(controller: self)
            let newWindow = NSWindow(
                contentRect: NSRect(origin: .zero, size: preferredSize),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            newWindow.title = "Aperture Browse"
            newWindow.titlebarAppearsTransparent = true
            newWindow.titleVisibility = .hidden
            newWindow.backgroundColor = .clear
            newWindow.isOpaque = false
            newWindow.isReleasedWhenClosed = false
            newWindow.minSize = NSSize(width: 560, height: 420)
            newWindow.collectionBehavior = [.fullScreenPrimary]
            newWindow.delegate = self
            // Publish the window before mounting SwiftUI. Its first appearance can
            // synchronously call back into this controller.
            window = newWindow
            newWindow.contentView = NSHostingView(rootView: content)
            newWindow.center()
            newWindow.setFrameAutosaveName("ApertureBrowseWindow")
        }
        resizeWindow(for: mode)
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else { return }
        closingWindow.delegate = nil
        window = nil
    }

    func resizeWindow(for mode: BrowseMode) {
        guard let window else { return }
        let size = preferredWindowSize(for: mode)
        guard abs(window.frame.width - size.width) > 2 || abs(window.frame.height - size.height) > 2 else { return }
        let oldFrame = window.frame
        let frame = NSRect(
            x: oldFrame.midX - size.width / 2,
            y: oldFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        window.setFrame(frame, display: true, animate: true)
    }

    private func preferredWindowSize(for mode: BrowseMode) -> NSSize {
        mode == .youtube ? NSSize(width: 680, height: 500) : NSSize(width: 980, height: 680)
    }
}

@MainActor
final class BrowserSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var address = ""
    @Published var pageTitle = "Browse"
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false

    let webView: WKWebView

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsAirPlayForMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsMagnification = true
    }

    func prepareForYouTube() {
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        let script = WKUserScript(
            source: """
                document.cookie = 'PREF=f6=400; path=/; max-age=31536000; SameSite=Lax';
                document.documentElement.setAttribute('dark', '');
                document.documentElement.style.colorScheme = 'dark';
                const style = document.createElement('style');
                style.textContent = 'html, body { background: #0f0f0f !important; color-scheme: dark !important; }';
                (document.head || document.documentElement).appendChild(style);
                """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.addUserScript(script)
    }

    func navigate(_ input: String, provider: WebSearchProvider) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let direct = URL(string: trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") ? trimmed : "https://\(trimmed)")
        if let direct, direct.host?.contains(".") == true {
            load(direct)
        } else if let searchURL = provider.searchURL(for: trimmed) {
            load(searchURL)
        }
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    func goBack() { if webView.canGoBack { webView.goBack() } }
    func goForward() { if webView.canGoForward { webView.goForward() } }
    func reload() { webView.reload() }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        update(from: webView)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        update(from: webView)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        update(from: webView)
    }

    private func update(from webView: WKWebView) {
        address = webView.url?.absoluteString ?? address
        pageTitle = webView.title ?? "Browse"
        isLoading = webView.isLoading
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }
}

struct MusicSearchResult: Decodable, Identifiable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let collectionName: String?
    let artworkUrl100: URL?
    let trackViewUrl: URL?

    var id: Int { trackId }
}

@MainActor
final class MusicCatalogController: ObservableObject {
    @Published var query = ""
    @Published var results: [MusicSearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func search(_ text: String? = nil) {
        let request = (text ?? query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty else { return }
        query = request
        isLoading = true
        errorMessage = nil
        Task {
            do {
                var components = URLComponents(string: "https://itunes.apple.com/search")!
                components.queryItems = [
                    URLQueryItem(name: "term", value: request),
                    URLQueryItem(name: "media", value: "music"),
                    URLQueryItem(name: "entity", value: "song"),
                    URLQueryItem(name: "limit", value: "30")
                ]
                let (data, response) = try await URLSession.shared.data(from: components.url!)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                struct Response: Decodable { let results: [MusicSearchResult] }
                results = try JSONDecoder().decode(Response.self, from: data).results
            } catch {
                results = []
                errorMessage = "Music search couldn’t connect."
            }
            isLoading = false
        }
    }

    func open(_ result: MusicSearchResult) {
        guard let url = result.trackViewUrl else { return }
        NSWorkspace.shared.open(url)
    }
}
