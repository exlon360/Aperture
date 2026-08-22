# Aperture

A native macOS notch companion with Control Center-style modules, a pop-out browser, music search, widgets, Dock controls, and a private local-AI sidecar.

## What is included

- A hardware-aware aperture that uses the built-in Mac camera housing and opens on hover, with a floating fallback for external displays.
- Launches automatically at login and stays dockless in the background. On a notched Mac the collapsed state has no app window at all—the hardware camera housing is the hover target.
- A Liquid Glass control layer on macOS 26, with an adaptive material fallback on macOS 14–15.
- Persistent switches for every feature; the private local AI starts disabled until explicitly enabled.
- A Control Center-style module grid and three-dot menu; Customize Controls can enable, disable, reorder, resize, or reset every feature.
- A live Music surface with current-track artwork and playback controls.
- Browse Music mode with a searchable song catalog and a resizable pop-out window.
- A dedicated Browse module with DuckDuckGo, Google, or Bing search in an embedded WebKit browser.
- An embedded dark Mini YouTube and web browser inside the notch, with optional pop-out, search, playback, AirPlay, and in-app popup handling.
- Selection, window, full-screen, and clipboard screenshots with a recent-capture strip.
- Native macOS notifications plus an in-notch activity feed for screenshots and focus sessions.
- Pocket: drag files onto the physical notch to open a persistent glass shelf with open, Finder reveal, copy-path, and remove actions.
- Six original widgets: Flow, Clipboard, Pulse, Launchpad, Pocket, and Dayline.
- Drag any widget out of the deck to create a live desktop copy; placements persist across launches.
- Desktop widgets lift above Finder only while hovered, so controls and file drops remain usable without covering normal app windows. Remove one with its × button, Aperture’s menu-bar menu, or Settings → Widgets.
- A private assistant with an explicit choice between Apple’s built-in on-device model and locally installed Ollama models.
- Opt-in Web Search grounded through Ollama’s search API, with clickable sources; local inference remains selected separately.
- Restored preview-first Dock controls for position, icon size, magnification, auto-hide, and recent apps.
- A menu-bar controller and persistent settings.

## Run it

Requires macOS 14 or newer and Xcode 16 or newer.

```zsh
swift run Aperture
```

For UI previews and launcher integrations, Aperture also accepts `--expanded`,
`--section=widgets`, `--section=local-ai`, `--section=browse`, `--section=dock`, or a direct feature
such as `--feature=music`, `--feature=screenshots`, and `--feature=notifications`.
Captures can also be launched directly with `--capture=area`, `--capture=window`,
`--capture=screen`, or `--capture=clipboard`.

For browser testing and launchers, use `--browse-window`, `--browse-music`, or `--youtube`.

To create an ad-hoc-signed app bundle:

```zsh
chmod +x scripts/package_app.sh
scripts/package_app.sh
open dist/Aperture.app
```

## Local assistant

On macOS 26, Aperture can use Apple’s built-in on-device Foundation Model when Apple Intelligence is enabled. No separate model install is required. Change models from the clearly labeled **MODEL** menu at the top of the AI module, or from Settings → Local AI.

### Optional local Ollama models

Install [Ollama](https://ollama.com), then pull the default compact model:

```zsh
ollama pull llama3.2:3b
```

Aperture connects to `http://127.0.0.1:11434` by default and lists the models installed there. Web Search is off by default and requires an Ollama API key saved in the macOS Keychain.

## Browse and Dock

Browse Web is a regular embedded browser and does not use the AI search key. Browse Music uses Apple’s catalog search results and opens selected songs in Apple Music or the associated store page.

Dock changes are previewed first and require explicit confirmation. Applying them restarts the macOS Dock process briefly without closing open apps or documents.
