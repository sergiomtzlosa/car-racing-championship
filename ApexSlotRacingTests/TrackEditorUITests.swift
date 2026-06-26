import SwiftUI
import XCTest
@testable import ApexSlotRacing

@MainActor
final class TrackEditorUITests: ApexUITestCase {
    func testEditorExposesEveryControlAndValidationReport() {
        show(TrackEditorView())

        for identifier in ["editor.back",
                           "editor.name",
                           "editor.environment",
                           "editor.fit",
                           "editor.validate",
                           "editor.testDrive",
                           "editor.save",
                           "editor.autoClose",
                           "editor.undo",
                           "editor.redo",
                           "editor.starter",
                           "editor.blank",
                           "editor.loadMenu",
                           "editor.summary",
                           "editor.resetCamera",
                           "editor.autoCloseHUD",
                           "editor.validationMessage",
                           "editor.replacePiece",
                           "editor.radius",
                           "editor.mirrorToggle",
                           "editor.delete",
                           "editor.mirror",
                           "editor.export",
                           "editor.import",
                           "editor.pasteJSON",
                           "editor.saveCustom"] {
            XCTAssertTrue(ui.exists(identifier), "Missing \(identifier)")
        }

        for kind in [TrackPieceKind.startFinish,
                     .straightLong,
                     .straightShort,
                     .chicane,
                     .curveSharp90,
                     .curveWide90,
                     .curveWide180,
                     .curve45,
                     .crossover,
                     .bridge,
                     .loop360] {
            XCTAssertTrue(ui.exists("editor.palette.\(kind.rawValue)"), "Missing palette \(kind.rawValue)")
        }

        XCTAssertEqual(ui.isEnabled("editor.undo"), false)
        XCTAssertEqual(ui.isEnabled("editor.redo"), false)

        ui.press("editor.validate")
        XCTAssertTrue(waitUntil { (self.ui.value("validation.headline") ?? "").contains("Circuit Ready") },
                      "Validation headline: \(ui.value("validation.headline") ?? "nil")")
        XCTAssertTrue((ui.value("validation.detail") ?? "").contains("closed"))
        XCTAssertTrue(ui.exists("validation.testDrive"))
        XCTAssertTrue(ui.exists("validation.done"))
        ui.press("validation.done")
        XCTAssertTrue(waitUntil { self.ui.find("validation.headline", timeout: 0.05) == nil })
    }

    func testStarterCanBeTestDrivenAndReturnsToMenu() {
        show(TrackEditorView())
        ui.press("editor.testDrive")

        guard let config = raceConfig else {
            return XCTFail("Test Drive did not start a race")
        }
        XCTAssertTrue(config.isTestDrive)
        XCTAssertEqual(config.track.name, "My Circuit")
        XCTAssertEqual(config.mode, .quick)

        app.goToMenu()
        XCTAssertEqual(app.route, .menu)
    }

    func testBlankCircuitCanBeExtendedAutoClosedValidatedAndUndone() {
        show(TrackEditorView())

        ui.press("editor.blank")
        XCTAssertTrue(waitUntil { (self.ui.value("editor.summary") ?? "").contains("1 pieces") },
                      "Summary: \(ui.value("editor.summary") ?? "nil")")
        XCTAssertTrue((ui.value("editor.message") ?? "").contains("Blank circuit"))

        ui.press("editor.palette.straightLong")
        XCTAssertTrue(waitUntil { (self.ui.value("editor.summary") ?? "").contains("2 pieces") })
        XCTAssertEqual(ui.isEnabled("editor.undo"), true)

        ui.press("editor.dismissMessage")
        XCTAssertTrue(waitUntil { self.ui.find("editor.message", timeout: 0.05) == nil })

        ui.press("editor.autoClose")
        XCTAssertTrue(waitUntil { self.ui.find("validation.headline", timeout: 0.05) == nil },
                      "Auto Close should succeed without opening the failure sheet")
        XCTAssertTrue((ui.value("editor.message") ?? "").localizedCaseInsensitiveContains("closed"),
                      "Auto Close message: \(ui.value("editor.message") ?? "nil")")

        ui.press("editor.validate")
        XCTAssertTrue(waitUntil { (self.ui.value("validation.headline") ?? "").contains("Circuit Ready") })
        ui.press("validation.done")

        ui.press("editor.undo")
        XCTAssertTrue(waitUntil { (self.ui.value("editor.summary") ?? "").contains("2 pieces") })
        ui.press("editor.validate")
        XCTAssertTrue(waitUntil { (self.ui.value("validation.headline") ?? "").contains("Circuit Open") })
        ui.press("validation.close")

        XCTAssertEqual(ui.isEnabled("editor.redo"), true)
        ui.press("editor.redo")
        ui.press("editor.validate")
        XCTAssertTrue(waitUntil { (self.ui.value("validation.headline") ?? "").contains("Circuit Ready") })
        ui.press("validation.done")
    }

