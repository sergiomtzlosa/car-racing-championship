import SwiftUI
import XCTest
@testable import ApexSlotRacing

@MainActor
final class SettingsUITests: ApexUITestCase {
    func testSettingsControlsUpdateState() {
        show(SettingsView())

        for identifier in ["settings.back",
                           "settings.volume.master",
                           "settings.volume.music",
                           "settings.volume.effects",
                           "settings.volume.motor",
                           "settings.mute",
                           "settings.quality",
                           "settings.camera",
                           "settings.showFPS",
                           "settings.reduceMotion",
                           "settings.cloudEnabled",
                           "settings.cloudProvider",
                           "settings.cloudURL",
                           "settings.testCloud",
                           "settings.gameCenterSignIn",
                           "settings.gameCenterDashboard",
                           "settings.unlockAll",
                           "settings.reset"] {
            XCTAssertTrue(ui.exists(identifier), "Missing \(identifier)")
        }

        ui.setSlider("settings.volume.master", to: 0.25)
        XCTAssertTrue(waitUntil { abs(self.app.settings.masterVolume - 0.25) < 0.03 },
                      "Master volume did not update, got \(app.settings.masterVolume)")
        XCTAssertNotNil(ui.text(containing: "25%"))

        ui.setSlider("settings.volume.music", to: 0.35)
        XCTAssertTrue(waitUntil { abs(self.app.settings.musicVolume - 0.35) < 0.03 })
        ui.setSlider("settings.volume.effects", to: 0.45)
        XCTAssertTrue(waitUntil { abs(self.app.settings.sfxVolume - 0.45) < 0.03 })
        ui.setSlider("settings.volume.motor", to: 0.55)
        XCTAssertTrue(waitUntil { abs(self.app.settings.engineVolume - 0.55) < 0.03 })

        ui.press("settings.mute")
        XCTAssertTrue(app.isMuted)
        ui.press("settings.mute")
        XCTAssertFalse(app.isMuted)

        XCTAssertFalse(app.settings.showFPS)
        ui.press("settings.showFPS")
        XCTAssertTrue(app.settings.showFPS)

        XCTAssertFalse(app.settings.reduceMotion)
        ui.press("settings.reduceMotion")
        XCTAssertTrue(app.settings.reduceMotion)

        ui.pressOption(in: "settings.quality", label: "Ultra")
        XCTAssertEqual(app.settings.graphicsQuality, .ultra)

        ui.pressOption(in: "settings.camera", label: "Cockpit")
        XCTAssertEqual(app.settings.defaultCamera, .firstPerson)

        ui.press("settings.unlockAll")
        XCTAssertTrue(app.profile.isUnlocked(.rally))
        XCTAssertTrue(app.profile.isUnlocked(.formula))
        XCTAssertEqual(Set(app.profile.unlockedDecalStyles), Set([0, 1, 2, 3]))
    }

    func testCloudAITestConnectionAndReadiness() {
        show(SettingsView())

        XCTAssertFalse(app.settings.cloudAIEnabled)
        XCTAssertEqual(ui.isEnabled("settings.testCloud"), false)

        ui.press("settings.cloudEnabled")
        XCTAssertTrue(app.settings.cloudAIEnabled)
        XCTAssertTrue(waitUntil { self.ui.isEnabled("settings.testCloud") == true })

        ui.setText("settings.cloudURL", to: "http://127.0.0.1:1/v1/drive")
        XCTAssertEqual(app.settings.cloudAIURL, "http://127.0.0.1:1/v1/drive")

        ui.press("settings.testCloud")
        XCTAssertTrue(waitUntil(timeout: 5) {
            (self.ui.value("settings.cloudStatus") ?? "").contains("NO RESPONSE")
        }, "Cloud test did not fail over, status: \(ui.value("settings.cloudStatus") ?? "nil")")

        ui.press("settings.cloudEnabled")
        XCTAssertFalse(app.settings.cloudAIEnabled)
    }

