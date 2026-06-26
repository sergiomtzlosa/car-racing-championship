import Foundation
import SwiftUI

enum AppRoute: Equatable {
    case menu
    case quickSetup
    case pursuitSetup
    case garage
    case editor
    case championship
    case settings
    case gameCenter
    case race(RaceConfig)
    case results(RaceResult)
}

@MainActor
final class AppModel: ObservableObject {
    @Published var route: AppRoute = .menu
    @Published private(set) var profile: PlayerProfile
    @Published private(set) var settings: AppSettings
    @Published private(set) var customTracks: [TrackLayout]
    @Published private(set) var championship: ChampionshipState?
    @Published private(set) var lastRaceConfig: RaceConfig?
    @Published private(set) var lastRaceResult: RaceResult?
    @Published private(set) var isMuted = AudioDirector.shared.isMuted
    @Published private(set) var pendingEditorTrack: TrackLayout?

    let saveStore: SaveStore
    let gameCenter: GameCenterService
    let networkMonitor: NetworkMonitor
    private let cloudAI: CloudAIService

    init(saveStore: SaveStore = .shared, authenticateGameCenter: Bool = true) {
        self.saveStore = saveStore
        self.profile = saveStore.loadProfile()
        self.settings = SettingsStore.load()
        self.customTracks = saveStore.loadCustomTracks()
        self.championship = saveStore.loadChampionship()
        self.gameCenter = GameCenterService()
        self.networkMonitor = NetworkMonitor()
        self.cloudAI = CloudAIService()

        AudioDirector.shared.apply(settings: settings)
        AudioDirector.shared.start()
        AudioDirector.shared.setMusicMode(.menu)
        if authenticateGameCenter {
            gameCenter.authenticate()
        }
    }

    var allTracks: [TrackLayout] {
        TrackCatalog.builtIn + customTracks
    }

    var playerChampionshipPoints: Int {
        championship?.entrants.first(where: { $0.isPlayer })?.points ?? 0
    }

    func track(id: UUID) -> TrackLayout? {
        TrackCatalog.layout(for: id, custom: customTracks)
    }

    func bestLap(for track: TrackLayout) -> Double? {
        profile.bestLaps[track.name]
    }

    // MARK: - Navigation

    func goToMenu() {
        isMuted = AudioDirector.shared.isMuted
        route = .menu
        AudioDirector.shared.endRace()
        AudioDirector.shared.setMusicMode(.menu)
        AudioDirector.shared.start()
    }

    func openQuickSetup() {
        route = .quickSetup
    }

    func openPursuitSetup() {
        route = .pursuitSetup
    }

    func openGarage() {
        route = .garage
    }

    func openEditor(track: TrackLayout? = nil) {
        pendingEditorTrack = track
        route = .editor
    }

    func takePendingEditorTrack() -> TrackLayout? {
        defer { pendingEditorTrack = nil }
        return pendingEditorTrack
    }

    func openChampionship() {
        route = .championship
    }

    func openSettings() {
        route = .settings
    }

    func openGameCenter() {
        route = .gameCenter
    }

    // MARK: - Race entry

    func startQuickRace(track: TrackLayout,
                        car: CarConfig,
                        difficulty: Difficulty,
                        laps: Int,
                        environment: TrackEnvironment) {
        var track = track
        track.environment = environment
        track.isBuiltIn = TrackCatalog.builtIn.contains(where: { $0.id == track.id })
        var opponent = CarConfig.standard(for: opponentModel(for: difficulty))
        opponent.primaryHex = opponentColor(for: track, difficulty: difficulty)
        let config = RaceConfig(mode: .quick,
                                track: track,
                                playerCar: unlockedCar(car),
                                opponentCar: opponent,
                                difficulty: difficulty,
                                laps: max(1, min(20, laps)),
                                pursuitRole: .pursuer,
                                opponentName: opponentName(for: difficulty),
                                championshipContext: nil)
        route = .race(config)
    }

    func startPursuit(track: TrackLayout,
                      car: CarConfig,
                      difficulty: Difficulty,
                      role: PursuitRole,
                      environment: TrackEnvironment) {
        var track = track
        track.environment = environment
        var opponent = CarConfig.standard(for: role == .pursuer ? .gt : .formula)
        opponent.primaryHex = role == .pursuer ? "#2E7BE8" : "#E0B32A"
        let config = RaceConfig(mode: .pursuit,
                                track: track,
                                playerCar: unlockedCar(car),
                                opponentCar: opponent,
                                difficulty: difficulty,
                                laps: 3,
                                pursuitRole: role,
                                opponentName: role == .pursuer ? "Fugitive GT" : "Pursuit Unit",
                                championshipContext: nil)
        route = .race(config)
    }

