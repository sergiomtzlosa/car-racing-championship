import SwiftUI
import XCTest
@testable import ApexSlotRacing

@MainActor
final class GarageUITests: ApexUITestCase {
    func testGarageExposesControlsAndDraftDoesNotPersistBeforeSave() {
        show(GarageView())

        for identifier in ["garage.back",
                           "garage.autoRotate",
                           "garage.model.gt",
                           "garage.model.rally",
                           "garage.model.formula",
                           "garage.paint.E83B2F",
                           "garage.paint.2E7BE8",
                           "garage.primaryColor",
                           "garage.secondaryColor",
                           "garage.wheel.0",
                           "garage.wheel.1",
                           "garage.wheel.2",
                           "garage.decal.0",
                           "garage.decal.1",
                           "garage.randomize",
                           "garage.save"] {
            XCTAssertTrue(ui.exists(identifier), "Missing \(identifier)")
        }

        let original = app.profile.carConfig
        ui.press("garage.paint.2E7BE8")
        XCTAssertTrue(waitUntil { self.ui.text(containing: "UNSAVED CHANGES") != nil })
        XCTAssertEqual(app.profile.carConfig.primaryHex, original.primaryHex,
                       "Paint must remain a draft until Save Configuration")

        ui.press("garage.save")
        XCTAssertEqual(app.profile.carConfig.primaryHex, "#2E7BE8")
        XCTAssertTrue(waitUntil { self.ui.text(containing: "UNSAVED CHANGES") == nil })
    }

    func testLockedCarsUnlockAndSaveWithWheelDecalAndModelChanges() {
        show(GarageView())

        XCTAssertEqual(ui.isEnabled("garage.model.rally"), false)
        XCTAssertEqual(ui.isEnabled("garage.model.formula"), false)
        XCTAssertEqual(ui.isEnabled("garage.decal.1"), false)

        app.unlockAll()
        XCTAssertTrue(waitUntil { self.ui.isEnabled("garage.model.rally") == true })
        XCTAssertTrue(waitUntil { self.ui.isEnabled("garage.decal.1") == true })

        ui.press("garage.model.rally")
        ui.press("garage.wheel.2")
        ui.press("garage.decal.1")
        ui.press("garage.save")

        XCTAssertEqual(app.profile.carConfig.model, .rally)
        XCTAssertEqual(app.profile.carConfig.wheelStyle, 2)
        XCTAssertEqual(app.profile.carConfig.decalStyle, 1)
    }

    func testRandomizeAndTurntableToggleAndBack() {
        show(GarageView())

        let initialLabel = ui.label("garage.autoRotate") ?? ""
        ui.press("garage.autoRotate")
        XCTAssertNotEqual(ui.label("garage.autoRotate") ?? "", initialLabel)

        ui.press("garage.randomize")
        XCTAssertTrue(ui.exists("garage.save"))

        ui.press("garage.back")
        XCTAssertEqual(app.route, .menu)
    }
}
