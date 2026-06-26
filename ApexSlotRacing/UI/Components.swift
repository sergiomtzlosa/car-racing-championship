import SwiftUI

struct CarbonBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            LinearGradient(colors: [
                Color(hex: "#10161D"),
                Theme.background,
                Color(hex: "#0A0C10")
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { proxy in
                Canvas { context, size in
                    let spacing: CGFloat = 34
                    var path = Path()
                    var x: CGFloat = 0
                    while x < size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + size.height * 0.24, y: size.height))
                        x += spacing
                    }
                    context.stroke(path, with: .color(Color.white.opacity(0.017)), lineWidth: 1)
                }
            }
            RadialGradient(colors: [
                Theme.orange.opacity(0.10),
                .clear
            ], center: .topTrailing, startRadius: 30, endRadius: 700)
            RadialGradient(colors: [
                Theme.teal.opacity(0.045),
                .clear
            ], center: .bottomLeading, startRadius: 10, endRadius: 600)
            LinearGradient(colors: [.black.opacity(0.18), .clear, .black.opacity(0.35)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}

struct BackButton: View {
    var title: String = "Menu"
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
            }
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(Color.white.opacity(0.055))
                    .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.escape, modifiers: [])
    }
}

struct ScreenHeader: View {
    var eyebrow: String
    var title: String
    var subtitle: String?
    var trailing: AnyView?

    init(eyebrow: String, title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> some View = { EmptyView() }) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(Theme.orange)
                Text(title)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.offWhite)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            trailing
        }
    }
}

struct SectionCard<Content: View>: View {
    var title: String?
    var icon: String?
    @ViewBuilder var content: () -> Content

    init(title: String? = nil, icon: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            if let title {
                HStack(spacing: 8) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.orange)
                    }
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(Theme.muted)
                }
            }
            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.panel.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
    }
}

struct MiniPill: View {
    var text: String
    var tint: Color = Theme.muted
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
            }
            Text(text.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.10)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 1))
    }
}

struct StatPill: View {
    var label: String
    var value: String
    var tint: Color = Theme.orange
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.offWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.045)))
    }
}

struct MenuTile: View {
    var icon: String
    var title: String
    var subtitle: String
    var accent: Color
    var badge: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(0.14))
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.offWhite)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                Spacer()
                if let badge {
                    Text(badge.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accent.opacity(0.12)))
                }
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.muted.opacity(0.8))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct TrackDot: Identifiable {
    var id: String
    var progress: Float
    var color: Color
    var isPlayer: Bool
}

struct TrackOutlineView: View {
    let track: TrackLayout
    var lineWidth: CGFloat = 2.4
    var tint: Color = Theme.orange
    var showStart: Bool = false
    var dots: [TrackDot] = []
    private let built: BuiltTrack

    init(track: TrackLayout,
         lineWidth: CGFloat = 2.4,
         tint: Color = Theme.orange,
         showStart: Bool = false,
         dots: [TrackDot] = []) {
        self.track = track
        self.lineWidth = lineWidth
        self.tint = tint
        self.showStart = showStart
        self.dots = dots
        self.built = TrackPathBuilder.build(track)
    }

    var body: some View {
        Canvas { context, size in
            let pad: CGFloat = max(lineWidth * 2.8, 10)
            let usable = CGSize(width: max(1, size.width - pad * 2), height: max(1, size.height - pad * 2))
            let spanX = CGFloat(max(1, built.boundsMax.x - built.boundsMin.x))
            let spanZ = CGFloat(max(1, built.boundsMax.z - built.boundsMin.z))
            let scale = min(usable.width / spanX, usable.height / spanZ)
            let centerX = CGFloat((built.boundsMin.x + built.boundsMax.x) * 0.5)
            let centerZ = CGFloat((built.boundsMin.z + built.boundsMax.z) * 0.5)

            func point(_ p: SIMD3<Float>) -> CGPoint {
                CGPoint(x: (CGFloat(p.x) - centerX) * scale + size.width * 0.5,
                        y: (CGFloat(p.z) - centerZ) * scale + size.height * 0.5)
            }

            guard let frames = built.lanePaths.first?.frames, frames.count > 1 else {
                _ = context
                return
            }
            var path = Path()
            path.move(to: point(frames[0].position))
            for frame in frames.dropFirst() {
                path.addLine(to: point(frame.position))
            }
            if built.isClosed { path.closeSubpath() }

            context.stroke(path, with: .color(Color.black.opacity(0.55)),
                           style: StrokeStyle(lineWidth: lineWidth + 4.5, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(tint.opacity(0.95)),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(Color.white.opacity(0.35)),
                           style: StrokeStyle(lineWidth: max(0.6, lineWidth * 0.23), lineCap: .round, lineJoin: .round))

            if showStart, let start = built.lanePaths.first?.frames.first {
                let startPoint = point(start.position)
                let r = max(2.5, lineWidth)
                context.fill(Path(ellipseIn: CGRect(x: startPoint.x - r, y: startPoint.y - r, width: r * 2, height: r * 2)),
                             with: .color(Theme.offWhite))
                context.fill(Path(ellipseIn: CGRect(x: startPoint.x - r * 0.45, y: startPoint.y - r * 0.45,
                                                    width: r * 0.9, height: r * 0.9)),
                             with: .color(Theme.orange))
            }

            for dot in dots {
                let laneCount = max(1, built.lanePaths.count)
                let laneIndex = dot.isPlayer ? 0 : min(laneCount - 1, 1)
                let lane = built.lanePaths[laneIndex]
                let fraction = dot.progress.truncatingRemainder(dividingBy: 1)
                let pose = lane.pose(at: max(0, fraction) * lane.length)
                let p = point(pose.position)
                let r: CGFloat = dot.isPlayer ? 5.2 : 4.1
                context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                             with: .color(Color.black.opacity(0.55)))
                context.fill(Path(ellipseIn: CGRect(x: p.x - r + 1, y: p.y - r + 1,
                                                    width: r * 2 - 2, height: r * 2 - 2)),
                             with: .color(dot.color))
                if dot.isPlayer {
                    context.stroke(Path(ellipseIn: CGRect(x: p.x - r - 1, y: p.y - r - 1,
                                                         width: r * 2 + 2, height: r * 2 + 2)),
                                   with: .color(Theme.offWhite), lineWidth: 1)
                }
            }
        }
        .drawingGroup()
    }
}

