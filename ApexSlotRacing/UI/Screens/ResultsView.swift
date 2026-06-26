import SwiftUI

struct ResultsView: View {
    let result: RaceResult
    @EnvironmentObject private var app: AppModel

    private var player: CarResult? {
        result.cars.first(where: { $0.isPlayer })
    }

    private var track: TrackLayout? {
        app.track(id: result.trackID) ?? app.lastRaceConfig?.track
    }

    private var sortedCars: [CarResult] {
        result.cars.sorted { $0.position < $1.position }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 20) {
                    hero
                    content
                }
                .padding(.horizontal, 34)
                .padding(.bottom, 34)
            }
        }
        .background(CarbonBackground())
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            BackButton { app.goToMenu() }
                .accessibilityIdentifier("results.back")
            ScreenHeader(eyebrow: "Official Timing",
                         title: "Race Classification",
                         subtitle: "\(result.trackName) · \(result.mode.displayName) · \(result.date.formatted(date: .abbreviated, time: .shortened))")
            Spacer()
            MiniPill(text: result.difficulty.displayName, tint: Theme.amber, icon: "gauge.with.dots.needle.67percent")
            MiniPill(text: result.mode.displayName.uppercased(), tint: Theme.orange, icon: "flag.checkered")
        }
        .padding(.horizontal, 34)
        .padding(.top, 30)
        .padding(.bottom, 10)
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Theme.orange.opacity(0.22), Theme.orange.opacity(0.04)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.orange.opacity(0.35), lineWidth: 1))
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.playerWon ? "VICTORY" : (player.map { "P\($0.position)" } ?? "DNF"))
                            .font(.system(size: 58, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.offWhite)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .accessibilityIdentifier("results.outcome")
                        Text(result.playerWon ? "CHECKERED FLAG" : "CLASSIFICATION")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(Theme.orange)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    Rectangle().fill(Theme.orange.opacity(0.3)).frame(width: 1, height: 72)
                    HStack(spacing: 12) {
                        StatPill(label: "Race time", value: (player?.totalTime ?? 0).lapTimeString(), tint: Theme.offWhite)
                        StatPill(label: "Best lap", value: result.playerBestLap.lapTimeString(), tint: Theme.teal)
                        StatPill(label: "Top speed", value: "\(Int(result.playerTopSpeed.rounded())) km/h", tint: Theme.orange)
                        StatPill(label: "Deslots", value: "\(result.playerDeslots)", tint: Theme.amber)
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 0)
                }
                .padding(26)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 156)

            if let track {
                VStack(alignment: .leading, spacing: 5) {
                    Text("CIRCUIT")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(Theme.muted)
                    TrackOutlineView(track: track, lineWidth: 2.4, tint: Theme.orange, showStart: true)
                        .frame(width: 230, height: 102)
                    Text(track.name)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.offWhite)
                        .lineLimit(1)
                }
                .padding(16)
                .frame(width: 270)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Theme.panel.opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.stroke, lineWidth: 1))
                )
            }
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                SectionCard(title: "Classification", icon: "list.number") {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            tableHeader("POS", width: 42)
                            tableHeader("DRIVER", width: nil)
                            tableHeader("CAR", width: 115)
                            tableHeader("TIME", width: 100)
                            tableHeader("BEST LAP", width: 92)
                            tableHeader("DESLOTS", width: 62)
                        }
                        .padding(.bottom, 8)
                        ForEach(Array(sortedCars.enumerated()), id: \.element.id) { index, car in
                            HStack(spacing: 10) {
                                Text("\(car.position)")
                                    .font(.system(size: 15, weight: .black, design: .monospaced))
                                    .foregroundStyle(car.isPlayer ? Theme.orange : Theme.muted)
                                    .frame(width: 42, alignment: .leading)
                                HStack(spacing: 8) {
                                    Circle().fill(Color(hex: car.colorHex)).frame(width: 7, height: 7)
                                    Text(car.name)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(car.isPlayer ? Theme.offWhite : Theme.muted)
                                    if car.isPlayer {
                                        Text("YOU")
                                            .font(.system(size: 7, weight: .black, design: .rounded))
                                            .foregroundStyle(Theme.orange)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(car.carModel.displayName)
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.muted)
                                    .frame(width: 115, alignment: .leading)
                                Text(car.totalTime.lapTimeString())
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.offWhite)
                                    .frame(width: 100, alignment: .leading)
                                Text(car.bestLap.lapTimeString())
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Theme.teal)
                                    .frame(width: 92, alignment: .leading)
                                Text("\(car.deslots)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(car.deslots > 0 ? Theme.amber : Theme.muted)
                                    .frame(width: 62, alignment: .leading)
                            }
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(car.isPlayer ? Theme.orange.opacity(0.07) : (index.isMultiple(of: 2) ? Color.white.opacity(0.018) : .clear))
                            )
                        }
                    }
                }
                if result.mode == .championship {
                    championshipNote
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 14) {
                if !result.unlockMessages.isEmpty || !result.achievementMessages.isEmpty {
                    SectionCard(title: "Rewards", icon: "sparkles") {
                        VStack(alignment: .leading, spacing: 9) {
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
                    }
                    .frame(width: 310)
                }

                SectionCard(title: "Actions", icon: "arrow.right.circle.fill") {
                    VStack(spacing: 8) {
                        Button {
                            app.rematch()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text(result.mode == .championship ? "NEXT ROUND" : "RACE AGAIN")
                                Spacer()
                            }
                        }
                        .buttonStyle(RacingButtonStyle(prominent: true, accent: Theme.orange, compact: true))
                        .disabled(result.mode == .championship && app.championship?.completed == true)
                        .accessibilityIdentifier("results.raceAgain")

                        Button {
                            app.changeSetup()
                        } label: {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                Text("CHANGE SETUP")
                                Spacer()
                            }
                        }
                        .buttonStyle(RacingButtonStyle(compact: true))
                        .accessibilityIdentifier("results.changeSetup")

                        if result.mode == .championship {
                            Button {
                                app.openChampionship()
                            } label: {
                                HStack {
                                    Image(systemName: "list.number")
                                    Text("STANDINGS")
                                    Spacer()
                                }
                            }
                            .buttonStyle(RacingButtonStyle(compact: true))
                            .accessibilityIdentifier("results.standings")
                        }

                        Button {
                            app.goToMenu()
                        } label: {
                            HStack {
                                Image(systemName: "house.fill")
                                Text("MAIN MENU")
                                Spacer()
                            }
                        }
                        .buttonStyle(RacingButtonStyle(compact: true))
                        .accessibilityIdentifier("results.mainMenu")
                    }
                }
                .frame(width: 310)

                SectionCard(title: "Telemetry", icon: "waveform.path.ecg") {
                    let averageSpeed = player?.averageSpeed ?? 0
                    let topSpeed = player?.topSpeed ?? 0
                    let duration = player?.totalTime ?? 0
                    let distance = averageSpeed * duration / 3600
                    VStack(spacing: 9) {
                        StatBar(label: "Average speed",
                                value: min(1, averageSpeed / 320),
                                tint: Theme.orange,
                                displayValue: String(format: "%.0f km/h", averageSpeed))
                        StatBar(label: "Top speed",
                                value: min(1, topSpeed / 320),
                                tint: Theme.teal,
                                displayValue: String(format: "%.0f km/h", topSpeed))
                        StatBar(label: "Race distance",
                                value: min(1, distance / 8),
                                tint: Theme.amber,
                                displayValue: String(format: "%.2f km", distance))
                    }
                }
                .frame(width: 310)
            }
        }
    }

    private var championshipNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.amber)
            VStack(alignment: .leading, spacing: 3) {
                Text("CHAMPIONSHIP POINTS AWARDED")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Theme.amber)
                Text("The season table has been updated. Continue to the next round from the Championship screen.")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            if let season = app.championship, let round = ChampionshipDirector.currentRound(of: season) {
                StatPill(label: "Next round", value: "R\(round.index + 1)", tint: Theme.orange)
            }
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.amber.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.amber.opacity(0.25), lineWidth: 1))
    }

    private func tableHeader(_ title: String, width: CGFloat?) -> some View {
        Text(title)
            .font(.system(size: 7, weight: .bold, design: .rounded))
            .tracking(1)
            .foregroundStyle(Theme.muted)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}
