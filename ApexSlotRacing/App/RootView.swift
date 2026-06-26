import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content
                .id(routeKey)
                .transition(.opacity.combined(with: .scale(scale: 0.995)))
        }
        .frame(minWidth: 1180, minHeight: 760)
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.22), value: app.route)
        .onChange(of: app.route) { _, route in
            if case .race = route {
                return
            }
            AudioDirector.shared.setMusicMode(.menu)
            AudioDirector.shared.start()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch app.route {
        case .menu:
            MainMenuView()
        case .quickSetup:
            RaceSetupView(mode: .quick)
        case .pursuitSetup:
            RaceSetupView(mode: .pursuit)
        case .garage:
            GarageView()
        case .editor:
            TrackEditorView()
        case .championship:
            ChampionshipView()
        case .settings:
            SettingsView()
        case .gameCenter:
            GameCenterView()
        case .race(let config):
            RaceView(config: config,
                     settings: app.settings,
                     onComplete: { result in
                         app.finishRace(result, config: config)
                     },
                     onQuit: {
                         app.goToMenu()
                     })
        case .results(let result):
            ResultsView(result: result)
        }
    }

    private var routeKey: String {
        switch app.route {
        case .menu: return "menu"
        case .quickSetup: return "quick-setup"
        case .pursuitSetup: return "pursuit-setup"
        case .garage: return "garage"
        case .editor: return "editor"
        case .championship: return "championship"
        case .settings: return "settings"
        case .gameCenter: return "game-center"
        case .race(let config): return "race-\(config.id.uuidString)"
        case .results(let result): return "results-\(result.id.uuidString)"
        }
    }
}