struct TrackCard: View {
    let track: TrackLayout
    let selected: Bool
    let bestLap: Double?
    let action: () -> Void

    private var built: BuiltTrack { TrackPathBuilder.build(track) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            Color.white.opacity(selected ? 0.10 : 0.045),
                            Color.white.opacity(0.02)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(selected ? Theme.orange.opacity(0.85) : Theme.stroke,
                                          lineWidth: selected ? 1.6 : 1)
                    )
                    .shadow(color: selected ? Theme.orange.opacity(0.22) : .clear, radius: 16)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 6) {
                        MiniPill(text: track.environment.displayName,
                                 tint: track.environment == .night ? Theme.teal : Theme.amber,
                                 icon: track.environment.icon)
                        Spacer(minLength: 4)
                        if !built.isClosed {
                            MiniPill(text: "Open", tint: Theme.danger, icon: "exclamationmark.triangle.fill")
                        }
                        MiniPill(text: difficultyLabel, tint: difficultyTint)
                    }
                    TrackOutlineView(track: track,
                                     lineWidth: 2.1,
                                     tint: selected ? Theme.orange : Theme.offWhite.opacity(0.75),
                                     showStart: true)
                        .frame(height: 68)
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.name)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.offWhite)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        HStack(spacing: 7) {
                            Text(String(format: "%.1f m", built.length))
                            Text("•")
                            Text("\(track.pieces.count) pieces")
                            if let bestLap {
                                Text("•")
                                Text(bestLap.lapTimeString())
                            }
                        }
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    }
                }
                .padding(13)
            }
            .frame(height: 174)
        }
        .buttonStyle(.plain)
    }

    private var difficultyLabel: String {
        switch track.id {
        case TrackCatalog.sunsetID: return "Rookie"
        case TrackCatalog.harborID: return "Technical"
        case TrackCatalog.loopID: return "Extreme"
        case TrackCatalog.nightID: return "Pro"
        default: return "Custom"
        }
    }

    private var difficultyTint: Color {
        switch track.id {
        case TrackCatalog.sunsetID: return Theme.success
        case TrackCatalog.harborID: return Theme.amber
        case TrackCatalog.loopID: return Theme.orange
        case TrackCatalog.nightID: return Theme.teal
        default: return Theme.muted
        }
    }
}

struct CarModelCard: View {
    let model: CarModelKind
    let config: CarConfig?
    let selected: Bool
    let unlocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(model.displayName.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.amber)
                    } else if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.orange)
                    }
                }
                CarGlyph(model: model, primary: Color(hex: config?.primaryHex ?? CarConfig.standard(for: model).primaryHex))
                    .frame(height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(unlocked ? Theme.offWhite : Theme.muted)
                    if let text = model.unlockText, !unlocked {
                        Text(text)
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.amber.opacity(0.9))
                            .lineLimit(1)
                    } else {
                        Text("\(Int(model.stats.topSpeed * 30)) km/h · \(model.stats.grip > 21 ? "High grip" : "Balanced")")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(selected ? 0.075 : 0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(selected ? Theme.orange.opacity(0.8) : Theme.stroke,
                                          lineWidth: selected ? 1.4 : 1)
                    )
            )
            .opacity(unlocked ? 1 : 0.65)
        }
        .buttonStyle(.plain)
    }
}

