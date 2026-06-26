import SwiftUI

struct ChampionshipView: View {
    @EnvironmentObject private var app: AppModel
    @State private var fieldSize = 6
    @State private var difficulty: Difficulty = .medium
    @State private var showAbandonConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                if let season = app.championship {
                    seasonContent(season)
                } else {
                    setupContent
                }
            }
        }
        .background(CarbonBackground())
        .alert("Abandon championship?", isPresented: $showAbandonConfirm) {
            Button("Keep Season", role: .cancel) {}
            Button("Abandon", role: .destructive) {
                app.abandonChampionship()
            }
        } message: {
            Text("Your current season and points will be deleted. This cannot be undone.")
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            BackButton { app.goToMenu() }
                .accessibilityIdentifier("championship.back")
            ScreenHeader(eyebrow: "Apex Championship",
                         title: "The Season",
                         subtitle: "Four circuits. Two lanes. One champion.")
            Spacer()
            if let season = app.championship {
                MiniPill(text: season.completed ? "SEASON COMPLETE" : "ROUND \(min(season.currentRoundIndex + 1, season.rounds.count)) / \(season.rounds.count)",
                         tint: season.completed ? Theme.amber : Theme.orange,
                         icon: season.completed ? "flag.checkered" : "calendar")
                MiniPill(text: "\(season.entrants.count) DRIVERS", tint: Theme.teal, icon: "person.3.fill")
            } else {
                MiniPill(text: "NEW SEASON", tint: Theme.orange, icon: "trophy.fill")
            }
        }
        .padding(.horizontal, 34)
        .padding(.top, 30)
        .padding(.bottom, 10)
    }

    // MARK: - New season

    private var setupContent: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(colors: [Theme.orange.opacity(0.20), Color(hex: "#161B22").opacity(0.85)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.orange.opacity(0.28), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 10) {
                        MiniPill(text: "\(fieldSize)-DRIVER FIELD", tint: Theme.orange, icon: "person.3.fill")
                            .accessibilityIdentifier("championship.fieldBadge")
                        Text("BUILD YOUR\nLEGACY")
                            .font(.system(size: 41, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.offWhite)
                            .lineSpacing(-4)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Qualify. Seed the heats. Score points. Four rounds decide who lifts the trophy.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: 420, alignment: .leading)
                        HStack(spacing: 8) {
                            StatPill(label: "Rounds", value: "4", tint: Theme.orange)
                            StatPill(label: "Points", value: "10·6·4·2", tint: Theme.amber)
                            StatPill(label: "Lanes", value: "2", tint: Theme.teal)
                        }
                    }
                    .padding(28)
                }
                .frame(height: 302)

                SectionCard(title: "Season Calendar", icon: "calendar") {
                    VStack(spacing: 8) {
                        ForEach(Array(TrackCatalog.builtIn.enumerated()), id: \.element.id) { index, track in
                            HStack(spacing: 12) {
                                Text("R\(index + 1)")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundStyle(Theme.orange)
                                    .frame(width: 24)
                                TrackOutlineView(track: track, lineWidth: 1.7, tint: Theme.offWhite.opacity(0.7), showStart: true)
                                    .frame(width: 92, height: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.name)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.offWhite)
                                    Text(track.environment.displayName.uppercased())
                                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Text(String(format: "%.1f m", TrackPathBuilder.build(track).length))
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Theme.muted)
                            }
                            .padding(7)
                            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.025)))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 16) {
                SectionCard(title: "Season Setup", icon: "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("FIELD SIZE")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(Theme.muted)
                            HStack(spacing: 6) {
                                ForEach([2, 4, 6, 8], id: \.self) { size in
                                    Button {
                                        fieldSize = size
                                    } label: {
                                        Text("\(size)")
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundStyle(fieldSize == size ? .white : Theme.muted)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(fieldSize == size ? Theme.orange : Color.white.opacity(0.05))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("championship.field.\(size)")
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("DIFFICULTY")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(Theme.muted)
                            Picker("Difficulty", selection: $difficulty) {
                                ForEach(Difficulty.allCases) { value in
                                    Text(value.displayName).tag(value)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .tint(Theme.orange)
                            .accessibilityIdentifier("championship.difficulty")
                        }

                        Rectangle().fill(Theme.stroke).frame(height: 1)

                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: app.profile.carConfig.primaryHex).opacity(0.18))
                                Image(systemName: "car.side.fill")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundStyle(Color(hex: app.profile.carConfig.primaryHex))
                            }
                            .frame(width: 52, height: 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("YOUR ENTRY")
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .tracking(1)
                                    .foregroundStyle(Theme.muted)
                                Text(app.profile.carConfig.model.displayName)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.offWhite)
                                Text(app.profile.playerName)
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Button("GARAGE") { app.openGarage() }
                                .buttonStyle(RacingButtonStyle(compact: true))
                                .frame(width: 88)
                                .accessibilityIdentifier("championship.garage")
                        }

                        Button {
                            app.startChampionship(fieldSize: fieldSize, difficulty: difficulty)
                        } label: {
                            HStack {
                                Image(systemName: "flag.checkered")
                                Text("START SEASON")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                        }
                        .buttonStyle(RacingButtonStyle(prominent: true, accent: Theme.orange))
                        .accessibilityIdentifier("championship.startSeason")
                    }
                }

                SectionCard(title: "How It Works", icon: "info.circle.fill") {
                    VStack(alignment: .leading, spacing: 9) {
                        infoRow("01", "Qualify", "Optional one-lap qualifying seeds the heat grid and lane choice.")
                        infoRow("02", "Race", "You drive your two-car heat. The rest of the field runs deterministic AI heats.")
                        infoRow("03", "Score", "Top four score 10 / 6 / 4 / 2 points. Wins, podiums, then best lap break ties.")
                        infoRow("04", "Crown", "The points leader after four rounds is champion. Win to unlock the open-wheel car.")
                    }
                }
            }
            .frame(width: 440)
        }
        .padding(.horizontal, 34)
        .padding(.top, 10)
        .padding(.bottom, 34)
    }

    // MARK: - Active season

    private func seasonContent(_ season: ChampionshipState) -> some View {
        VStack(spacing: 16) {
            if season.completed {
                championBanner(season)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) {
                    roundCalendar(season)
                    standingsCard(season)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 16) {
                    if !season.completed, let round = ChampionshipDirector.currentRound(of: season) {
                        currentRoundCard(season, round: round)
                        qualifyingCard(season)
                    } else {
                        seasonSummaryCard(season)
                    }
                }
                .frame(width: 390)
            }
        }
        .padding(.horizontal, 34)
        .padding(.top, 10)
        .padding(.bottom, 34)
    }

    private func championBanner(_ season: ChampionshipState) -> some View {
        let playerWon = season.championName == app.profile.playerName
        return HStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.amber.opacity(0.3), Theme.orange.opacity(0.08)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Circle().strokeBorder(Theme.amber.opacity(0.5), lineWidth: 1))
                Image(systemName: "trophy.fill")
                    .font(.system(size: 37, weight: .bold))
                    .foregroundStyle(Theme.amber)
            }
            .frame(width: 100, height: 100)
            VStack(alignment: .leading, spacing: 4) {
                Text(playerWon ? "YOU ARE THE CHAMPION" : "SEASON COMPLETE")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Theme.orange)
                Text(season.championName ?? "Champion")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.offWhite)
                Text(playerWon
                     ? "The Apex Championship is yours. Open Wheel machinery is now unlocked in the garage."
                     : "The title is decided. Review the final table and come back stronger next season.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(spacing: 8) {
                Button("NEW SEASON") {
                    app.abandonChampionship()
                }
                .buttonStyle(RacingButtonStyle(prominent: true, accent: Theme.orange, compact: true))
                .accessibilityIdentifier("championship.newSeason")
                Button("MAIN MENU") { app.goToMenu() }
                    .buttonStyle(RacingButtonStyle(compact: true))
                    .accessibilityIdentifier("championship.mainMenu")
            }
            .frame(width: 170)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Theme.amber.opacity(0.10), Theme.panel.opacity(0.9)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.amber.opacity(0.3), lineWidth: 1))
        )
    }

    private func roundCalendar(_ season: ChampionshipState) -> some View {
        SectionCard(title: "Calendar", icon: "calendar") {
            HStack(spacing: 9) {
                ForEach(season.rounds) { round in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("R\(round.index + 1)")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(round.completed ? Theme.muted : Theme.orange)
                            Spacer()
                            Image(systemName: round.completed ? "checkmark.circle.fill" : (round.index == season.currentRoundIndex ? "circle.dotted" : "circle"))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(round.completed ? Theme.success : (round.index == season.currentRoundIndex ? Theme.orange : Theme.muted.opacity(0.5)))
                        }
                        Text(round.trackName)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(round.completed ? Theme.offWhite.opacity(0.7) : Theme.offWhite)
                            .lineLimit(1)
                        if round.completed {
                            Text(round.winnerName)
                                .font(.system(size: 7, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.muted)
                                .lineLimit(1)
                        } else {
                            Text(round.index == season.currentRoundIndex ? "NEXT" : "UPCOMING")
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .tracking(0.7)
                                .foregroundStyle(round.index == season.currentRoundIndex ? Theme.orange : Theme.muted.opacity(0.7))
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(round.index == season.currentRoundIndex ? Theme.orange.opacity(0.08) : Color.white.opacity(0.025))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(round.index == season.currentRoundIndex ? Theme.orange.opacity(0.35) : Theme.stroke, lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    private func standingsCard(_ season: ChampionshipState) -> some View {
        SectionCard(title: "Standings", icon: "list.number") {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    header("POS", width: 34)
                    header("DRIVER", width: nil)
                    header("CAR", width: 110)
                    header("PTS", width: 40)
                    header("WINS", width: 38)
                    header("PODIUMS", width: 55)
                    header("BEST LAP", width: 84)
                }
                .padding(.bottom, 7)
                ForEach(Array(app.standings.enumerated()), id: \.element.id) { index, entrant in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(index == 0 ? Theme.amber : (entrant.isPlayer ? Theme.orange : Theme.muted))
                            .frame(width: 34, alignment: .leading)
                        HStack(spacing: 7) {
                            Circle().fill(Color(hex: entrant.colorHex)).frame(width: 7, height: 7)
                            Text(entrant.name)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(entrant.isPlayer ? Theme.offWhite : Theme.muted)
                            if entrant.isPlayer {
                                Text("YOU")
                                    .font(.system(size: 6, weight: .black, design: .rounded))
                                    .foregroundStyle(Theme.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(entrant.carModel.displayName)
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 110, alignment: .leading)
                        Text("\(entrant.points)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.offWhite)
                            .frame(width: 40, alignment: .leading)
                        Text("\(entrant.wins)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 38, alignment: .leading)
                        Text("\(entrant.podiums)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 55, alignment: .leading)
                        Text(entrant.bestLap.lapTimeString())
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.teal)
                            .frame(width: 84, alignment: .leading)
                    }
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(entrant.isPlayer ? Theme.orange.opacity(0.07) : (index.isMultiple(of: 2) ? Color.white.opacity(0.018) : .clear))
                    )
                }
            }
            HStack {
                Text("Points: 10 / 6 / 4 / 2 for the top four each round.")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("TIE-BREAK: WINS · PODIUMS · BEST LAP")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.muted.opacity(0.7))
            }
        }
    }

    private func currentRoundCard(_ season: ChampionshipState, round: ChampionshipRound) -> some View {
        let track = app.track(id: round.trackID)
        return SectionCard(title: "Next Round", icon: "flag.checkered") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ROUND \(round.index + 1) OF \(season.rounds.count)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(1.3)
                            .foregroundStyle(Theme.orange)
                        Text(round.trackName)
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.offWhite)
                    }
                    Spacer()
                    MiniPill(text: season.difficulty.displayName, tint: Theme.amber)
                }
                if let track {
                    TrackOutlineView(track: track, lineWidth: 2.6, tint: Theme.orange, showStart: true)
                        .frame(height: 124)
                        .padding(9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))
                }
                HStack(spacing: 8) {
                    StatPill(label: "Laps", value: "3", tint: Theme.offWhite)
                    StatPill(label: "Field", value: "\(season.entrants.count)", tint: Theme.teal)
                    StatPill(label: "Your points", value: "\(app.playerChampionshipPoints)", tint: Theme.orange)
                }
                Button {
                    app.startChampionshipRound()
                } label: {
                    HStack {
                        Image(systemName: "flag.checkered")
                        Text("START ROUND")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(RacingButtonStyle(prominent: true, accent: Theme.orange))
                .accessibilityIdentifier("championship.startRound")
                Button("ABANDON SEASON") {
                    showAbandonConfirm = true
                }
                .buttonStyle(RacingButtonStyle(accent: Theme.danger, compact: true))
                .accessibilityIdentifier("championship.abandon")
            }
        }
    }

    private func qualifyingCard(_ season: ChampionshipState) -> some View {
        let order = ChampionshipDirector.qualifyingOrder(state: season)
        return SectionCard(title: "Qualifying", icon: "stopwatch.fill") {
            VStack(alignment: .leading, spacing: 9) {
                if order.isEmpty {
                    Text("Run a simulated one-lap qualifying session to establish the grid and lane seeding.")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.muted)
                    Button {
                        app.simulateQualifying()
                    } label: {
                        HStack {
                            Image(systemName: "timer")
                            Text("SIMULATE QUALIFYING")
                            Spacer()
                        }
                    }
                    .buttonStyle(RacingButtonStyle(accent: Theme.teal, compact: true))
                    .accessibilityIdentifier("championship.simulateQualifying")
                } else {
                    ForEach(Array(order.enumerated()), id: \.element.id) { index, entrant in
                        HStack(spacing: 7) {
                            Text("\(index + 1)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(index == 0 ? Theme.amber : Theme.muted)
                                .frame(width: 18, alignment: .leading)
                            Circle().fill(Color(hex: entrant.colorHex)).frame(width: 6, height: 6)
                            Text(entrant.name)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(entrant.isPlayer ? Theme.offWhite : Theme.muted)
                            Spacer()
                            Text(entrant.qualifyingTime.shortTimeString())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(entrant.isPlayer ? Theme.orange : Theme.muted)
                        }
                        .padding(.vertical, 3)
                    }
                    Text("Qualifying sets heat seeding and lane choice. You still drive your own heat.")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.muted.opacity(0.8))
                }
            }
        }
    }

    private func seasonSummaryCard(_ season: ChampionshipState) -> some View {
        SectionCard(title: "Season Summary", icon: "trophy.fill") {
            VStack(alignment: .leading, spacing: 9) {
                StatPill(label: "Champion", value: season.championName ?? "—", tint: Theme.amber)
                Text("The final table is locked. Start a new season to chase a different title.")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
                Button("NEW SEASON") {
                    app.abandonChampionship()
                }
                .buttonStyle(RacingButtonStyle(prominent: true, accent: Theme.orange, compact: true))
                .accessibilityIdentifier("championship.newSeason")
            }
        }
    }

    private func infoRow(_ index: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(index)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.orange)
                .frame(width: 18, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.offWhite)
                Text(detail)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func header(_ title: String, width: CGFloat?) -> some View {
        Text(title)
            .font(.system(size: 7, weight: .bold, design: .rounded))
            .tracking(1)
            .foregroundStyle(Theme.muted)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}
