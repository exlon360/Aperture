import SwiftUI
import WebKit

struct BrowseNotchView: View {
    @ObservedObject var controller: BrowseController
    @ObservedObject private var browser: BrowserSession
    @ObservedObject private var youtube: BrowserSession
    @ObservedObject private var music: MusicCatalogController
    @State private var addressDraft = ""
    @State private var youtubeQuery = ""

    init(controller: BrowseController) {
        self.controller = controller
        self.browser = controller.browser
        self.youtube = controller.youtube
        self.music = controller.music
    }

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                Picker("", selection: $controller.mode) {
                    ForEach(BrowseMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 250)

                Spacer()

                Label("Private in Aperture", systemImage: "lock.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)

                Button {
                    controller.popOutCurrentMode()
                } label: {
                    Label("Pop Out", systemImage: "rectangle.on.rectangle.angled")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open this page in an optional separate Aperture window")
            }

            if controller.mode != .music {
                browserToolbar
            }

            Group {
                switch controller.mode {
                case .web:
                    EmbeddedWebView(session: browser)
                case .music:
                    MusicCatalogView(controller: music, compact: true)
                        .padding(12)
                case .youtube:
                    EmbeddedWebView(session: youtube)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 0.7)
            }
        }
        .foregroundStyle(.primary)
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onAppear {
            controller.activateInline(controller.mode)
            addressDraft = browser.address
        }
        .onChange(of: controller.mode) { _, mode in
            controller.activateInline(mode)
        }
        .onChange(of: browser.address) { _, address in
            addressDraft = address
        }
    }