    func startTestDrive(track: TrackLayout) {
        guard TrackPathBuilder.build(track).isClosed else { return }
        var track = track
        track.isBuiltIn = false
        var opponent = CarConfig.standard(for: .gt)
        opponent.primaryHex = "#2E7BE8"
        let config = RaceConfig(mode: .quick,
                                track: track,
                                playerCar: unlockedCar(profile.carConfig),
                                opponentCar: opponent,
                                difficulty: .medium,
                                laps: 2,
                                pursuitRole: .pursuer,
                                opponentName: "Test Rival",
                                championshipContext: nil,
                                isTestDrive: true)
        route = .race(config)
    }

    func rematch() {
        guard var config = lastRaceConfig else {
            route = .menu
            return
        }
        if config.mode == .championship {
            startChampionshipRound()
            return
        }
        config.id = UUID()
        route = .race(config)
    }

    func changeSetup() {
        guard let config = lastRaceConfig else {
            route = .menu
            return
        }
        switch config.mode {
        case .pursuit:
            route = .pursuitSetup
        case .quick, .qualifying:
            route = .quickSetup
        case .championship:
            route = .championship
        }
    }

    // MARK: - Race completion

    /// Applies a finished race to the local profile exactly once. The race
    /// overlay calls this immediately so restarting or quitting from the
    /// finish banner cannot discard a result. Returning to the results screen
    /// later is idempotent and routes with the processed result (including
    /// unlocks and achievement messages).
    @discardableResult
    func recordRace(_ incoming: RaceResult, config: RaceConfig) -> RaceResult {
        if let existing = lastRaceResult, existing.id == incoming.id {
            return existing
        }

        var result = incoming
        lastRaceConfig = config

        if config.isTestDrive || result.mode == .qualifying {
            lastRaceResult = result
            return result
        }

        let wasRallyUnlocked = profile.isUnlocked(.rally)
        let wasFormulaUnlocked = profile.isUnlocked(.formula)
        let hadDecal1 = profile.unlockedDecalStyles.contains(1)
        let hadDecal2 = profile.unlockedDecalStyles.contains(2)
        let hadDecal3 = profile.unlockedDecalStyles.contains(3)

        let playerCar = result.cars.first(where: { $0.isPlayer })
        var roundPosition = playerCar?.position ?? 0
        var playerChampion = false
        var completedRound: ChampionshipRound?

        if result.mode == .championship, var season = championship {
            let wasComplete = season.completed
            completedRound = ChampionshipDirector.recordRound(state: &season, result: result)
            championship = season
            saveStore.saveChampionship(season)
            roundPosition = completedRound?.playerPosition ?? roundPosition
            if !wasComplete, season.completed, season.championName == profile.playerName {
                playerChampion = true
                profile.championships += 1
            }
        }

        profile.races += 1
        let wonHeat = result.playerWon
        let wonRound = result.mode == .championship ? roundPosition == 1 : wonHeat
        if wonRound { profile.wins += 1 }
        let podium = result.mode == .championship ? roundPosition <= 3 : (playerCar?.position ?? 99) <= 3
        if podium { profile.podiums += 1 }
        if result.mode == .pursuit, result.playerWon { profile.pursuitsWon += 1 }

        if result.playerBestLap > 0 {
            let existing = profile.bestLaps[result.trackName] ?? .greatestFiniteMagnitude
            if result.playerBestLap < existing {
                profile.bestLaps[result.trackName] = result.playerBestLap
            }
        }
        profile.topSpeed = max(profile.topSpeed, result.playerTopSpeed)
        if let playerCar {
            profile.totalDistance += (playerCar.averageSpeed / 30.0) * playerCar.totalTime
        }

        let completedLoop = config.track.pieces.contains(where: { $0.kind == .loop360 })
            && (playerCar?.completedLaps ?? 0) > 0
        let newAchievements = AchievementService.evaluate(result: result,
                                                          profile: &profile,
                                                          champion: playerChampion,
                                                          loopCompleted: completedLoop)

        if profile.wins > 0, !profile.isUnlocked(.rally) {
            profile.unlockedCars.append(CarModelKind.rally.rawValue)
        }
        if profile.championships > 0, !profile.isUnlocked(.formula) {
            profile.unlockedCars.append(CarModelKind.formula.rawValue)
        }
        if profile.podiums >= 1, !profile.unlockedDecalStyles.contains(1) {
            profile.unlockedDecalStyles.append(1)
        }
        if profile.podiums >= 3, !profile.unlockedDecalStyles.contains(2) {
            profile.unlockedDecalStyles.append(2)
        }
        if profile.wins >= 3, !profile.unlockedDecalStyles.contains(3) {
            profile.unlockedDecalStyles.append(3)
        }

        if !wasRallyUnlocked, profile.isUnlocked(.rally) {
            result.unlockMessages.append("80s Rally unlocked")
        }
        if !wasFormulaUnlocked, profile.isUnlocked(.formula) {
            result.unlockMessages.append("Open Wheel unlocked")
        }
        if !hadDecal1, profile.unlockedDecalStyles.contains(1) {
            result.unlockMessages.append("Livery set 01 unlocked")
        }
        if !hadDecal2, profile.unlockedDecalStyles.contains(2) {
            result.unlockMessages.append("Livery set 02 unlocked")
        }
        if !hadDecal3, profile.unlockedDecalStyles.contains(3) {
            result.unlockMessages.append("Livery set 03 unlocked")
        }
        result.achievementMessages = newAchievements.map(AchievementService.title(for:))

        profile.favoriteTrack = result.trackName
        saveStore.saveProfile(profile)

        gameCenter.report(profile: profile, championshipPoints: playerChampionshipPoints)
        for achievement in newAchievements {
            gameCenter.reportAchievement(id: achievement)
        }

        lastRaceResult = result
        return result
    }

