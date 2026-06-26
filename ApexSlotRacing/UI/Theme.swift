import AppKit
import SwiftUI

extension NSColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt64(value, radix: 16) else { return nil }
        let red = CGFloat((number >> 16) & 0xFF) / 255
        let green = CGFloat((number >> 8) & 0xFF) / 255
        let blue = CGFloat(number & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    var hexString: String {
        guard let color = usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

extension Color {
    init(hex: String) {
        if let ns = NSColor(hex: hex) {
            self.init(nsColor: ns)
        } else {
            self = .white
        }
    }

    func nsColor() -> NSColor {
        NSColor(self)
    }
}

enum Theme {
    static let background = Color(hex: "#07090C")
    static let graphite = Color(hex: "#11151B")
    static let panel = Color(hex: "#161B22")
    static let panelLight = Color(hex: "#1E252E")
    static let stroke = Color.white.opacity(0.10)
    static let orange = Color(hex: "#FF4D22")
    static let orangeDeep = Color(hex: "#D63112")
    static let amber = Color(hex: "#FFB020")
    static let teal = Color(hex: "#52D6D0")
    static let offWhite = Color(hex: "#F1EDE5")
    static let muted = Color(hex: "#8A929E")
    static let danger = Color(hex: "#FF3B30")
    static let success = Color(hex: "#3DDC84")
}

struct GlassPanel: ViewModifier {
    var padding: CGFloat = 20
    var radius: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            Color.white.opacity(0.065),
                            Color.white.opacity(0.025)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(Theme.panel.opacity(0.82))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassPanel(padding: CGFloat = 20, radius: CGFloat = 18) -> some View {
        modifier(GlassPanel(padding: padding, radius: radius))
    }
}

struct RacingButtonStyle: ButtonStyle {
    var prominent: Bool = false
    var accent: Color = Theme.orange
    var compact: Bool = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 13 : 15, weight: .semibold, design: .rounded))
            .foregroundStyle(prominent ? Color.white : Theme.offWhite)
            .padding(.horizontal, compact ? 14 : 20)
            .padding(.vertical, compact ? 8 : 13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(prominent ? accent : Color.white.opacity(configuration.isPressed ? 0.12 : 0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(prominent ? Color.white.opacity(0.18) : Theme.stroke, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.36)
            .saturation(isEnabled ? 1 : 0.45)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SectionTitle: View {
    var eyebrow: String?
    var title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(Theme.orange)
            }
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.offWhite)
        }
    }
}

struct StatBar: View {
    var label: String
    var value: Double
    var tint: Color = Theme.orange
    var displayValue: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text(displayValue ?? String(format: "%.0f%%", value * 100))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.offWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule().fill(tint)
                        .frame(width: max(4, proxy.size.width * CGFloat(value)))
                }
            }
            .frame(height: 5)
        }
    }
}

extension Double {
    func lapTimeString() -> String {
        guard isFinite, self > 0 else { return "--:--.---" }
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        let millis = Int((self - floor(self)) * 1000)
        return String(format: "%d:%02d.%03d", minutes, seconds, millis)
    }

    func shortTimeString() -> String {
        guard isFinite, self > 0 else { return "--.--" }
        let minutes = Int(self) / 60
        let seconds = self - Double(minutes * 60)
        if minutes > 0 {
            return String(format: "%d:%05.2f", minutes, seconds)
        }
        return String(format: "%.2f", seconds)
    }
}