    private var browserToolbar: some View {
        HStack(spacing: 8) {
            let session = controller.mode == .youtube ? youtube : browser

            IconButton(systemName: "chevron.left", help: "Back", action: session.goBack)
                .disabled(!session.canGoBack)
            IconButton(systemName: "chevron.right", help: "Forward", action: session.goForward)
                .disabled(!session.canGoForward)
            IconButton(systemName: "arrow.clockwise", help: "Reload", action: session.reload)

            HStack(spacing: 7) {
                Image(systemName: controller.mode == .youtube ? "play.rectangle.fill" : "magnifyingglass")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(controller.mode == .youtube ? .red : .secondary)
                if controller.mode == .youtube {
                    TextField("Search YouTube", text: $youtubeQuery)
                        .textFieldStyle(.plain)
                        .onSubmit { controller.searchInlineYouTube(youtubeQuery) }
                } else {
                    TextField("Search or enter website", text: $addressDraft)
                        .textFieldStyle(.plain)
                        .onSubmit { controller.searchInlineWeb(addressDraft) }
                }
                if session.isLoading { ProgressView().controlSize(.small) }
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            if controller.mode == .web {
                Menu(controller.searchProvider.rawValue) {
                    ForEach(WebSearchProvider.allCases) { provider in
                        Button(provider.rawValue) { controller.searchProvider = provider }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Button {
                if controller.mode == .youtube {
                    controller.searchInlineYouTube(youtubeQuery)
                } else {
                    controller.searchInlineWeb(addressDraft)
                }
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .frame(width: 26, height: 26)
                    .background(AperturePalette.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(controller.mode == .youtube && youtubeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

struct BrowseWindowView: View {
    @ObservedObject var controller: BrowseController
    @ObservedObject private var browser: BrowserSession
    @ObservedObject private var youtube: BrowserSession
    @ObservedObject private var music: MusicCatalogController
    @State private var addressDraft = ""
    @State private var youtubeQuery = ""

    init(controller: BrowseController) {
        self.controller = controller
        self.browser = controller.windowBrowser
        self.youtube = controller.windowYouTube
        self.music = controller.music
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.top, 30)
            Divider().opacity(0.4)
            Group {
                switch controller.mode {
                case .web:
                    EmbeddedWebView(session: browser)
                case .music:
                    MusicCatalogView(controller: music, compact: false)
                        .padding(16)
                case .youtube:
                    EmbeddedWebView(session: youtube)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(hex: "151517").opacity(0.98))
        .preferredColorScheme(.dark)
        .tint(AperturePalette.accent)
        .ignoresSafeArea()
        .onAppear {
            addressDraft = browser.address
        }
        .onChange(of: browser.address) { _, value in addressDraft = value }
        .onChange(of: controller.mode) { _, mode in
            controller.resizeWindow(for: mode)
            if mode == .web && browser.webView.url == nil { controller.openWeb() }
            if mode == .music && music.results.isEmpty { controller.openMusic() }
            if mode == .youtube && youtube.webView.url == nil { controller.openYouTube() }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 9) {
            Picker("", selection: $controller.mode) {
                ForEach(BrowseMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 250)

            switch controller.mode {
            case .web:
                IconButton(systemName: "chevron.left", help: "Back", action: browser.goBack)
                    .disabled(!browser.canGoBack)
                IconButton(systemName: "chevron.right", help: "Forward", action: browser.goForward)
                    .disabled(!browser.canGoForward)
                IconButton(systemName: "arrow.clockwise", help: "Reload", action: browser.reload)
                HStack(spacing: 7) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    TextField("Search or enter website", text: $addressDraft)
                        .textFieldStyle(.plain)
                        .onSubmit { browser.navigate(addressDraft, provider: controller.searchProvider) }
                    if browser.isLoading { ProgressView().controlSize(.small) }
                }
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Menu(controller.searchProvider.rawValue) {
                    ForEach(WebSearchProvider.allCases) { provider in
                        Button(provider.rawValue) { controller.searchProvider = provider }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Button {
                    if let url = browser.webView.url { NSWorkspace.shared.open(url) }
                } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.plain)
                .help("Open in default browser")
            case .music:
                Text("Browse Music")
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search songs, artists, or albums", text: $music.query)
                        .textFieldStyle(.plain)
                        .onSubmit { music.search() }
                }
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Button("Search") { music.search() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            case .youtube:
                IconButton(systemName: "chevron.left", help: "Back", action: youtube.goBack)
                    .disabled(!youtube.canGoBack)
                IconButton(systemName: "chevron.right", help: "Forward", action: youtube.goForward)
                    .disabled(!youtube.canGoForward)
                IconButton(systemName: "arrow.clockwise", help: "Reload", action: youtube.reload)
                HStack(spacing: 7) {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundStyle(.red)
                    TextField("Search YouTube", text: $youtubeQuery)
                        .textFieldStyle(.plain)
                        .onSubmit(searchYouTube)
                    if youtube.isLoading { ProgressView().controlSize(.small) }
                }
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Button("Search", action: searchYouTube)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button {
                    if let url = youtube.webView.url { NSWorkspace.shared.open(url) }
                } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.plain)
                .help("Open in default browser")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
    }

    private func searchYouTube() {
        controller.openYouTube(query: youtubeQuery)
    }
}

struct MusicCatalogView: View {
    @ObservedObject var controller: MusicCatalogController
    let compact: Bool

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: compact ? 150 : 190), spacing: 10)]
    }

    var body: some View {
        VStack(spacing: 10) {
            if compact {
                HStack(spacing: 8) {
                    Text("Browse Music")
                        .font(.system(size: 14, weight: .semibold))
                    TextField("Search songs", text: $controller.query)
                        .textFieldStyle(.plain)
                        .onSubmit { controller.search() }
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    Button("Search") { controller.search() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }

            if controller.isLoading {
                ProgressView("Searching Apple Music…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = controller.errorMessage {
                ContentUnavailableView("Music Search Unavailable", systemImage: "wifi.exclamationmark", description: Text(error))
            } else if controller.results.isEmpty {
                ContentUnavailableView("Search Apple Music", systemImage: "music.note.list", description: Text("Find songs, artists, and albums."))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(controller.results) { result in
                            Button { controller.open(result) } label: {
                                HStack(spacing: 10) {
                                    AsyncImage(url: result.artworkUrl100) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Color.white.opacity(0.08).overlay { Image(systemName: "music.note") }
                                    }
                                    .frame(width: compact ? 40 : 48, height: compact ? 40 : 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.trackName)
                                            .font(.system(size: 11, weight: .semibold))
                                            .lineLimit(1)
                                        Text(result.artistName)
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(8)
                                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

private struct EmbeddedWebView: NSViewRepresentable {
    @ObservedObject var session: BrowserSession

    func makeNSView(context: Context) -> WKWebView { session.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