    func finishRace(_ incoming: RaceResult, config: RaceConfig) {
        let result = recordRace(incoming, config: config)
        route = .results(result)
    }

    // MARK: - Championship

    func startChampionship(fieldSize: Int, difficulty: Difficulty) {
        var season = ChampionshipDirector.newSeason(profile: profile,
                                                    fieldSize: fieldSize,
                                                    difficulty: difficulty)
        if season.entrants.first(where: { $0.isPlayer })?.name == "YOU" {
            // Keep the profile display name when it is not blank.
            if !profile.playerName.isEmpty, let index = season.entrants.firstIndex(where: { $0.isPlayer }) {
                season.entrants[index].name = profile.playerName
            }
        }
        championship = season
        saveStore.saveChampionship(season)
        route = .championship
    }

    func startChampionshipRound() {
        guard let season = championship,
              let config = ChampionshipDirector.makeRaceConfig(state: season, playerCar: unlockedCar(profile.carConfig)) else {
            route = .championship
            return
        }
        route = .race(config)
    }

    func simulateQualifying() {
        guard var season = championship else { return }
        ChampionshipDirector.simulateQualifying(state: &season)
        championship = season
        saveStore.saveChampionship(season)
    }

    func abandonChampionship() {
        championship = nil
        saveStore.saveChampionship(nil)
    }

    var standings: [ChampionshipEntrant] {
        guard let championship else { return [] }
        return ChampionshipDirector.standings(state: championship)
    }

    // MARK: - Garage and tracks

    func updateCar(_ config: CarConfig) {
        guard profile.isUnlocked(config.model) else { return }
        profile.carConfig = config
        saveStore.saveProfile(profile)
    }

    func saveTrack(_ track: TrackLayout) {
        var track = track
        track.isBuiltIn = false
        saveStore.saveTrack(track)
        if let index = customTracks.firstIndex(where: { $0.id == track.id }) {
            customTracks[index] = track
        } else {
            customTracks.insert(track, at: 0)
        }
    }

    func deleteTrack(_ track: TrackLayout) {
        guard !track.isBuiltIn else { return }
        saveStore.deleteTrack(id: track.id)
        customTracks.removeAll(where: { $0.id == track.id })
    }

    func importTrack(_ track: TrackLayout) {
        var track = track
        track.isBuiltIn = false
        saveTrack(track)
    }

    // MARK: - Settings and data

    func updateSettings(_ settings: AppSettings) {
        self.settings = settings
        SettingsStore.save(settings)
        AudioDirector.shared.apply(settings: settings)
    }

    func toggleMute() {
        let value = !AudioDirector.shared.isMuted
        AudioDirector.shared.setMuted(value)
        isMuted = value
    }

    func setMuted(_ value: Bool) {
        AudioDirector.shared.setMuted(value)
        isMuted = value
    }

    func testCloudAI(endpoint: String? = nil) async -> Bool {
        await cloudAI.testConnection(endpoint: endpoint ?? settings.cloudAIURL)
    }

    func unlockAll() {
        profile.unlockedCars = CarModelKind.allCases.map(\.rawValue)
        profile.unlockedDecalStyles = [0, 1, 2, 3]
        saveStore.saveProfile(profile)
    }

    func resetAllData() {
        profile = .fresh()
        championship = nil
        SettingsStore.save(.default)
        settings = .default
        saveStore.saveProfile(profile)
        saveStore.saveChampionship(nil)
        for track in customTracks {
            saveStore.deleteTrack(id: track.id)
        }
        customTracks = []
        AudioDirector.shared.apply(settings: settings)
        route = .menu
    }

    // MARK: - Helpers

    private func unlockedCar(_ config: CarConfig) -> CarConfig {
        profile.isUnlocked(config.model) ? config : .standard(for: .gt)
    }

    private func opponentModel(for difficulty: Difficulty) -> CarModelKind {
        switch difficulty {
        case .easy: return .rally
        case .medium: return .gt
        case .hard: return .formula
        }
    }

    private func opponentColor(for track: TrackLayout, difficulty: Difficulty) -> String {
        switch difficulty {
        case .easy: return "#2FB37A"
        case .medium: return "#2E7BE8"
        case .hard: return "#9D5BE8"
        }
    }

    private func opponentName(for difficulty: Difficulty) -> String {
        switch difficulty {
        case .easy: return "R. Lindqvist"
        case .medium: return "V. Rossi"
        case .hard: return "K. Tanaka"
        }
    }
}
