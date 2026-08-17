import XCTest
@testable import ApexSlotRacing

final class CloudAIConfigurationTests: XCTestCase {
    private let settingsKey = "apexSlotRacing.settings.v1"

    func testLegacySettingsDecodeWithNewDefaults() throws {
        let legacy = """
        {
          "masterVolume": 0.4,
          "musicVolume": 0.2,
          "sfxVolume": 0.3,
          "engineVolume": 0.1,
          "graphicsQuality": "low",
          "defaultCamera": "topDown",
          "cloudAIEnabled": true,
          "cloudAIURL": "https://example.com/v1/drive",
          "reduceMotion": true,
          "showFPS": true
        }
        """
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(legacy.utf8))
        XCTAssertEqual(settings.masterVolume, 0.4, accuracy: 0.0001)
        XCTAssertEqual(settings.musicVolume, 0.2, accuracy: 0.0001)
        XCTAssertEqual(settings.sfxVolume, 0.3, accuracy: 0.0001)
        XCTAssertEqual(settings.engineVolume, 0.1, accuracy: 0.0001)
        XCTAssertEqual(settings.graphicsQuality, .low)
        XCTAssertEqual(settings.defaultCamera, .topDown)
        XCTAssertTrue(settings.cloudAIEnabled)
        XCTAssertEqual(settings.cloudAIURL, "https://example.com/v1/drive")
        XCTAssertTrue(settings.reduceMotion)
        XCTAssertTrue(settings.showFPS)

        XCTAssertEqual(settings.cloudAIProvider, .direct)
        XCTAssertEqual(settings.cloudAIModel, CloudAIProvider.openAI.defaultModel)
        XCTAssertEqual(settings.cloudAIToken, "")
    }

    func testTokenIsExcludedFromPersistedSettings() throws {
        var settings = AppSettings()
        settings.cloudAIProvider = .openAI
        settings.cloudAIURL = CloudAIModelPresets.openCodeEndpoint
        settings.cloudAIModel = "deepseek-v4.1-flash-free"
        settings.cloudAIToken = "sk-super-secret-token"

        let data = try JSONEncoder().encode(settings)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("sk-super-secret-token"))
        XCTAssertFalse(text.contains("cloudAIToken"))

        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.cloudAIProvider, .openAI)
        XCTAssertEqual(decoded.cloudAIURL, CloudAIModelPresets.openCodeEndpoint)
        XCTAssertEqual(decoded.cloudAIModel, "deepseek-v4.1-flash-free")
        XCTAssertEqual(decoded.cloudAIToken, "")
    }

    func testProviderDefaultsAndOpenCodePresets() {
        XCTAssertEqual(CloudAIProvider.direct.defaultURL, "http://127.0.0.1:8787/v1/drive")
        XCTAssertEqual(CloudAIProvider.openAI.defaultURL, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(CloudAIProvider.openAI.defaultModel, "gpt-4o-mini")
        XCTAssertEqual(CloudAIModelPresets.openCodeEndpoint,
                       "https://opencode.ai/inference/openai/v1/chat/completions")
        XCTAssertEqual(CloudAIModelPresets.localMock.endpoint,
                       "http://127.0.0.1:8787/v1/chat/completions")

        let models = Set(CloudAIModelPresets.openCodeFreeModels.map(\.model))
        for expected in ["deepseek-v4.1-flash-free",
                         "glm-5.3-flash-free",
                         "mimo-v2.6-flash-free",
                         "big-pickle",
                         "iceman-free",
                         "beam-free"] {
            XCTAssertTrue(models.contains(expected), "Missing OpenCode free model \(expected)")
        }
        XCTAssertTrue(CloudAIModelPresets.openCodeFreeModels.allSatisfy {
            $0.endpoint == CloudAIModelPresets.openCodeEndpoint
        })
    }

    func testConfigurationReadsSettingsFields() {
        var settings = AppSettings()
        settings.cloudAIProvider = .openAI
        settings.cloudAIURL = "https://api.example/v1/chat/completions"
        settings.cloudAIModel = "model-x"
        settings.cloudAIToken = "  token-y  "
        let configuration = CloudAIConfiguration(settings: settings)
        XCTAssertEqual(configuration.provider, .openAI)
        XCTAssertEqual(configuration.endpoint, "https://api.example/v1/chat/completions")
        XCTAssertEqual(configuration.model, "model-x")
        XCTAssertEqual(configuration.trimmedToken, "token-y")
    }

    func testInMemoryTokenStoreRoundTrip() {
        let store = InMemoryCloudAITokenStore()
        XCTAssertEqual(store.loadToken(), "")
        XCTAssertTrue(store.saveToken("  first-token \n"))
        XCTAssertEqual(store.loadToken(), "first-token")
        XCTAssertTrue(store.saveToken("second-token"))
        XCTAssertEqual(store.loadToken(), "second-token")
        store.deleteToken()
        XCTAssertEqual(store.loadToken(), "")
    }

    @MainActor
    func testAppModelPersistsTokenOutsideSettingsAndClearsItOnReset() throws {
        let key = settingsKey
        let backup = UserDefaults.standard.data(forKey: key)
        defer {
            if let backup {
                UserDefaults.standard.set(backup, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.removeObject(forKey: key)

        let directory = try TestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let tokenStore = InMemoryCloudAITokenStore(token: "existing-token")
        let app = AppModel(saveStore: SaveStore(rootURL: directory),
                           authenticateGameCenter: false,
                           cloudTokenStore: tokenStore)
        XCTAssertEqual(app.settings.cloudAIToken, "existing-token")

        var updated = app.settings
        updated.cloudAIToken = "new-secret-token"
        app.updateSettings(updated)
        XCTAssertEqual(tokenStore.loadToken(), "new-secret-token")
        XCTAssertEqual(app.settings.cloudAIToken, "new-secret-token")

        let persisted = try XCTUnwrap(UserDefaults.standard.data(forKey: key))
        let persistedText = String(decoding: persisted, as: UTF8.self)
        XCTAssertFalse(persistedText.contains("new-secret-token"))
        XCTAssertFalse(persistedText.contains("cloudAIToken"))

        app.resetAllData()
        XCTAssertEqual(tokenStore.loadToken(), "")
        XCTAssertEqual(app.settings.cloudAIToken, "")
    }
}
