import SwiftUI
import XCTest
@testable import ApexSlotRacing

@MainActor
final class RaceSetupUITests: ApexUITestCase {
    func testQuickRaceSetupControlsBuildTheSelectedConfig() {
        app.unlockAll()
        show(RaceSetupView(mode: .quick))

        for identifier in ["setup.back",
                           "setup.track.sunset-speedway",
                           "setup.track.harbor-hairpins",
                           "setup.track.loop-360",
                           "setup.track.night-grand-prix",
                           "setup.car.gt",
                           "setup.car.rally",
                           "setup.car.formula",
                           "setup.difficulty",
                           "setup.laps.3",
                           "setup.laps.5",
                           "setup.laps.10",
                           "setup.environment",
                           "setup.start"] {
            XCTAssertTrue(ui.exists(identifier), "Missing \(identifier)")
        }

        ui.press("setup.track.night-grand-prix")
        XCTAssertTrue(waitUntil { (self.ui.text(containing: "Night Grand Prix") != nil) })

        ui.pressOption(in: "setup.environment", label: "Club Day")
        ui.pressOption(in: "setup.difficulty", label: "Hard")
        ui.press("setup.laps.10")
        ui.press("setup.car.rally")
        ui.press("setup.start")

        guard let config = raceConfig else {
            return XCTFail("Start Race did not route to a race")
        }
        XCTAssertEqual(config.mode, .quick)
        XCTAssertEqual(config.track.id, TrackCatalog.nightID)
        XCTAssertEqual(config.difficulty, .hard)
        XCTAssertEqual(config.laps, 10)
        XCTAssertEqual(config.playerCar.model, .rally)
        XCTAssertEqual(config.track.environment, .club)
    }

    func testPursuitRoleAndDifficultyAreApplied() {
        show(RaceSetupView(mode: .pursuit))

        for identifier in ["setup.role.pursuer",
                           "setup.role.fugitive",
                           "setup.difficulty",
                           "setup.environment",
                           "setup.start"] {
            XCTAssertTrue(ui.exists(identifier), "Missing \(identifier)")
        }
        XCTAssertFalse(ui.exists("setup.laps.3"), "Pursuit is fixed at three laps")

        ui.press("setup.role.fugitive")
        ui.pressOption(in: "setup.difficulty", label: "Easy")
        ui.press("setup.start")

        guard let config = raceConfig else {
            return XCTFail("Start Pursuit did not route to a race")
        }
        XCTAssertEqual(config.mode, .pursuit)
        XCTAssertEqual(config.pursuitRole, .fugitive)
        XCTAssertEqual(config.difficulty, .easy)
        XCTAssertEqual(config.laps, 3)
    }

    func testOpenCircuitShowsEditorHandoffAndLoadsInEditor() {
        var open = TrackLayout(name: "Open Test",
                               pieces: [TrackPiece(kind: .startFinish, length: 8)],
                               environment: .club,
                               isBuiltIn: false)
        open.isBuiltIn = false
        app.saveTrack(open)
        show(RaceSetupView(mode: .quick))
        ui.press("setup.track.open-test")
        XCTAssertTrue(ui.exists("setup.openEditor"))
        XCTAssertEqual(ui.isEnabled("setup.start"), false)

        ui.press("setup.openEditor")
        XCTAssertEqual(app.route, .editor)
        XCTAssertNotNil(app.pendingEditorTrack)

        show(TrackEditorView())
        XCTAssertEqual(ui.value("editor.name") ?? "", "Open Test")
    }

    func testBackReturnsToMenu() {
        show(RaceSetupView(mode: .quick))
        ui.press("setup.back")
        XCTAssertEqual(app.route, .menu)
    }
}
