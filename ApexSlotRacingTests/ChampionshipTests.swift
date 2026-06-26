import XCTest
@testable import ApexSlotRacing

final class ChampionshipTests: XCTestCase {
    func testNewSeasonSupportsTwoToEightEntrants() {
        let profile = PlayerProfile.fresh()
        for field in [2, 4, 6, 8] {
            let season = ChampionshipDirector.newSeason(profile: profile, fieldSize: field, difficulty: .medium)
            XCTAssertEqual(season.entrants.count, field)
            XCTAssertEqual(season.entrants.filter { $0.isPlayer }.count, 1)
            XCTAssertEqual(season.rounds.count, TrackCatalog.builtIn.count)
            XCTAssertEqual(Set(season.entrants.map(\.name)).count, field)
            XCTAssertFalse(season.completed)
            XCTAssertEqual(ChampionshipDirector.standings(state: season).count, field)
        }
        XCTAssertEqual(ChampionshipDirector.newSeason(profile: profile, fieldSize: 1, difficulty: .easy).entrants.count, 2)
        XCTAssertEqual(ChampionshipDirector.newSeason(profile: profile, fieldSize: 99, difficulty: .hard).entrants.count, 8)
    }

    func testQualifyingIsDeterministicAndSeedsAllEntrants() {
        var season = ChampionshipDirector.newSeason(profile: .fresh(), fieldSize: 8, difficulty: .medium)
        XCTAssertTrue(ChampionshipDirector.qualifyingOrder(state: season).isEmpty)
        ChampionshipDirector.simulateQualifying(state: &season)
        let firstOrder = ChampionshipDirector.qualifyingOrder(state: season)
        XCTAssertEqual(firstOrder.count, 8)
        XCTAssertEqual(firstOrder.map(\.qualifyingTime), firstOrder.map(\.qualifyingTime).sorted())

        var second = season
        ChampionshipDirector.simulateQualifying(state: &second)
        XCTAssertEqual(firstOrder.map(\.qualifyingTime), ChampionshipDirector.qualifyingOrder(state: second).map(\.qualifyingTime))
    }

    func testRoundPointsAndSeasonCompletion() {
        var season = ChampionshipDirector.newSeason(profile: .fresh(), fieldSize: 8, difficulty: .medium)
        XCTAssertEqual(ChampionshipDirector.pointsTable, [10, 6, 4, 2])

        for roundIndex in 0..<season.rounds.count {
            XCTAssertEqual(season.currentRoundIndex, roundIndex)
            guard let rival = ChampionshipDirector.rival(for: season) else {
                return XCTFail("No rival for round \(roundIndex)")
            }
            let track = TrackCatalog.layout(for: season.rounds[roundIndex].trackID, custom: [])!
            let result = TestSupport.raceResult(track: track,
                                                playerTime: 50,
                                                rivalTime: 62,
                                                rivalName: rival.name)
            let recorded = ChampionshipDirector.recordRound(state: &season, result: result)
            XCTAssertNotNil(recorded)
            XCTAssertTrue(season.rounds[roundIndex].completed)
            XCTAssertEqual(season.rounds[roundIndex].playerPoints, 10)
            XCTAssertEqual(season.rounds[roundIndex].playerPosition, 1)
            XCTAssertEqual(season.rounds[roundIndex].results.count, 8)
        }

        XCTAssertTrue(season.completed)
        XCTAssertEqual(season.currentRoundIndex, season.rounds.count)
        let standings = ChampionshipDirector.standings(state: season)
        XCTAssertEqual(standings.first?.points, 40)
        XCTAssertTrue(standings.first?.isPlayer ?? false)
        XCTAssertEqual(season.championName, standings.first?.name)
        XCTAssertEqual(standings.first?.wins, 4)
        XCTAssertEqual(standings.first?.podiums, 4)
        XCTAssertGreaterThan(standings.first?.bestLap ?? 0, 0)
    }

    func testRoundConfigSelectsARivalAndKeepsPlayerCar() {
        let season = ChampionshipDirector.newSeason(profile: .fresh(), fieldSize: 6, difficulty: .hard)
        let car = CarConfig.standard(for: .rally)
        let config = ChampionshipDirector.makeRaceConfig(state: season, playerCar: car)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.mode, .championship)
        XCTAssertEqual(config?.laps, 3)
        XCTAssertEqual(config?.difficulty, .hard)
        XCTAssertEqual(config?.playerCar, car)
        XCTAssertNotNil(config?.championshipContext)
        XCTAssertEqual(config?.championshipContext?.roundIndex, 0)
    }

    func testChampionshipStatePersistsThroughSaveStore() throws {
        let directory = try TestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore(rootURL: directory)
        var season = ChampionshipDirector.newSeason(profile: .fresh(), fieldSize: 4, difficulty: .easy)
        ChampionshipDirector.simulateQualifying(state: &season)
        season.createdAt = Date(timeIntervalSince1970: 100_000)
        season.updatedAt = Date(timeIntervalSince1970: 123_456)

        store.saveChampionship(season)
        let loaded = store.loadChampionship()
        XCTAssertEqual(loaded, season)
        XCTAssertEqual(loaded?.entrants.count, 4)

        store.saveChampionship(nil)
        XCTAssertNil(store.loadChampionship())
    }

    func testSmallFieldCanCompleteWithoutCrashing() {
        var season = ChampionshipDirector.newSeason(profile: .fresh(), fieldSize: 2, difficulty: .easy)
        for _ in 0..<4 {
            guard let rival = ChampionshipDirector.rival(for: season) else {
                return XCTFail("Missing rival")
            }
            let track = TrackCatalog.layout(for: season.rounds[season.currentRoundIndex].trackID, custom: [])!
            let result = TestSupport.raceResult(track: track,
                                                playerTime: 40,
                                                rivalTime: 41,
                                                rivalName: rival.name)
            ChampionshipDirector.recordRound(state: &season, result: result)
        }
        XCTAssertTrue(season.completed)
        XCTAssertNotNil(season.championName)
        XCTAssertEqual(ChampionshipDirector.makeRaceConfig(state: season, playerCar: .standard(for: .gt)), nil)
    }
}