    func testOpenAICompatibleFieldsPresetsAndTokenStorage() {
        show(SettingsView())

        XCTAssertFalse(app.settings.cloudAIEnabled)
        XCTAssertFalse(ui.exists("settings.cloudToken"))
        XCTAssertFalse(ui.exists("settings.cloudModel"))

        ui.pressOption(in: "settings.cloudProvider", label: "OpenAI-compatible")
        XCTAssertTrue(waitUntil { self.app.settings.cloudAIProvider == .openAI })
        XCTAssertTrue(ui.exists("settings.cloudToken"))
        XCTAssertTrue(ui.exists("settings.cloudModel"))
        XCTAssertEqual(app.settings.cloudAIURL, CloudAIProvider.openAI.defaultURL)

        for identifier in ["settings.preset.opencode",
                           "settings.preset.localMock",
                           "settings.preset.openAI",
                           "settings.cloudModelPresets"] {
            XCTAssertTrue(ui.exists(identifier), "Missing \(identifier)")
        }

        ui.setText("settings.cloudModel", to: "my-model")
        XCTAssertTrue(waitUntil { self.app.settings.cloudAIModel == "my-model" })

        ui.setText("settings.cloudToken", to: "sk-test-token")
        XCTAssertTrue(waitUntil { self.app.settings.cloudAIToken == "sk-test-token" })
        XCTAssertEqual(tokenStore.loadToken(), "sk-test-token")

        ui.press("settings.preset.opencode")
        XCTAssertTrue(waitUntil {
            self.app.settings.cloudAIURL == CloudAIModelPresets.openCodeEndpoint
        })
        XCTAssertEqual(app.settings.cloudAIProvider, .openAI)
        XCTAssertTrue(CloudAIModelPresets.openCodeFreeModels.contains {
            $0.model == self.app.settings.cloudAIModel
        })

        ui.press("settings.preset.localMock")
        XCTAssertTrue(waitUntil {
            self.app.settings.cloudAIURL == CloudAIModelPresets.localMock.endpoint
        })
        XCTAssertEqual(app.settings.cloudAIModel, CloudAIModelPresets.localMock.model)

        ui.pressOption(in: "settings.cloudProvider", label: "Direct JSON")
        XCTAssertTrue(waitUntil { self.app.settings.cloudAIProvider == .direct })
        XCTAssertEqual(app.settings.cloudAIURL, CloudAIProvider.direct.defaultURL)
    }

    func testOpenAITestConnectionFailsOverPromptly() {
        show(SettingsView())

        ui.press("settings.cloudEnabled")
        ui.pressOption(in: "settings.cloudProvider", label: "OpenAI-compatible")
        XCTAssertTrue(waitUntil { self.app.settings.cloudAIProvider == .openAI })

        ui.setText("settings.cloudURL", to: "http://127.0.0.1:1/v1/chat/completions")
        ui.setText("settings.cloudModel", to: "mock-model")
        ui.press("settings.testCloud")
        XCTAssertTrue(waitUntil(timeout: 5) {
            (self.ui.value("settings.cloudStatus") ?? "").contains("NO RESPONSE")
        }, "OpenAI cloud test did not fail over, status: \(ui.value("settings.cloudStatus") ?? "nil")")
    }

    func testResetAlertCanCancelThenResetEverything() {
        app.unlockAll()
        app.startChampionship(fieldSize: 4, difficulty: .medium)
        show(SettingsView())

        ui.press("settings.reset")
        XCTAssertTrue(ui.pressButton(label: "Cancel"))
        XCTAssertNotNil(app.championship)
        XCTAssertTrue(app.profile.isUnlocked(.formula))

        ui.press("settings.reset")
        XCTAssertTrue(ui.pressButton(label: "Reset Everything"))
        XCTAssertNil(app.championship)
        XCTAssertFalse(app.profile.isUnlocked(.rally))
        XCTAssertFalse(app.profile.isUnlocked(.formula))
        XCTAssertEqual(app.route, .menu)
    }

    func testBackButtonReturnsToMenu() {
        show(SettingsView())
        ui.press("settings.back")
        XCTAssertEqual(app.route, .menu)
    }
}
