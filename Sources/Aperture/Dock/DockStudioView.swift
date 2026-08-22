import SwiftUI

struct DockStudioView: View {
    @ObservedObject var controller: DockController
    @State private var showingConfirmation = false

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dock")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Tune the system Dock")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reset", action: controller.resetPreview)
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                }

                Picker("Position", selection: $controller.position) {
                    ForEach(DockPosition.allCases) { position in
                        Text(position.title).tag(position)
                    }
                }
                .pickerStyle(.segmented)

                DockSlider(title: "Icon Size", value: $controller.tileSize, range: 24...80)
                Toggle("Magnification", isOn: $controller.magnification)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                if controller.magnification {
                    DockSlider(title: "Magnified Size", value: $controller.magnifiedSize, range: 48...128)
                }
                HStack {
                    Toggle("Auto-hide", isOn: $controller.autoHide)
                    Toggle("Recent apps", isOn: $controller.showRecents)
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                Spacer()
                HStack {
                    if let result = controller.resultMessage {
                        Text(result)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(result == "Dock updated" ? AperturePalette.mint : Color.orange)
                    }
                    Spacer()
                    Button(controller.isApplying ? "Applying…" : "Apply to Dock") {
                        showingConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(controller.isApplying)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            DockPreview(controller: controller)
                .frame(width: 240)
        }
        .foregroundStyle(.primary)
        .confirmationDialog("Apply this Dock setup?", isPresented: $showingConfirmation) {
            Button("Apply & Restart Dock") { controller.apply() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("macOS will briefly restart the Dock. Open apps and files are not affected.")
        }
    }
}

private struct DockSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(title).font(.system(size: 10, weight: .medium))
                Spacer()
                Text("\(Int(value))").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
        }
    }
}

private struct DockPreview: View {
    @ObservedObject var controller: DockController

    var body: some View {
        ZStack(alignment: alignment) {
            LinearGradient(colors: [Color.white.opacity(0.10), Color(hex: "777A81").opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
            dockBar
                .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .topLeading) {
            Text("PREVIEW").apertureLabel().padding(14)
        }
    }

    private var alignment: Alignment {
        switch controller.position {
        case .left: return .leading
        case .right: return .trailing
        case .bottom: return .bottom
        }
    }

    private var dockBar: some View {
        Group {
            if controller.position == .bottom {
                HStack(spacing: 7) { icons }
                    .padding(8)
            } else {
                VStack(spacing: 7) { icons }
                    .padding(8)
            }
        }
        .background(Color(hex: "202024").opacity(0.96), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 12, y: 7)
        .opacity(controller.autoHide ? 0.68 : 1)
    }

    @ViewBuilder private var icons: some View {
        ForEach(["face.smiling", "safari", "message.fill", "music.note", "gearshape.fill"], id: \.self) { icon in
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 25, height: 25)
                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 7))
        }
    }
}
