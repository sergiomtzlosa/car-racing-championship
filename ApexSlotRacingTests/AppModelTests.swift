import XCTest
@testable import ApexSlotRacing

@MainActor
final class AppModelTests: XCTestCase {
    func testRecordingARaceIsIdempotentAndAwardsUnlocksOnce() throws {
        let directory = try TestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppModel(saveStore: SaveStore(rootURL: directory),
                          authenticateGameCenter: false,
                          cloudTokenStore: InMemoryCloudAITokenStore())

        let track = TrackCatalog.sunsetSpeedway
        let config = TestSupport.config(track: track, mode: .quick, laps: 2)
        let raw = TestSupport.raceResult(track: track,
                                         mode: .quick,
                                         playerTime: 40,
                                         rivalTime: 42,
                                         rivalName: "CPU")

        let processed = app.recordRace(raw, config: config)
        XCTAssertEqual(app.profile.races, 1)
        XCTAssertEqual(app.profile.wins, 1)
        XCTAssertEqual(app.profile.podiums, 1)
        XCTAssertTrue(app.profile.isUnlocked(.rally))
        XCTAssertTrue(processed.unlockMessages.contains("80s Rally unlocked"))
        XCTAssertEqual(app.lastRaceResult?.id, raw.id)

        // The finish overlay records immediately; pressing View Results later
        // must not apply the same result twice.
        let again = app.recordRace(raw, config: config)
        XCTAssertEqual(again.id, raw.id)
        XCTAssertEqual(app.profile.races, 1)
        XCTAssertEqual(app.profile.wins, 1)
        XCTAssertEqual(again.unlockMessages.filter { $0 == "80s Rally unlocked" }.count, 1)

        app.finishRace(raw, config: config)
        XCTAssertEqual(app.profile.races, 1)
        XCTAssertEqual(app.lastRaceResult?.id, raw.id)
    }

    func testTestDriveDoesNotChangeCareerStats() throws {
        let directory = try TestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppModel(saveStore: SaveStore(rootURL: directory),
                          authenticateGameCenter: false,
                          cloudTokenStore: InMemoryCloudAITokenStore())

        let track = TrackCatalog.starterLayout()
        let config = RaceConfig(mode: .quick,
                                track: track,
                                playerCar: .standard(for: .gt),
                                opponentCar: .standard(for: .rally),
                                difficulty: .medium,
                                laps: 2,
                                pursuitRole: .pursuer,
                                opponentName: "CPU",
                                championshipContext: nil,
                                isTestDrive: true)
        let raw = TestSupport.raceResult(track: track,
                                         mode: .quick,
                                         playerTime: 40,
                                         rivalTime: 42,
                                         rivalName: "CPU")

        app.recordRace(raw, config: config)
        XCTAssertEqual(app.profile.races, 0)
        XCTAssertEqual(app.profile.wins, 0)
        XCTAssertEqual(app.lastRaceResult?.id, raw.id)
    }
}
