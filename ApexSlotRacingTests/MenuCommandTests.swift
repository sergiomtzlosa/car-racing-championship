import SwiftUI
import XCTest
@testable import ApexSlotRacing

@MainActor
final class MenuCommandTests: ApexUITestCase {
    func testEveryMenuCommandHasATitleShortcutAndAction() {
        XCTAssertEqual(ApexMenuCommand.allCases.count, 8)

        let expectations: [(ApexMenuCommand, String, String, EventModifiers)] = [
            (.quickRace, "Quick Race", "n", [.command]),
            (.pursuit, "Pursuit", "p", [.command, .shift]),
            (.championship, "Championship", "c", [.command, .shift]),
            (.garage, "Garage", "g", [.command]),
            (.trackEditor, "Track Editor", "e", [.command]),
            (.mainMenu, "Main Menu", "m", [.command, .shift]),
            (.mute, "Mute Audio", "m", [.command, .option]),
            (.help, "Apex Slot Racing Help", "?", [.command])
        ]

        for (command, title, key, modifiers) in expectations {
            XCTAssertEqual(command.title(isMuted: false), title)
            XCTAssertEqual(String(command.shortcutKey.character), key)
            XCTAssertEqual(command.shortcutModifiers, modifiers)
        }
        XCTAssertEqual(ApexMenuCommand.mute.title(isMuted: true), "Unmute Audio")

        app.goToMenu()
        ApexMenuCommand.quickRace.perform(on: app)
        XCTAssertEqual(app.route, .quickSetup)

        app.goToMenu()
        ApexMenuCommand.pursuit.perform(on: app)
        XCTAssertEqual(app.route, .pursuitSetup)

        app.goToMenu()
        ApexMenuCommand.championship.perform(on: app)
        XCTAssertEqual(app.route, .championship)

        app.goToMenu()
        ApexMenuCommand.garage.perform(on: app)
        XCTAssertEqual(app.route, .garage)

        app.goToMenu()
        ApexMenuCommand.trackEditor.perform(on: app)
        XCTAssertEqual(app.route, .editor)

        app.goToMenu()
        XCTAssertEqual(app.route, .menu)

        let initialMute = app.isMuted
        ApexMenuCommand.mute.perform(on: app)
        XCTAssertNotEqual(app.isMuted, initialMute)
        ApexMenuCommand.mute.perform(on: app)
        XCTAssertEqual(app.isMuted, initialMute)

        var helpRequests = 0
        app.helpPresentation = { helpRequests += 1 }
        ApexMenuCommand.help.perform(on: app)
        XCTAssertEqual(helpRequests, 1)
        app.helpPresentation = nil
    }
}
