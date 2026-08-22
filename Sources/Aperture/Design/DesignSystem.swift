import SwiftUI

enum AperturePalette {
    static let ink = Color(nsColor: .windowBackgroundColor)
    static let raised = Color(nsColor: .underPageBackgroundColor).opacity(0.72)
    static let card = Color(nsColor: .controlBackgroundColor).opacity(0.66)
    static let line = Color(nsColor: .separatorColor).opacity(0.62)
    static let text = Color(nsColor: .labelColor)
    static let secondary = Color(nsColor: .secondaryLabelColor)
    static let accent = Color(hex: "D6D8DC")
    static let mint = Color(nsColor: .systemGreen)
    static let silicon = Color(hex: "C6C9CF")
    static let iris = Color(hex: "979AA1")
    static let sky = Color(hex: "EEEFF2")
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red, green, blue: UInt64
        switch cleaned.count {
        case 3:
            (red, green, blue) = ((value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        default:
            (red, green, blue) = (value >> 16, value >> 8 & 0xFF, value & 0xFF)
        }
        self.init(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}

struct ApertureCard<Content: View>: View {
    let tint: Color
    @ViewBuilder var content: Content

    init(tint: Color = AperturePalette.accent, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: "1A1A1D").opacity(0.97))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AperturePalette.line, lineWidth: 0.6)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct IconButton: View {
    let systemName: String
    var isActive = false
    var help: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? AperturePalette.ink : AperturePalette.text)
                .frame(width: 30, height: 30)
                .background(isActive ? AperturePalette.text : Color.white.opacity(0.07), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help ?? "")
    }
}

extension View {
    func apertureLabel() -> some View {
        self
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .tracking(1.3)
            .foregroundStyle(AperturePalette.secondary)
    }

    func apertureGlass(cornerRadius: CGFloat, interactive: Bool = false, clear: Bool = false) -> some View {
        modifier(ApertureGlassModifier(cornerRadius: cornerRadius, interactive: interactive, clear: clear))
    }
}

private struct ApertureGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let interactive: Bool
    let clear: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if clear {
                content
                    .background(Color.white.opacity(interactive ? 0.075 : 0.045), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.6)
                    }
            } else {
                content.glassEffect(.regular.interactive(interactive), in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
