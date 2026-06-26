import SwiftUI
import XCTest
@testable import ApexSlotRacing

@MainActor
final class ChampionshipUITests: ApexUITestCase {
    func testSeasonSetupControlsStartAConfiguredSeason() {
        show(ChampionshipView())

        for identifier in ["championship.back",
                           "championship.field.2",
                           "championship.field.4",
                           "championship.field.6",
                           "championship.field.8",
                           "championship.difficulty",
                           "championship.garage",
                           "championship.startSeason"] {
            XCTAssertTrue(ui.exists(identifier), "Missing \(identifier)")
        }

        ui.press("championship.field.2")
        XCTAssertNotNil(ui.text(containing: "2-DRIVER FIELD"))
        ui.pressOption(in: "championship.difficulty", label: "Hard")
        ui.press("championship.startSeason")

        guard let season = app.championship else {
            return XCTFail("Start Season did not create a championship")
        }
        XCTAssertEqual(season.entrants.count, 2)
        XCTAssertEqual(season.difficulty, .hard)
        XCTAssertEqual(app.route, .championship)

        XCTAssertTrue(ui.exists("championship.startRound"))
        XCTAssertTrue(ui.exists("championship.abandon"))
        XCTAssertTrue(ui.exists("championship.simulateQualifying"))
    }

    func testQualifyingAndRoundStartRouteToAChampionshipRace() {
        app.startChampionship(fieldSize: 4, difficulty: .medium)
        show(ChampionshipView())

        XCTAssertTrue(ui.exists("championship.simulateQualifying"))
        ui.press("championship.simulateQualifying")
        XCTAssertTrue(waitUntil { self.app.championship?.entrants.contains(where: { $0.qualifyingTime > 0 }) == true })

        ui.press("championship.startRound")
        guard let config = raceConfig else {
            return XCTFail("Start Round did not route to a race")
        }
        XCTAssertEqual(config.mode, .championship)
        XCTAssertEqual(config.championshipContext?.roundIndex, 0)
        XCTAssertEqual(config.laps, 3)
    }

    func testAbandonConfirmationKeepsThenDeletesSeason() {
        app.startChampionship(fieldSize: 6, difficulty: .medium)
        show(ChampionshipView())

        ui.press("championship.abandon")
        XCTAssertTrue(ui.pressButton(label: "Keep Season"))
        XCTAssertNotNil(app.championship)

        ui.press("championship.abandon")
        XCTAssertTrue(ui.pressButton(label: "Abandon"))
        XCTAssertNil(app.championship)
        XCTAssertEqual(app.route, .championship)
        XCTAssertTrue(ui.exists("championship.startSeason"))
    }

    func testGarageAndBackNavigation() {
        show(ChampionshipView())
        ui.press("championship.garage")
        XCTAssertEqual(app.route, .garage)

        app.goToMenu()
        show(ChampionshipView())
        ui.press("championship.back")
        XCTAssertEqual(app.route, .menu)
    }

    func testCompletedSeasonShowsChampionBannerAndActions() {
        app.startChampionship(fieldSize: 4, difficulty: .medium)

        for _ in 0..<4 {
            guard let season = app.championship,
                  let config = ChampionshipDirector.makeRaceConfig(state: season,
                                                                  playerCar: app.profile.carConfig),
                  let context = config.championshipContext else {
                return XCTFail("Could not prepare championship round")
            }
            let result = TestSupport.raceResult(track: config.track,
                                                mode: .championship,
                                                playerTime: 40,
                                                rivalTime: 50,
                                                rivalName: context.rivalName,
                                                playerPosition: 1,
                                                rivalPosition: 2,
                                                context: context)
            app.finishRace(result, config: config)
        }

        XCTAssertEqual(app.championship?.completed, true)
        XCTAssertEqual(app.championship?.championName, app.profile.playerName)
        XCTAssertTrue(app.profile.isUnlocked(.formula))
        XCTAssertTrue(app.profile.achievements.contains("apex.champion"))

        show(ChampionshipView())
        XCTAssertNotNil(ui.text(containing: "YOU ARE THE CHAMPION"))
        XCTAssertTrue(ui.exists("championship.mainMenu"))
        XCTAssertTrue(ui.exists("championship.newSeason"))

        ui.press("championship.mainMenu")
        XCTAssertEqual(app.route, .menu)

        app.openChampionship()
        show(ChampionshipView())
        ui.press("championship.newSeason")
        XCTAssertNil(app.championship)
        XCTAssertEqual(app.route, .championship)
        XCTAssertTrue(ui.exists("championship.startSeason"))
    }
}