struct CarGlyph: View {
    var model: CarModelKind
    var primary: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var bodyPath = Path()
            switch model {
            case .gt:
                bodyPath.move(to: CGPoint(x: w * 0.05, y: h * 0.70))
                bodyPath.addCurve(to: CGPoint(x: w * 0.25, y: h * 0.36),
                                  control1: CGPoint(x: w * 0.08, y: h * 0.52),
                                  control2: CGPoint(x: w * 0.14, y: h * 0.38))
                bodyPath.addLine(to: CGPoint(x: w * 0.46, y: h * 0.30))
                bodyPath.addLine(to: CGPoint(x: w * 0.58, y: h * 0.18))
                bodyPath.addCurve(to: CGPoint(x: w * 0.83, y: h * 0.31),
                                  control1: CGPoint(x: w * 0.70, y: h * 0.16),
                                  control2: CGPoint(x: w * 0.77, y: h * 0.22))
                bodyPath.addLine(to: CGPoint(x: w * 0.95, y: h * 0.52))
                bodyPath.addLine(to: CGPoint(x: w * 0.92, y: h * 0.73))
                bodyPath.addLine(to: CGPoint(x: w * 0.68, y: h * 0.78))
                bodyPath.addLine(to: CGPoint(x: w * 0.36, y: h * 0.79))
                bodyPath.addLine(to: CGPoint(x: w * 0.08, y: h * 0.77))
                bodyPath.closeSubpath()
            case .rally:
                bodyPath.move(to: CGPoint(x: w * 0.05, y: h * 0.72))
                bodyPath.addLine(to: CGPoint(x: w * 0.10, y: h * 0.40))
                bodyPath.addLine(to: CGPoint(x: w * 0.30, y: h * 0.34))
                bodyPath.addLine(to: CGPoint(x: w * 0.55, y: h * 0.18))
                bodyPath.addLine(to: CGPoint(x: w * 0.78, y: h * 0.22))
                bodyPath.addLine(to: CGPoint(x: w * 0.95, y: h * 0.42))
                bodyPath.addLine(to: CGPoint(x: w * 0.94, y: h * 0.76))
                bodyPath.addLine(to: CGPoint(x: w * 0.07, y: h * 0.78))
                bodyPath.closeSubpath()
            case .formula:
                bodyPath.move(to: CGPoint(x: w * 0.03, y: h * 0.72))
                bodyPath.addLine(to: CGPoint(x: w * 0.20, y: h * 0.61))
                bodyPath.addLine(to: CGPoint(x: w * 0.43, y: h * 0.50))
                bodyPath.addLine(to: CGPoint(x: w * 0.54, y: h * 0.30))
                bodyPath.addLine(to: CGPoint(x: w * 0.69, y: h * 0.33))
                bodyPath.addLine(to: CGPoint(x: w * 0.79, y: h * 0.55))
                bodyPath.addLine(to: CGPoint(x: w * 0.96, y: h * 0.64))
                bodyPath.addLine(to: CGPoint(x: w * 0.94, y: h * 0.72))
                bodyPath.addLine(to: CGPoint(x: w * 0.05, y: h * 0.76))
                bodyPath.closeSubpath()
            }
            context.fill(bodyPath, with: .linearGradient(
                Gradient(colors: [primary.opacity(0.95), primary.opacity(0.55)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: w, y: h)
            ))
            context.stroke(bodyPath, with: .color(Color.white.opacity(0.30)), lineWidth: 0.8)

            var windowPath = Path()
            if model == .formula {
                windowPath.addEllipse(in: CGRect(x: w * 0.54, y: h * 0.31, width: w * 0.09, height: h * 0.12))
            } else {
                windowPath.move(to: CGPoint(x: w * 0.41, y: h * 0.34))
                windowPath.addLine(to: CGPoint(x: w * 0.56, y: h * 0.22))
                windowPath.addLine(to: CGPoint(x: w * 0.69, y: h * 0.28))
                windowPath.addLine(to: CGPoint(x: w * 0.62, y: h * 0.38))
                windowPath.closeSubpath()
            }
            context.fill(windowPath, with: .color(Color(hex: "#0B1116").opacity(0.82)))

            var wheel = Path()
            wheel.addEllipse(in: CGRect(x: w * 0.18, y: h * 0.66, width: w * 0.13, height: h * 0.30))
            wheel.addEllipse(in: CGRect(x: w * 0.71, y: h * 0.66, width: w * 0.13, height: h * 0.30))
            context.fill(wheel, with: .color(Color.black.opacity(0.85)))
        }
    }
}

struct HoldControl: View {
    var title: String
    var icon: String
    var tint: Color
    var accessibilityID: String = ""
    var onPress: (Bool) -> Void
    @State private var pressed = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
        }
        .foregroundStyle(pressed ? Color.white : Theme.offWhite)
        .frame(width: 112, height: 46)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(pressed ? tint : Color.black.opacity(0.34))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(pressed ? tint : Color.white.opacity(0.16), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed {
                        pressed = true
                        onPress(true)
                    }
                }
                .onEnded { _ in
                    pressed = false
                    onPress(false)
                }
        )
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityAction {
            onPress(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onPress(false)
            }
        }
    }
}

struct CheckeredStripe: View {
    var height: CGFloat = 5
    var body: some View {
        Canvas { context, size in
            let cell = height
            var row = 0
            var x: CGFloat = -cell
            while x < size.width + cell {
                let offset = row % 2 == 0 ? 0 : cell
                context.fill(Path(CGRect(x: x + offset, y: 0, width: cell, height: cell)),
                             with: .color(row % 2 == 0 ? Theme.offWhite : Theme.orange))
                x += cell
                row += 1
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}
