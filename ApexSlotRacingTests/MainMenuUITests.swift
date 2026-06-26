import SwiftUI
import XCTest
@testable import ApexSlotRacing

@MainActor
final class MainMenuUITests: ApexUITestCase {
    func testEveryMenuTileAndHeroControlNavigates() {
        show(MainMenuView())

        for identifier in ["menu.championship",
                           "menu.quickRace",
                           "menu.pursuit",
                           "menu.trackEditor",
                           "menu.garage",
                           "menu.settings",
                           "menu.gameCenter",
                           "menu.heroGarage",
                           "menu.quit"] {
            XCTAssertTrue(ui.exists(identifier), "Missing \(identifier)")
        }

        ui.press("menu.championship")
        XCTAssertEqual(app.route, .championship)

        ui.press("menu.quickRace")
        XCTAssertEqual(app.route, .quickSetup)

        ui.press("menu.pursuit")
        XCTAssertEqual(app.route, .pursuitSetup)

        ui.press("menu.trackEditor")
        XCTAssertEqual(app.route, .editor)

        ui.press("menu.garage")
        XCTAssertEqual(app.route, .garage)

        ui.press("menu.settings")
        XCTAssertEqual(app.route, .settings)

        ui.press("menu.gameCenter")
        XCTAssertEqual(app.route, .gameCenter)

        ui.press("menu.heroGarage")
        XCTAssertEqual(app.route, .garage)
    }

    func testMenuReflectsProfileAndChampionshipSummary() {
        app.startChampionship(fieldSize: 4, difficulty: .hard)
        show(MainMenuView())

        XCTAssertTrue(ui.exists("menu.championship"))
        let subtitle = ui.value("menu.championship") ?? ""
        let title = ui.label("menu.championship") ?? ""
        XCTAssertTrue((subtitle + title).contains("Round") || (subtitle + title).contains("4"),
                      "Expected an active-season summary, got '\(title) \(subtitle)'")
    }

    func testMenuMuteCommandTogglesObservableState() {
        show(MainMenuView())
        let initial = app.isMuted
        app.toggleMute()
        XCTAssertNotEqual(app.isMuted, initial)
        app.toggleMute()
        XCTAssertEqual(app.isMuted, initial)
    }
}
