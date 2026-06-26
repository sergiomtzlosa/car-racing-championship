import SwiftUI
import XCTest
@testable import ApexSlotRacing

@MainActor
final class RaceHUDUITests: ApexUITestCase {
    func testHUDElementsTelemetryAndControls() {
        let config = TestSupport.config(track: TrackCatalog.sunsetSpeedway, mode: .quick, laps: 5)
        let session = RaceSession(settings: .default)
        show(RaceHUD(config: config, session: session))

        for identifier in ["hud.position",
                           "hud.lap",
                           "hud.raceTime",
                           "hud.bestLap",
                           "hud.minimap",
                           "hud.aiStatus",
                           "hud.camera",
                           "hud.mute",
                           "hud.pause",
                           "hud.speed",
                           "hud.deslots",
                           "hud.throttle",
                           "hud.brake",
                           "hud.countdown"] {
            XCTAssertTrue(ui.exists(identifier), "Missing \(identifier)")
        }
        XCTAssertNotNil(ui.text(containing: "LOCAL AI"))

        var telemetry = RaceTelemetry.placeholder
        telemetry.speed = 123
        telemetry.position = 2
        telemetry.lap = 4
        telemetry.totalLaps = 5
        telemetry.bestLap = 12.345
        telemetry.deslots = 1
        session.publish(telemetry)
        XCTAssertTrue(waitUntil { (self.ui.value("hud.speed") ?? "") == "123" })
        XCTAssertTrue(waitUntil { (self.ui.value("hud.deslots") ?? "") == "1" })
        XCTAssertNotNil(ui.text(containing: "P2"))

        telemetry.phase = .racing
        telemetry.raceTime = 0.5
        session.publish(telemetry)
        XCTAssertTrue(waitUntil { self.ui.exists("hud.go") })

        telemetry.raceTime = 30
        telemetry.warning = "BRAKE"
        telemetry.statusMessage = "SLOT DESLOT — RECOVERING"
        telemetry.lap = 5
        session.publish(telemetry)
        XCTAssertTrue(waitUntil { (self.ui.value("hud.warning") ?? "") == "BRAKE" })
        XCTAssertTrue(waitUntil { (self.ui.value("hud.status") ?? "").contains("SLOT DESLOT") })
        XCTAssertTrue(waitUntil { self.ui.exists("hud.finalLap") })

        telemetry.penalty = 2.4
        session.publish(telemetry)
        XCTAssertTrue(waitUntil { self.ui.exists("hud.penalty") })

        let initialCamera = session.cameraMode
        ui.press("hud.camera")
        XCTAssertNotEqual(session.cameraMode, initialCamera)

        XCTAssertFalse(session.isMuted)
        ui.press("hud.mute")
        XCTAssertTrue(session.isMuted)
        ui.press("hud.mute")
        XCTAssertFalse(session.isMuted)

        ui.press("hud.pause")
        XCTAssertTrue(session.isPaused)
        ui.press("hud.pause")
        XCTAssertFalse(session.isPaused)

        ui.press("hud.throttle")
        XCTAssertEqual(session.input.snapshot().throttle, 1)
        pump(0.5)
        XCTAssertEqual(session.input.snapshot().throttle, 0)

        ui.press("hud.brake")
        XCTAssertEqual(session.input.snapshot().brake, 1)
        pump(0.5)
        XCTAssertEqual(session.input.snapshot().brake, 0)
    }

    func testPursuitHUDShowsMeterBoostAndGuidance() {
        let config = TestSupport.config(track: TrackCatalog.loop360, mode: .pursuit, laps: 3)
        let session = RaceSession(settings: .default)
        show(RaceHUD(config: config, session: session))

        var telemetry = RaceTelemetry.placeholder
        telemetry.phase = .racing
        telemetry.raceTime = 10
        telemetry.playerIsPursuer = true
        telemetry.gap = 2.3
        telemetry.captureProgress = 0.55
        telemetry.boostCharges = 2
        telemetry.boostActive = true
        telemetry.pursuitTimeRemaining = 84
        session.publish(telemetry)

        XCTAssertTrue(waitUntil { self.ui.exists("hud.pursuitMeter") })
        XCTAssertTrue(waitUntil { self.ui.exists("hud.boost") })
        XCTAssertNotNil(ui.text(containing: "CAPTURE"))

        ui.press("hud.boost")
        pump(0.3)
        XCTAssertFalse(session.input.snapshot().boost)
    }
}

@MainActor
final class RaceOverlayUITests: ApexUITestCase {
    func testPauseOverlayResumeRestartAndQuit() {
        let config = TestSupport.config(track: TrackCatalog.sunsetSpeedway, mode: .quick, laps: 3)
        let session = RaceSession(settings: .default)
        session.togglePause()
        var quitCount = 0
        show(RacePauseOverlay(config: config, session: session, onQuit: { quitCount += 1 }))

        XCTAssertTrue(ui.exists("race.pause.title"))
        XCTAssertTrue(ui.exists("race.pause.resume"))
        XCTAssertTrue(ui.exists("race.pause.restart"))
        XCTAssertTrue(ui.exists("race.pause.quit"))

        ui.press("race.pause.resume")
        XCTAssertFalse(session.isPaused)

        session.togglePause()
        ui.press("race.pause.restart")
        XCTAssertFalse(session.isPaused)
        XCTAssertNil(session.result)

        session.togglePause()
        ui.press("race.pause.quit")
        XCTAssertEqual(quitCount, 1)
    }

    func testFinishOverlayActionsAndChampionshipRaceAgainVisibility() {
        let config = TestSupport.config(track: TrackCatalog.sunsetSpeedway, mode: .quick, laps: 3)
        let result = TestSupport.raceResult(track: TrackCatalog.sunsetSpeedway,
                                            mode: .quick,
                                            playerTime: 90,
                                            rivalTime: 91,
                                            rivalName: "V. Rossi")
        let session = RaceSession(settings: .default)
        session.finish(result)
        var completed: RaceResult?
        var quitCount = 0
        show(RaceFinishOverlay(config: config,
                               result: result,
                               session: session,
                               onComplete: { completed = $0 },
                               onQuit: { quitCount += 1 }))

        XCTAssertEqual(ui.value("race.finish.outcome"), "VICTORY")
        XCTAssertTrue(ui.exists("race.finish.raceAgain"))

        ui.press("race.finish.viewResults")
        XCTAssertEqual(completed?.id, result.id)

        ui.press("race.finish.raceAgain")
        XCTAssertNil(session.result)

        ui.press("race.finish.menu")
        XCTAssertEqual(quitCount, 1)

        let championshipConfig = TestSupport.config(track: TrackCatalog.sunsetSpeedway,
                                                    mode: .championship,
                                                    laps: 3)
        show(RaceFinishOverlay(config: championshipConfig,
                               result: result,
                               session: session,
                               onComplete: { _ in },
                               onQuit: {}))
        XCTAssertNil(ui.find("race.finish.raceAgain", timeout: 0.3))
    }
}
