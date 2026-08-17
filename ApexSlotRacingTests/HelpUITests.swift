import SwiftUI
import XCTest
@testable import ApexSlotRacing

@MainActor
final class HelpUITests: ApexUITestCase {
    func testEveryHelpTopicIsPresentAndNavigates() {
        show(HelpView())

        XCTAssertTrue(ui.exists("help.title"))
        XCTAssertTrue(ui.exists("help.close"))
        for topic in HelpContent.topics {
            XCTAssertTrue(ui.exists("help.topic.\(topic.id)"), "Missing help.topic.\(topic.id)")
        }

        XCTAssertTrue(waitUntil {
            (self.ui.label("help.detail.title") ?? "").contains("Quick Start")
        }, "Quick Start did not appear by default")

        for topic in HelpContent.topics {
            ui.press("help.topic.\(topic.id)")
            XCTAssertTrue(waitUntil {
                (self.ui.label("help.detail.title") ?? "").contains(topic.title)
            }, "Topic \(topic.id) did not become selected")
            XCTAssertNotNil(ui.text(containing: topic.sections[0].title),
                            "Missing first section for \(topic.id)")
        }

        ui.press("help.topic.controls")
        XCTAssertNotNil(ui.text(containing: "Throttle"))
        XCTAssertNotNil(ui.text(containing: "Right trigger") ?? ui.text(containing: "right trigger"))
        XCTAssertTrue((ui.label("help.detail.summary") ?? "").contains("Keyboard") ||
                      (ui.text(containing: "Keyboard") != nil))

        ui.press("help.topic.settings")
        XCTAssertNotNil(ui.text(containing: "Keychain"))
        XCTAssertNotNil(ui.text(containing: "OpenAI"))
    }

    func testCloseActionAndAppWiring() {
        var closes = 0
        show(HelpView(onClose: { closes += 1 }))

        ui.press("help.close")
        XCTAssertEqual(closes, 1)

        var helpRequests = 0
        app.helpPresentation = { helpRequests += 1 }
        app.showHelp()
        XCTAssertEqual(helpRequests, 1)
        ApexMenuCommand.help.perform(on: app)
        XCTAssertEqual(helpRequests, 2)
        app.helpPresentation = nil
    }

    func testHelpWindowControllerRetainsASecondaryWindow() {
        let controller = HelpWindowController.shared
        controller.showHelp()
        defer {
            controller.close()
            ui.showPlaceholder(app: app)
        }

        XCTAssertTrue(controller.window?.isVisible == true)
        XCTAssertEqual(controller.window?.title, "Apex Slot Racing Help")
        XCTAssertNotNil(controller.window?.contentView)
        XCTAssertGreaterThan(controller.window?.contentView?.subviews.count ?? 0, 0)
    }
}
