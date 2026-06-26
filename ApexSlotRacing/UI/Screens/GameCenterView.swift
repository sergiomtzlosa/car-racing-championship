import SwiftUI

struct GameCenterView: View {
    @EnvironmentObject private var app: AppModel

    private var unlockedAchievements: [String] {
        app.profile.achievements
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 16) {
                        statusCard
                        localRecords
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 16) {
                        achievementsCard
                        privacyCard
                    }
                    .frame(width: 480)
                }
                .padding(.horizontal, 34)
                .padding(.top, 10)
                .padding(.bottom, 34)
            }
        }
        .background(CarbonBackground())
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            BackButton { app.goToMenu() }
                .accessibilityIdentifier("gameCenter.back")
            ScreenHeader(eyebrow: "Online & Local",
                         title: "Game Center",
                         subtitle: "Leaderboards, achievements and records. Gameplay never waits for the network.")
            Spacer()
            MiniPill(text: app.gameCenter.isAuthenticated ? "CONNECTED" : "LOCAL MODE",
                     tint: app.gameCenter.isAuthenticated ? Theme.success : Theme.amber,
                     icon: app.gameCenter.isAuthenticated ? "checkmark.circle.fill" : "wifi.slash")
        }
        .padding(.horizontal, 34)
        .padding(.top, 30)
        .padding(.bottom, 10)
    }

    private var statusCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [Theme.orange.opacity(0.22), Theme.orange.opacity(0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(Circle().strokeBorder(Theme.orange.opacity(0.35), lineWidth: 1))
                Image(systemName: app.gameCenter.isAuthenticated ? "person.crop.circle.badge.checkmark" : "gamecontroller.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.orange)
            }
            .frame(width: 78, height: 78)

            VStack(alignment: .leading, spacing: 5) {
                Text(app.gameCenter.isAuthenticated ? (app.gameCenter.playerAlias.isEmpty ? "GAME CENTER ATHLETE" : app.gameCenter.playerAlias.uppercased()) : "LOCAL PROFILE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.7)
                    .foregroundStyle(Theme.orange)
                Text(app.gameCenter.statusText)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.offWhite)
                Text("Best laps, championship points and pursuit wins are submitted when signed in. Every achievement and record is stored locally first.")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: 480, alignment: .leading)
            }
            Spacer()
            VStack(spacing: 8) {
                Button {
                    app.gameCenter.authenticate()
                } label: {
                    Label("SIGN IN / REFRESH", systemImage: "person.crop.circle")
                }
                .buttonStyle(RacingButtonStyle(prominent: true, accent: Theme.orange, compact: true))
                .accessibilityIdentifier("gameCenter.signIn")
                Button {
                    app.gameCenter.showDashboard()
                } label: {
                    Label("OPEN DASHBOARD", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(RacingButtonStyle(accent: Theme.teal, compact: true))
                .disabled(!app.gameCenter.isAuthenticated)
                .accessibilityIdentifier("gameCenter.dashboard")
            }
            .frame(width: 190)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.panel.opacity(0.88))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.stroke, lineWidth: 1))
        )
    }

    private var localRecords: some View {
        SectionCard(title: "Local Records", icon: "stopwatch.fill") {
            VStack(spacing: 0) {
                HStack {
                    header("CIRCUIT")
                    Spacer()
                    header("BEST LAP")
                }
                .padding(.bottom, 7)
                ForEach(TrackCatalog.builtIn) { track in
                    HStack(spacing: 10) {
                        Circle().fill(Theme.orange).frame(width: 5, height: 5)
                        Text(track.name)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.offWhite)
                        Spacer()
                        Text(app.profile.bestLaps[track.name]?.lapTimeString() ?? "--:--.---")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.teal)
                    }
                    .padding(.vertical, 9)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.stroke).frame(height: 1) }
                }
            }
            HStack(spacing: 8) {
                StatPill(label: "Races", value: "\(app.profile.races)", tint: Theme.offWhite)
                StatPill(label: "Wins", value: "\(app.profile.wins)", tint: Theme.orange)
                StatPill(label: "Podiums", value: "\(app.profile.podiums)", tint: Theme.amber)
                StatPill(label: "Titles", value: "\(app.profile.championships)", tint: Theme.teal)
                StatPill(label: "Top speed", value: "\(Int(app.profile.topSpeed.rounded())) km/h", tint: Theme.teal)
                Spacer(minLength: 0)
                if let favorite = app.profile.favoriteTrack {
                    MiniPill(text: favorite.uppercased(), tint: Theme.muted, icon: "star.fill")
                }
            }
            .padding(.top, 4)
        }
    }

    private var achievementsCard: some View {
        SectionCard(title: "Achievements", icon: "trophy.fill") {
            VStack(spacing: 8) {
                ForEach(AchievementService.all) { achievement in
                    let unlocked = unlockedAchievements.contains(achievement.id)
                    HStack(spacing: 11) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9)
                                .fill((unlocked ? Theme.orange : Theme.muted).opacity(0.10))
                            Image(systemName: achievement.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(unlocked ? Theme.orange : Theme.muted.opacity(0.55))
                        }
                        .frame(width: 38, height: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(achievement.title)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(unlocked ? Theme.offWhite : Theme.muted)
                            Text(achievement.detail)
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        if unlocked {
                            MiniPill(text: "UNLOCKED", tint: Theme.success, icon: "checkmark")
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.muted.opacity(0.45))
                        }
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 10).fill(unlocked ? Color.white.opacity(0.035) : .clear))
                }
            }
        }
    }

    private var privacyCard: some View {
        SectionCard(title: "Fair Play & Privacy", icon: "hand.raised.fill") {
            VStack(alignment: .leading, spacing: 7) {
                Text("Game Center identity is never required to race. Local records are authoritative in offline mode and sync attempts happen only after a successful sign-in.")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
                Text("Cloud AI telemetry contains anonymous race state only: speed, curvature look-ahead, gap and boost availability. It contains no player name, Game Center identity or personal data.")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
                Text("Leaderboard IDs are documented in README.md. They are safe placeholders until App Store Connect is configured.")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.muted.opacity(0.8))
            }
        }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 7, weight: .bold, design: .rounded))
            .tracking(1)
            .foregroundStyle(Theme.muted)
            .frame(width: text == "CIRCUIT" ? nil : 110, alignment: .leading)
    }
}
