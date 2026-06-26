import XCTest
@testable import ApexSlotRacing

final class CloudAIServiceTests: XCTestCase {
    private func telemetry() -> CloudAITelemetry {
        CloudAITelemetry(sessionId: "test",
                         trackId: "sunset_speedway",
                         difficulty: "medium",
                         speed: 5,
                         maxSpeed: 10,
                         opponentGap: 1.2,
                         boostAvailable: false,
                         lookahead: [
                            CloudLookahead(distance: 2,
                                           curvature: 0.01,
                                           surface: "straight",
                                           loop: false)
                         ])
    }

    func testRejectsNonLoopbackHTTP() async {
        let service = CloudAIService()
        let connection = await service.testConnection(endpoint: "http://example.com/v1/drive")
        let response = await service.predict(endpoint: "file:///tmp/drive",
                                             telemetry: telemetry())
        XCTAssertFalse(connection)
        XCTAssertNil(response)
    }

    func testUnavailableEndpointFallsBackPromptly() async {
        let service = CloudAIService()
        let start = Date()
        let response = await service.predict(endpoint: "http://127.0.0.1:9/v1/drive",
                                             telemetry: telemetry())
        XCTAssertNil(response)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }
}
