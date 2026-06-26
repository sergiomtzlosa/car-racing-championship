import SwiftUI

struct RacePauseOverlay: View {
    let config: RaceConfig
    @ObservedObject var session: RaceSession
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
                .background(.ultraThinMaterial)
            VStack(spacing: 22) {
                MiniPill(text: "RACE PAUSED", tint: Theme.amber, icon: "pause.fill")
                Text("HOLD THE LINE")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.offWhite)
                    .accessibilityIdentifier("race.pause.title")
                Text("\(config.track.name)  ·  \(config.mode.displayName.uppercased())")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.muted)
                HStack(spacing: 9) {
                    Button("RESUME") { session.resume() }
                        .buttonStyle(RacingButtonStyle(prominent: true, compact: true))
                        .accessibilityIdentifier("race.pause.resume")
                    Button("RESTART") { session.restart() }
                        .buttonStyle(RacingButtonStyle(compact: true))
                        .accessibilityIdentifier("race.pause.restart")
                    Button("QUIT") { onQuit() }
                        .buttonStyle(RacingButtonStyle(accent: Theme.danger, compact: true))
                        .accessibilityIdentifier("race.pause.quit")
                }
                .frame(width: 430)
                Text("ESC / P to resume  ·  R to restart  ·  M mute")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.muted.opacity(0.8))
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.panel.opacity(0.96))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: 30)
            )
        }
        .transition(.opacity)
    }
}

struct RaceFinishOverlay: View {
    let config: RaceConfig
    let result: RaceResult
    @ObservedObject var session: RaceSession
    let onComplete: (RaceResult) -> Void
    let onQuit: () -> Void

    private var position: Int? {
        result.cars.first(where: { $0.isPlayer })?.position
    }

    private var player: CarResult? {
        result.cars.first(where: { $0.isPlayer })
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .background(.ultraThinMaterial)
            VStack(spacing: 19) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.playerWon ? "CHECKERED FLAG" : "RACE COMPLETE")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(2.2)
                            .foregroundStyle(result.playerWon ? Theme.orange : Theme.muted)
                        Text(result.playerWon ? "VICTORY" : (position.map { "P\($0) FINISH" } ?? "RACE COMPLETE"))
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.offWhite)
                            .accessibilityIdentifier("race.finish.outcome")
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(result.playerWon ? Theme.orange : Theme.panelLight)
                        Text(position.map { "P\($0)" } ?? "—")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundStyle(result.playerWon ? .white : Theme.offWhite)
                    }
                    .frame(width: 72, height: 72)
                }
                .frame(width: 520)

                HStack(spacing: 10) {
                    StatPill(label: "Race time", value: (player?.totalTime ?? 0).lapTimeString(), tint: Theme.offWhite)
                    StatPill(label: "Best lap", value: result.playerBestLap.lapTimeString(), tint: Theme.teal)
                    StatPill(label: "Top speed", value: "\(Int(result.playerTopSpeed.rounded())) km/h", tint: Theme.orange)
                    StatPill(label: "Deslots", value: "\(result.playerDeslots)", tint: Theme.amber)
                }

                if !result.unlockMessages.isEmpty || !result.achievementMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(result.unlockMessages, id: \.self) { message in
                            Label(message, systemImage: "lock.open.fill")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.amber)
                        }
                        ForEach(result.achievementMessages, id: \.self) { message in
                            Label(message, systemImage: "trophy.fill")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.teal)
                        }
                    }
                    .frame(width: 520, alignment: .leading)
                }

                HStack(spacing: 9) {
                    Button("VIEW RESULTS") { onComplete(result) }
                        .buttonStyle(RacingButtonStyle(prominent: true, compact: true))
                        .accessibilityIdentifier("race.finish.viewResults")
                    if config.mode != .championship && config.mode != .qualifying {
                        Button("RACE AGAIN") { session.restart() }
                            .buttonStyle(RacingButtonStyle(compact: true))
                            .accessibilityIdentifier("race.finish.raceAgain")
                    }
                    Button("MENU") { onQuit() }
                        .buttonStyle(RacingButtonStyle(compact: true))
                        .accessibilityIdentifier("race.finish.menu")
                }
                .frame(width: 520)
                Text("Race results are saved locally. Game Center updates when signed in.")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.muted.opacity(0.7))
            }
            .padding(34)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Theme.panel.opacity(0.97))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                    .shadow(color: .black.opacity(0.55), radius: 34)
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}
