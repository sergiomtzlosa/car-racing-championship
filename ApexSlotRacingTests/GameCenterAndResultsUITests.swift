import SwiftUI
import XCTest
@testable import ApexSlotRacing

@MainActor
final class GameCenterUITests: ApexUITestCase {
    func testGameCenterControlsAndOfflineFallback() {
        show(GameCenterView())

        XCTAssertTrue(ui.exists("gameCenter.back"))
        XCTAssertTrue(ui.exists("gameCenter.signIn"))
        XCTAssertTrue(ui.exists("gameCenter.dashboard"))
        // Native GameKit authentication presents a system overlay; the unsigned
        // local build has no entitlement, so only the offline fallback is
        // exercised here. The button is present and enabled for configured builds.
        XCTAssertEqual(ui.isEnabled("gameCenter.signIn"), true)
        XCTAssertEqual(ui.isEnabled("gameCenter.dashboard"), false)
        XCTAssertFalse(app.gameCenter.isAuthenticated)
        XCTAssertNotNil(ui.text(containing: "LOCAL PROFILE"))
        XCTAssertNotNil(ui.text(containing: "Local records active"))

        ui.press("gameCenter.back")
        XCTAssertEqual(app.route, .menu)
    }

    func testOfflineLocalRecordsAndAchievementsUpdate() {
        let track = TrackCatalog.sunsetSpeedway
        let config = TestSupport.config(track: track, mode: .quick, laps: 3)
        let result = TestSupport.raceResult(track: track,
                                            mode: .quick,
                                            playerTime: 40,
                                            rivalTime: 41,
                                            rivalName: "V. Rossi",
                                            playerPosition: 1,
                                            rivalPosition: 2)
        app.finishRace(result, config: config)

        XCTAssertEqual(app.profile.races, 1)
        XCTAssertEqual(app.profile.wins, 1)
        XCTAssertEqual(app.profile.bestLaps[track.name] ?? 0, 40.0 / 3.0, accuracy: 0.0001)
        XCTAssertTrue(app.profile.achievements.contains("apex.first.win"))
        XCTAssertTrue(app.profile.achievements.contains("apex.flawless"))

        show(GameCenterView())
        XCTAssertNotNil(ui.text(containing: "0:13.333"))
        XCTAssertNotNil(ui.text(containing: "280 km/h"))
        XCTAssertNotNil(ui.text(containing: "First Blood"))
        XCTAssertNotNil(ui.text(containing: "Flawless Drive"))
        XCTAssertNotNil(ui.text(containing: "UNLOCKED"))
    }
}

@MainActor
final class ResultsUITests: ApexUITestCase {
    func testQuickResultActionsAndClassification() {
        let config = TestSupport.config(track: TrackCatalog.sunsetSpeedway, mode: .quick, laps: 3)
        let result = TestSupport.raceResult(track: TrackCatalog.sunsetSpeedway,
                                            mode: .quick,
                                            playerTime: 94.2,
                                            rivalTime: 95.1,
                                            rivalName: "V. Rossi")
        app.finishRace(result, config: config)
        guard let recorded = app.lastRaceResult else {
            return XCTFail("Race result was not recorded")
        }

        show(ResultsView(result: recorded))
        for identifier in ["results.back",
                           "results.outcome",
                           "results.raceAgain",
                           "results.changeSetup",
                           "results.mainMenu"] {
            XCTAssertTrue(ui.exists(identifier), "Missing \(identifier)")
        }
        XCTAssertEqual(ui.value("results.outcome"), "VICTORY")
        XCTAssertNil(ui.find("results.standings", timeout: 0.2))

        ui.press("results.raceAgain")
        guard let rematch = raceConfig else {
            return XCTFail("Race Again did not route to a race")
        }
        XCTAssertEqual(rematch.mode, .quick)
        XCTAssertEqual(rematch.track.id, TrackCatalog.sunsetID)
        XCTAssertEqual(rematch.laps, 3)

        app.goToMenu()
        show(ResultsView(result: recorded))
        ui.press("results.changeSetup")
        XCTAssertEqual(app.route, .quickSetup)

        app.goToMenu()
        show(ResultsView(result: recorded))
        ui.press("results.mainMenu")
        XCTAssertEqual(app.route, .menu)

        show(ResultsView(result: recorded))
        ui.press("results.back")
        XCTAssertEqual(app.route, .menu)
    }

    func testChampionshipResultShowsStandingsAndNextRound() {
        app.startChampionship(fieldSize: 4, difficulty: .medium)
        guard let season = app.championship,
              let track = app.track(id: season.rounds[0].trackID) else {
            return XCTFail("Championship did not provide a round track")
        }

        let context = ChampionshipRaceContext(roundIndex: 0,
                                              rivalName: "V. Rossi",
                                              rivalColorHex: "#2E7BE8",
                                              rivalSkill: 0.85)
        let result = TestSupport.raceResult(track: track,
                                            mode: .championship,
                                            playerTime: 91.4,
                                            rivalTime: 92.0,
                                            rivalName: "V. Rossi",
                                            context: context)
        let config = TestSupport.config(track: track, mode: .championship, laps: 3)
        app.finishRace(result, config: config)
        guard let recorded = app.lastRaceResult else {
            return XCTFail("Championship result was not recorded")
        }

        show(ResultsView(result: recorded))
        XCTAssertTrue(ui.exists("results.standings"))
        XCTAssertTrue(ui.exists("results.raceAgain"))

        ui.press("results.standings")
        XCTAssertEqual(app.route, .championship)
    }
}