    func testPieceInspectorEditsAndDeletionUndo() {
        show(TrackEditorView())

        ui.press("editor.piece.0")
        XCTAssertTrue(waitUntil { (self.ui.value("editor.summary") ?? "").contains("5 pieces") })

        XCTAssertTrue(ui.exists("editor.length"))
        ui.press("editor.mirror")
        XCTAssertTrue(waitUntil { self.ui.value("editor.mirrorToggle") == "1" })
        ui.press("editor.mirrorToggle")
        XCTAssertTrue(waitUntil { self.ui.value("editor.mirrorToggle") == "0" })

        ui.press("editor.delete")
        XCTAssertTrue(waitUntil { (self.ui.value("editor.summary") ?? "").contains("4 pieces") },
                      "Summary after delete: \(ui.value("editor.summary") ?? "nil")")

        ui.press("editor.undo")
        XCTAssertTrue(waitUntil { (self.ui.value("editor.summary") ?? "").contains("5 pieces") })
    }

    func testTrackNameEnvironmentAndLibrarySave() {
        show(TrackEditorView())

        ui.setText("editor.name", to: "UI Test Circuit")
        XCTAssertEqual(ui.value("editor.name") ?? "", "UI Test Circuit")

        ui.pressOption(in: "editor.environment", label: "Night Race")

        ui.press("editor.saveCustom")
        XCTAssertTrue(waitUntil { self.app.customTracks.contains(where: { $0.name == "UI Test Circuit" }) },
                      "Custom track was not saved")
        XCTAssertEqual(app.customTracks.first(where: { $0.name == "UI Test Circuit" })?.environment, .night)
        XCTAssertTrue((ui.value("editor.message") ?? "").contains("Saved"))
    }

    func testPasteJSONImportsAndReportsInvalidData() {
        show(TrackEditorView())

        let json = (try? saveStore.encodeTrack(TrackCatalog.harborHairpins))
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""

        ui.press("editor.pasteJSON")
        XCTAssertTrue(ui.exists("editor.paste.text"))
        XCTAssertTrue(ui.exists("editor.paste.clear"))
        XCTAssertTrue(ui.exists("editor.paste.load"))
        ui.pasteText("editor.paste.text", json)
        ui.press("editor.paste.load")

        XCTAssertTrue(waitUntil { (self.ui.value("editor.name") ?? "") == "Harbor Hairpins" },
                      "Pasted name: \(ui.value("editor.name") ?? "nil")")
        XCTAssertTrue((ui.value("editor.summary") ?? "").contains("pieces"))

        ui.press("editor.pasteJSON")
        ui.pasteText("editor.paste.text", "not a track")
        ui.press("editor.paste.load")
        XCTAssertTrue(waitUntil { (self.ui.value("editor.message") ?? "").count > 0 },
                      "Invalid JSON did not surface a message")
        XCTAssertEqual(ui.value("editor.name") ?? "", "Harbor Hairpins")
    }

    func testBackReturnsToMenu() {
        show(TrackEditorView())
        ui.press("editor.back")
        XCTAssertEqual(app.route, .menu)
    }
}
