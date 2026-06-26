import SwiftUI

struct RaceHUD: View {
    let config: RaceConfig
    @ObservedObject var session: RaceSession

    private var telemetry: RaceTelemetry { session.telemetry }

    var body: some View {
        ZStack {
            VStack {
                topBar
                HStack(alignment: .top) {
                    minimap
                    Spacer()
                    warningArea
                    Spacer()
                    rightTop
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                Spacer()
                HStack(alignment: .bottom) {
                    speedometer
                    Spacer()
                    controls
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
            }
            centerOverlay
        }
        .allowsHitTesting(true)
        .animation(.easeOut(duration: 0.16), value: telemetry.penalty > 0)
        .animation(.easeOut(duration: 0.16), value: telemetry.phase)
    }

    private var topBar: some View {
        HStack(spacing: 18) {
            HStack(spacing: 8) {
                CheckeredStripe(height: 4).frame(width: 24)
                Text("APEX")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Theme.offWhite)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.black.opacity(0.45)))
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))

            HUDValue(label: "POSITION", value: "P\(telemetry.position)", sub: "/ \(telemetry.fieldSize)", tint: Theme.orange)
                .accessibilityIdentifier("hud.position")
            HUDValue(label: "LAP", value: "\(telemetry.lap)", sub: "/ \(telemetry.totalLaps)", tint: Theme.offWhite)
                .accessibilityIdentifier("hud.lap")
            HUDValue(label: "RACE", value: telemetry.raceTime.lapTimeString(), sub: nil, tint: Theme.offWhite)
                .accessibilityIdentifier("hud.raceTime")
            HUDValue(label: "BEST", value: telemetry.bestLap.lapTimeString(), sub: nil, tint: Theme.teal)
                .accessibilityIdentifier("hud.bestLap")
            Spacer()
            aiStatusChip
            if config.mode == .pursuit {
                MiniPill(text: telemetry.playerIsPursuer ? "PURSUER" : "FUGITIVE",
                         tint: telemetry.playerIsPursuer ? Theme.orange : Theme.teal,
                         icon: telemetry.playerIsPursuer ? "light.beacon.max.fill" : "figure.run")
            }
            Button {
                session.toggleMute()
            } label: {
                Image(systemName: session.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.black.opacity(0.42)))
            }
            .buttonStyle(.plain)
            .help("Mute audio (M)")
            .accessibilityLabel(session.isMuted ? "Unmute audio" : "Mute audio")
            .accessibilityIdentifier("hud.mute")
            Button {
                session.togglePause()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.offWhite)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.black.opacity(0.42)))
            }
            .buttonStyle(.plain)
            .help("Pause race (Esc)")
            .accessibilityLabel("Pause race")
            .accessibilityIdentifier("hud.pause")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private var aiModeLabel: String {
        let raw = telemetry.aiMode.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "LOCAL AI" : raw.uppercased()
    }

    private var aiStatusChip: some View {
        let cloud = aiModeLabel.contains("CLOUD")
        let tint = cloud ? Theme.teal : Theme.offWhite.opacity(0.78)
        return HStack(spacing: 5) {
            Image(systemName: "cpu")
                .font(.system(size: 9, weight: .bold))
            Text(aiModeLabel)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.48)))
        .overlay(Capsule().strokeBorder((cloud ? Theme.teal : Theme.stroke).opacity(0.55), lineWidth: 1))
        .fixedSize()
        .accessibilityLabel("AI driver: \(aiModeLabel)")
        .accessibilityIdentifier("hud.aiStatus")
    }

    private var minimap: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CIRCUIT")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text(config.track.name.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Theme.offWhite.opacity(0.8))
            }
            TrackOutlineView(track: config.track,
                             lineWidth: 2.2,
                             tint: Theme.offWhite.opacity(0.74),
                             showStart: true,
                             dots: telemetry.cars.map { car in
                                 TrackDot(id: car.id.uuidString,
                                          progress: car.progress,
                                          color: car.isPlayer ? Theme.orange : Color(hex: car.colorHex),
                                          isPlayer: car.isPlayer)
                             })
                .frame(height: 122)
        }
        .padding(13)
        .frame(width: 232)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.45))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        )
        .accessibilityIdentifier("hud.minimap")
    }

    @ViewBuilder
    private var warningArea: some View {
        VStack(spacing: 7) {
            if let warning = telemetry.warning {
                Text(warning)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(warning == "BRAKE" ? Theme.danger : Theme.amber)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.58)))
                    .overlay(Capsule().strokeBorder((warning == "BRAKE" ? Theme.danger : Theme.amber).opacity(0.45), lineWidth: 1))
                    .accessibilityIdentifier("hud.warning")
            }
            if let status = telemetry.statusMessage {
                Text(status)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.offWhite)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.black.opacity(0.58)))
                    .accessibilityIdentifier("hud.status")
            }
            if config.mode == .pursuit {
                pursuitMeter
            }
        }
        .padding(.top, 2)
    }

    private var pursuitMeter: some View {
        VStack(spacing: 5) {
            HStack {
                Text(telemetry.playerIsPursuer ? "CAPTURE" : "PURSUIT")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Theme.muted)
                Spacer()
                if let gap = telemetry.gap {
                    Text(String(format: "%+.1f m", gap))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(abs(gap) < 3 ? Theme.orange : Theme.muted)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    if telemetry.playerIsPursuer {
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.teal, Theme.orange], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(5, proxy.size.width * telemetry.captureProgress))
                    } else {
                        Capsule()
                            .fill(Theme.teal)
                            .frame(width: max(5, proxy.size.width * min(1, abs(telemetry.gap ?? 0) / 12)))
                    }
                }
            }
            .frame(width: 220, height: 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.48)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.stroke, lineWidth: 1))
        .accessibilityIdentifier("hud.pursuitMeter")
    }

    private var rightTop: some View {
        VStack(alignment: .trailing, spacing: 7) {
            Button {
                session.cycleCamera()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: telemetry.cameraMode.icon)
                        .font(.system(size: 10, weight: .bold))
                    Text(telemetry.cameraMode.displayName.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1)
                }
                .foregroundStyle(Theme.offWhite)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.48)))
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Cycle camera (C)")
            .accessibilityLabel("Cycle camera")
            .accessibilityIdentifier("hud.camera")
            Text("C / Y")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.muted.opacity(0.8))
        }
    }

    private var speedometer: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.52))
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                .frame(width: 202, height: 202)
            SpeedGauge(speed: min(320, telemetry.speed), topSpeed: min(320, telemetry.topSpeed))
                .frame(width: 190, height: 190)
            VStack(spacing: 0) {
                Text("\(Int(telemetry.speed.rounded()))")
                    .font(.system(size: 41, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.offWhite)
                    .monospacedDigit()
                    .accessibilityIdentifier("hud.speed")
                Text("KM/H")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(Theme.orange)
                Text(telemetry.currentLap.lapTimeString())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 14)
            }
            .offset(y: 6)
        }
    }

    private var controls: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if config.mode == .pursuit {
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(index < telemetry.boostCharges ? Theme.orange : Color.white.opacity(0.14))
                    }
                    if telemetry.boostActive {
                        Text("BOOST")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.orange)
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.5)))
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            }

            HStack(spacing: 7) {
                TelemetryBar(label: "THROTTLE", value: telemetry.throttle, tint: Theme.success)
                TelemetryBar(label: "BRAKE", value: telemetry.brake, tint: Theme.danger)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("DESLOTS")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(Theme.muted)
                    Text("\(telemetry.deslots)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(telemetry.deslots > 0 ? Theme.danger : Theme.offWhite)
                        .accessibilityIdentifier("hud.deslots")
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.46)))
            }

            HStack(spacing: 9) {
                HoldControl(title: "THROTTLE", icon: "arrow.up", tint: Theme.success, accessibilityID: "hud.throttle") { session.setThrottle($0) }
                HoldControl(title: "BRAKE", icon: "arrow.down", tint: Theme.danger, accessibilityID: "hud.brake") { session.setBrake($0) }
                if config.mode == .pursuit {
                    Button {
                        session.setBoost(true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { session.setBoost(false) }
                    } label: {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.orange)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(Color.black.opacity(0.34)))
                            .overlay(Circle().strokeBorder(Theme.orange.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Boost (Shift)")
                    .accessibilityIdentifier("hud.boost")
                }
            }
            Text(config.mode == .pursuit
                 ? "W / ↑ throttle   ·   S / ↓ brake   ·   Shift boost   ·   Esc pause"
                 : "W / ↑ throttle   ·   S / ↓ brake   ·   C camera   ·   Esc pause")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.muted.opacity(0.75))
        }
    }

    @ViewBuilder
    private var centerOverlay: some View {
        if telemetry.phase == .countdown {
            VStack(spacing: 3) {
                Text(telemetry.countdown > 3.0 ? "GET READY" : "\(min(3, max(1, Int(ceil(telemetry.countdown)))))")
                    .font(.system(size: telemetry.countdown > 3.0 ? 22 : 96, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.offWhite)
                    .shadow(color: Theme.orange.opacity(0.5), radius: 22)
                if telemetry.countdown > 3.0 {
                    Text("LIGHTS OUT IN 3")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Theme.orange)
                }
            }
            .padding(34)
            .background(Circle().fill(Color.black.opacity(0.20)))
            .transition(.scale(scale: 0.8).combined(with: .opacity))
            .accessibilityIdentifier("hud.countdown")
        } else if telemetry.phase == .racing, telemetry.raceTime < 1.0 {
            Text("GO")
                .font(.system(size: 78, weight: .black, design: .rounded))
                .foregroundStyle(Theme.success)
                .shadow(color: Theme.success.opacity(0.6), radius: 24)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
                .accessibilityIdentifier("hud.go")
        } else if telemetry.penalty > 0 {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.amber)
                Text("DESLOT")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(Theme.amber)
                Text(String(format: "RE-SLOT IN %.1f", telemetry.penalty))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.offWhite)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 22)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.62)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.amber.opacity(0.45), lineWidth: 1))
            .accessibilityIdentifier("hud.penalty")
        } else if telemetry.lap == telemetry.totalLaps, telemetry.phase == .racing {
            Text("FINAL LAP")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundStyle(Theme.orange)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .overlay(Capsule().strokeBorder(Theme.orange.opacity(0.5), lineWidth: 1))
                .offset(y: -130)
                .accessibilityIdentifier("hud.finalLap")
        }
    }
}

