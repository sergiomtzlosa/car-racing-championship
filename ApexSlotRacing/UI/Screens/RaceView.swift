import SwiftUI

struct RaceView: View {
    let config: RaceConfig
    @EnvironmentObject private var app: AppModel
    @StateObject private var session: RaceSession
    let onComplete: (RaceResult) -> Void
    let onQuit: () -> Void

    init(config: RaceConfig,
         settings: AppSettings,
         onComplete: @escaping (RaceResult) -> Void,
         onQuit: @escaping () -> Void) {
        self.config = config
        self.onComplete = onComplete
        self.onQuit = onQuit
        _session = StateObject(wrappedValue: RaceSession(settings: settings))
    }

    var body: some View {
        ZStack {
            RaceSceneView(config: config, settings: app.settings, session: session)
            RaceHUD(config: config, session: session)

            if session.isPaused {
                RacePauseOverlay(config: config, session: session, onQuit: onQuit)
            }
            if let result = session.result {
                RaceFinishOverlay(config: config,
                                  result: app.lastRaceResult?.id == result.id ? app.lastRaceResult ?? result : result,
                                  session: session,
                                  onComplete: onComplete,
                                  onQuit: onQuit)
            }
        }
        .ignoresSafeArea()
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .onChange(of: session.result?.id) { _, _ in
            if let result = session.result {
                app.recordRace(result, config: config)
            }
        }
    }
}
