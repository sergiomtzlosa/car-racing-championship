import XCTest
@testable import ApexSlotRacing

final class CloudAIControlTests: XCTestCase {
    func testCloudControlHonoursProviderMaximumAge() {
        let simulation = TestSupport.makeSimulation()
        XCTAssertTrue(TestSupport.startRace(simulation))
        XCTAssertEqual(simulation.aiMode, "LOCAL AI")

        simulation.setCloudControl(throttle: 0.9, brake: 0, maxAge: 10)
        TestSupport.step(simulation, seconds: 0.1)
        XCTAssertEqual(simulation.aiMode, "CLOUD AI")

        // A zero maximum age expires immediately, so the local driver resumes.
        simulation.setCloudControl(throttle: 0.9, brake: 0, maxAge: 0)
        TestSupport.step(simulation, seconds: 0.1)
        XCTAssertEqual(simulation.aiMode, "LOCAL AI")
    }

    func testClearingCloudControlRestoresLocalAI() {
        let simulation = TestSupport.makeSimulation()
        XCTAssertTrue(TestSupport.startRace(simulation))

        simulation.setCloudControl(throttle: 0.7, brake: 0, maxAge: 10)
        TestSupport.step(simulation, seconds: 0.1)
        XCTAssertEqual(simulation.aiMode, "CLOUD AI")

        simulation.setCloudControl(throttle: nil, brake: nil)
        XCTAssertEqual(simulation.aiMode, "LOCAL AI")
        TestSupport.step(simulation, seconds: 0.1)
        XCTAssertEqual(simulation.aiMode, "LOCAL AI")
    }

    func testProviderTuningCoversSlowChatModels() {
        XCTAssertGreaterThan(CloudAIProvider.openAI.requestTimeout,
                             CloudAIProvider.direct.requestTimeout)
        XCTAssertGreaterThan(CloudAIProvider.openAI.pollIntervalNanoseconds,
                             CloudAIProvider.direct.pollIntervalNanoseconds)
        XCTAssertGreaterThan(CloudAIProvider.openAI.cloudControlMaximumAge,
                             CloudAIProvider.direct.cloudControlMaximumAge)
        XCTAssertGreaterThan(CloudAIProvider.openAI.cloudControlMaximumAge,
                             CloudAIProvider.openAI.requestTimeout)
    }
}