private struct HUDValue: View {
    var label: String
    var value: String
    var sub: String?
    var tint: Color
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Theme.muted)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                    if let sub {
                        Text(sub)
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.38)))
    }
}

private struct TelemetryBar: View {
    var label: String
    var value: Double
    var tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(Theme.muted)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule().fill(tint)
                        .frame(width: max(3, proxy.size.width * min(1, value)))
                }
            }
            .frame(width: 48, height: 4)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.46)))
    }
}

private struct SpeedGauge: View {
    var speed: Double
    var topSpeed: Double
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.39
            let start = 135.0
            let sweep = 270.0
            let progress = max(0, min(1, speed / 320))

            var base = Path()
            base.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(start + sweep), clockwise: false)
            context.stroke(base, with: .color(Color.white.opacity(0.11)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            var active = Path()
            active.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(start + sweep * progress), clockwise: false)
            context.stroke(active, with: .linearGradient(
                Gradient(colors: [Theme.teal, Theme.amber, Theme.orange]),
                startPoint: CGPoint(x: center.x - radius, y: center.y + radius),
                endPoint: CGPoint(x: center.x + radius, y: center.y - radius)
            ), style: StrokeStyle(lineWidth: 7, lineCap: .round))

            for index in 0...8 {
                let angle = Angle(degrees: start + sweep * Double(index) / 8)
                let inner = radius - 12
                let outer = radius - 6
                let a = CGPoint(x: center.x + cos(angle.radians) * inner, y: center.y + sin(angle.radians) * inner)
                let b = CGPoint(x: center.x + cos(angle.radians) * outer, y: center.y + sin(angle.radians) * outer)
                var tick = Path()
                tick.move(to: a)
                tick.addLine(to: b)
                context.stroke(tick, with: .color(index == 8 ? Theme.orange.opacity(0.8) : Color.white.opacity(0.28)), lineWidth: index % 2 == 0 ? 1.6 : 0.8)
                if index % 2 == 0 {
                    let labelPoint = CGPoint(x: center.x + cos(angle.radians) * (radius - 23),
                                             y: center.y + sin(angle.radians) * (radius - 23))
                    context.draw(Text("\(index * 40)").font(.system(size: 7, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.muted),
                                 at: labelPoint, anchor: .center)
                }
            }

            if topSpeed > 0 {
                let angle = Angle(degrees: start + sweep * min(1, topSpeed / 320))
                let p = CGPoint(x: center.x + cos(angle.radians) * (radius + 6),
                                y: center.y + sin(angle.radians) * (radius + 6))
                context.fill(Path(ellipseIn: CGRect(x: p.x - 2.2, y: p.y - 2.2, width: 4.4, height: 4.4)),
                             with: .color(Theme.teal))
            }

            let needleAngle = Angle(degrees: start + sweep * progress)
            let tip = CGPoint(x: center.x + cos(needleAngle.radians) * (radius - 20),
                              y: center.y + sin(needleAngle.radians) * (radius - 20))
            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: tip)
            context.stroke(needle, with: .color(Theme.orange), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                         with: .color(Theme.offWhite))
        }
    }
}
