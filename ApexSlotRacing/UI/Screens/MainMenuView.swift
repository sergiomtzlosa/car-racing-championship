import AppKit
import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                leftPanel
                    .frame(width: min(590, proxy.size.width * 0.52))
                heroPanel
            }
            .padding(.leading, 46)
            .padding(.trailing, 38)
            .padding(.vertical, 34)
        }
        .background(CarbonBackground())
    }

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            profileStrip
            Spacer(minLength: 22)
            brand
                .padding(.bottom, 26)
            menuGrid
            Spacer(minLength: 20)
            footer
        }
    }

    private var profileStrip: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.orange.opacity(0.16))
                Text(initials)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.orange)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.profile.playerName.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Theme.offWhite)
                HStack(spacing: 5) {
                    Circle()
                        .fill(app.gameCenter.isAuthenticated ? Theme.teal : Theme.muted)
                        .frame(width: 4.5, height: 4.5)
                    Text(app.gameCenter.isAuthenticated ? "GAME CENTER CONNECTED" : "LOCAL PROFILE")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            StatPill(label: "Wins", value: "\(app.profile.wins)", tint: Theme.orange)
            StatPill(label: "Titles", value: "\(app.profile.championships)", tint: Theme.amber)
        }
    }

    private var initials: String {
        let parts = app.profile.playerName.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        if letters.isEmpty { return "A" }
        return String(letters).uppercased()
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                CheckeredStripe(height: 7).frame(width: 44)
                Text("1:32 SCALE CHAMPIONSHIP")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(2.1)
                    .foregroundStyle(Theme.orange)
            }
            Text("APEX")
                .font(.system(size: 104, weight: .black, design: .rounded))
                .tracking(-5)
                .foregroundStyle(
                    LinearGradient(colors: [Theme.offWhite, Theme.offWhite.opacity(0.62)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
            HStack(spacing: 12) {
                Text("SLOT RACING")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .tracking(8.5)
                    .foregroundStyle(Theme.orange)
                Rectangle()
                    .fill(Theme.stroke)
                    .frame(width: 1, height: 17)
                Text("MACOS  ·  SCENEKIT 3D")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Theme.muted)
            }
            Text("Tiny cars. Full send. Build the circuit, tune the machine, and take the title.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: 440, alignment: .leading)
                .padding(.top, 10)
        }
    }

    private var menuGrid: some View {
        VStack(spacing: 8) {
            MenuTile(icon: "trophy.fill",
                     title: "Championship",
                     subtitle: app.championship == nil ? "Start a season · 2–8 drivers" : championshipSubtitle,
                     accent: Theme.orange,
                     badge: app.championship?.completed == true ? "FINALE" : nil) {
                app.openChampionship()
            }
            .accessibilityIdentifier("menu.championship")
            HStack(spacing: 8) {
                MenuTile(icon: "flag.checkered",
                         title: "Quick Race",
                         subtitle: "Player vs CPU · 3–10 laps",
                         accent: Theme.amber) {
                    app.openQuickSetup()
                }
                .accessibilityIdentifier("menu.quickRace")
                MenuTile(icon: "light.beacon.max.fill",
                         title: "Pursuit",
                         subtitle: "Fugitive vs pursuer · boost",
                         accent: Theme.teal) {
                    app.openPursuitSetup()
                }
                .accessibilityIdentifier("menu.pursuit")
            }
            HStack(spacing: 8) {
                MenuTile(icon: "square.grid.3x3.fill",
                         title: "Track Editor",
                         subtitle: "Build, validate, test",
                         accent: Theme.amber) {
                    app.openEditor()
                }
                .accessibilityIdentifier("menu.trackEditor")
                MenuTile(icon: "wrench.and.screwdriver.fill",
                         title: "Garage",
                         subtitle: "Paint, wheels, decals",
                         accent: Theme.orange) {
                    app.openGarage()
                }
                .accessibilityIdentifier("menu.garage")
            }
            HStack(spacing: 8) {
                MenuTile(icon: "slider.horizontal.3",
                         title: "Settings",
                         subtitle: "Audio, visuals, AI",
                         accent: Theme.muted) {
                    app.openSettings()
                }
                .accessibilityIdentifier("menu.settings")
                MenuTile(icon: "gamecontroller.fill",
                         title: "Game Center",
                         subtitle: app.gameCenter.isAuthenticated ? "Leaderboards" : "Local records active",
                         accent: Theme.teal) {
                    app.openGameCenter()
                }
                .accessibilityIdentifier("menu.gameCenter")
            }
        }
        .frame(maxWidth: 540)
    }

    private var championshipSubtitle: String {
        guard let season = app.championship else { return "Start a season · 2–8 drivers" }
        if season.completed {
            return season.championName.map { "Champion: \($0)" } ?? "Season complete"
        }
        let round = min(season.currentRoundIndex + 1, season.rounds.count)
        return "Round \(round) of \(season.rounds.count) · \(app.playerChampionshipPoints) pts"
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text("v1.0")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.muted.opacity(0.6))
            Text("APEX SLOT RACING")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Theme.muted.opacity(0.6))
            Spacer()
            Button("HELP") {
                app.showHelp()
            }
            .buttonStyle(.plain)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(Theme.offWhite.opacity(0.8))
            .accessibilityIdentifier("menu.help")
            Button("QUIT") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(Theme.muted.opacity(0.6))
            .accessibilityIdentifier("menu.quit")
        }
    }

    private var heroPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color(hex: "#1A222C").opacity(0.65),
                        Color(hex: "#0B1016").opacity(0.85)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 30, x: 0, y: 18)

            ShowcaseSceneView(config: app.profile.carConfig,
                              qualitative: app.settings.graphicsQuality,
                              interactive: false,
                              autoRotate: !app.settings.reduceMotion)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    LinearGradient(colors: [
                        .clear,
                        Theme.background.opacity(0.10),
                        Theme.background.opacity(0.72)
                    ], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                )

            VStack {
                HStack {
                    MiniPill(text: "SHOWROOM", tint: Theme.offWhite.opacity(0.8), icon: "sparkles")
                    Spacer()
                    MiniPill(text: "\(app.profile.unlockedCars.count) / \(CarModelKind.allCases.count) CARS", tint: Theme.orange, icon: "car.fill")
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("CURRENT MACHINE")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .tracking(1.8)
                                .foregroundStyle(Theme.orange)
                            Text(app.profile.carConfig.model.displayName)
                                .font(.system(size: 27, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.offWhite)
                            Text(app.profile.carConfig.model.subtitle.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.4)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button {
                            app.openGarage()
                        } label: {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.offWhite)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.10)))
                                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("menu.heroGarage")
                    }
                    HStack(spacing: 7) {
                        StatPill(label: "Top speed", value: "\(Int(app.profile.carConfig.model.stats.topSpeed * 30)) km/h", tint: Theme.orange)
                        StatPill(label: "Grip", value: "\(Int(app.profile.carConfig.model.stats.grip))", tint: Theme.teal)
                        StatPill(label: "Best lap", value: bestLapText, tint: Theme.amber)
                    }
                }
            }
            .padding(25)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("BUILT PROCEDURALLY  ·  NO TWO SEASONS ALIKE")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(Theme.muted.opacity(0.55))
                }
            }
            .padding(18)
        }
        .padding(.leading, 30)
    }

    private var bestLapText: String {
        if let track = app.allTracks.first,
           let lap = app.profile.bestLaps[track.name] {
            return lap.lapTimeString()
        }
        return "--:--.---"
    }
}
