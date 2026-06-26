import XCTest
import simd
@testable import ApexSlotRacing

final class PhysicsTests: XCTestCase {
    func testThrottleAcceleratesAndBrakeDecelerates() {
        let simulation = TestSupport.makeSimulation(laps: 3)
        XCTAssertTrue(TestSupport.startRace(simulation))
        guard let player = simulation.cars.first(where: { $0.isPlayer }) else {
            return XCTFail("Missing player")
        }

        TestSupport.step(simulation, seconds: 1.0, input: RaceInput(throttle: 1, brake: 0, boost: false))
        let speedAfterThrottle = player.speed
        XCTAssertGreaterThan(speedAfterThrottle, 1.0)
        XCTAssertGreaterThan(player.distance, 0.2)
        XCTAssertGreaterThan(simulation.telemetry(cameraMode: .thirdPerson).throttle, 0.9)

        TestSupport.step(simulation, seconds: 1.0, input: RaceInput(throttle: 0, brake: 1, boost: false))
        XCTAssertLessThan(player.speed, speedAfterThrottle)
        XCTAssertGreaterThanOrEqual(player.speed, 0)
    }

    func testCountdownLocksCarAndPausePreservesPhase() {
        let simulation = TestSupport.makeSimulation()
        let player = simulation.cars.first(where: { $0.isPlayer })!
        XCTAssertEqual(simulation.phase, .countdown)
        TestSupport.step(simulation, seconds: 1.0, input: RaceInput(throttle: 1, brake: 0, boost: false))
        XCTAssertEqual(player.speed, 0)
        XCTAssertEqual(player.distance, 0)

        simulation.setPaused(true)
        let pausedCountdown = simulation.countdown
        TestSupport.step(simulation, seconds: 1.0, input: RaceInput(throttle: 1, brake: 0, boost: false))
        XCTAssertEqual(simulation.phase, .paused)
        XCTAssertEqual(simulation.countdown, pausedCountdown, accuracy: 0.0001)
        simulation.setPaused(false)
        XCTAssertEqual(simulation.phase, .countdown)

        XCTAssertTrue(TestSupport.startRace(simulation))
        simulation.setPaused(true)
        TestSupport.step(simulation, seconds: 0.5)
        XCTAssertEqual(simulation.phase, .paused)
        simulation.setPaused(false)
        XCTAssertEqual(simulation.phase, .racing)
    }

    func testCornerOverSpeedTriggersDeslotAndPenalty() {
        let built = TrackPathBuilder.build(TrackCatalog.harborHairpins)
        let simulation = RaceSimulation(builtTrack: built, config: TestSupport.config(track: TrackCatalog.harborHairpins))
        XCTAssertTrue(TestSupport.startRace(simulation))
        let player = simulation.cars.first(where: { $0.isPlayer })!
        let lane = player.lanePath
        guard let curve = lane.frames.first(where: { !$0.kind.isLoop && $0.curvature > 0.12 }) else {
            return XCTFail("No curve frame")
        }

        player.distance = curve.s + 0.1
        player.speed = 14
        simulation.update(dt: 1.0 / 120.0, input: RaceInput(throttle: 1, brake: 0, boost: false))
        XCTAssertEqual(player.state, .deslot)
        XCTAssertEqual(player.deslots, 1)
        XCTAssertEqual(player.penalty, 3.0, accuracy: 0.05)
        XCTAssertEqual(player.speed, 0)

        TestSupport.step(simulation, seconds: 3.1)
        XCTAssertEqual(player.state, .running)
        XCTAssertEqual(player.penalty, 0, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(player.distance, 0)
    }

    func testLoopEntryBelowMinimumSpeedFails() {
        let built = TrackPathBuilder.build(TrackCatalog.loop360)
        let simulation = RaceSimulation(builtTrack: built, config: TestSupport.config(track: TrackCatalog.loop360))
        XCTAssertTrue(TestSupport.startRace(simulation))
        let player = simulation.cars.first(where: { $0.isPlayer })!
        guard let loopFrame = player.lanePath.frames.first(where: { $0.kind.isLoop }) else {
            return XCTFail("No loop frame")
        }

        player.distance = loopFrame.s + 0.1
        player.speed = 3.0
        player.wasOnLoop = false
        simulation.update(dt: 1.0 / 120.0, input: RaceInput(throttle: 1, brake: 0, boost: false))
        XCTAssertEqual(player.state, .deslot)
        XCTAssertEqual(player.deslots, 1)
    }

    func testLapWrapAndBestLap() {
        let simulation = TestSupport.makeSimulation(laps: 2)
        XCTAssertTrue(TestSupport.startRace(simulation))
        let player = simulation.cars.first(where: { $0.isPlayer })!
        guard let lane = simulation.builtTrack.lanePaths.first else {
            return XCTFail("Missing lane")
        }

        player.distance = lane.length - 0.05
        player.speed = 4
        player.lapStartTime = -2.2
        TestSupport.step(simulation, seconds: 0.2, input: RaceInput(throttle: 1, brake: 0, boost: false))
        XCTAssertGreaterThanOrEqual(player.completedLaps, 1)
        XCTAssertGreaterThan(player.bestLap, 2.0)
        XCTAssertGreaterThan(player.lastLap, 2.0)
        XCTAssertNil(simulation.result)
    }

    func testRaceFinishesAndPublishesResult() {
        let simulation = TestSupport.makeSimulation(laps: 1)
        XCTAssertTrue(TestSupport.startRace(simulation))
        let player = simulation.cars.first(where: { $0.isPlayer })!
        guard let lane = simulation.builtTrack.lanePaths.first else {
            return XCTFail("Missing lane")
        }

        player.distance = lane.length - 0.05
        player.speed = 4
        player.lapStartTime = -2.0
        TestSupport.step(simulation, seconds: 0.2, input: RaceInput(throttle: 1, brake: 0, boost: false))
        XCTAssertEqual(simulation.phase, .finished)
        XCTAssertNotNil(simulation.result)
        XCTAssertTrue(simulation.result?.playerWon ?? false)
        XCTAssertEqual(simulation.result?.cars.first(where: { $0.isPlayer })?.finished, true)
        XCTAssertFalse(simulation.drainEvents().isEmpty)
    }

    func testPursuitGivesFugitiveAThreeSecondHeadStart() {
        var config = TestSupport.config(track: TrackCatalog.sunsetSpeedway, mode: .pursuit, laps: 3)
        config.pursuitRole = .pursuer
        let simulation = RaceSimulation(builtTrack: TrackPathBuilder.build(config.track), config: config)
        XCTAssertTrue(TestSupport.startRace(simulation))
        let player = simulation.cars.first(where: { $0.isPlayer })!
        let rival = simulation.cars.first(where: { !$0.isPlayer })!
        XCTAssertTrue(player.isPursuer)
        XCTAssertEqual(player.startDelay, 3.0, accuracy: 0.001)
        XCTAssertEqual(rival.startDelay, 0, accuracy: 0.001)
        TestSupport.step(simulation, seconds: 0.5)
        XCTAssertEqual(player.distance, 0, accuracy: 0.001)
        XCTAssertGreaterThan(rival.distance, 0.5)
    }

    func testAISpeedProfilesRespectDifficultyAndCurvature() {
        for track in TrackCatalog.builtIn {
            let built = TrackPathBuilder.build(track)
            guard let lane = built.lanePaths.last else { continue }
            let easy = AISpeedProfile(lanePath: lane, stats: CarModelKind.gt.stats, difficulty: .easy)
            let hard = AISpeedProfile(lanePath: lane, stats: CarModelKind.gt.stats, difficulty: .hard)
            XCTAssertEqual(easy.speedLimits.count, lane.frames.count)
            XCTAssertEqual(hard.speedLimits.count, lane.frames.count)
            XCTAssertGreaterThanOrEqual(hard.speedLimits.max() ?? 0, easy.speedLimits.max() ?? 0)

            for frame in lane.frames where frame.kind.isCurve {
                let hardTarget = hard.targetSpeed(at: frame.s)
                let straightTarget = hard.targetSpeed(at: lane.frames.first(where: { !$0.kind.isCurve && !$0.kind.isLoop })?.s ?? 0)
                XCTAssertLessThanOrEqual(hardTarget, straightTarget + 0.75)
                XCTAssertTrue(hardTarget.isFinite)
            }
        }
    }

    func testAICompletesACleanStintOnReferenceTracks() {
        for track in TrackCatalog.builtIn {
            let simulation = TestSupport.makeSimulation(track: track, laps: 3, difficulty: .medium)
            XCTAssertTrue(TestSupport.startRace(simulation))
            let rival = simulation.cars.first(where: { !$0.isPlayer })!
            TestSupport.step(simulation, seconds: 35)
            XCTAssertEqual(rival.deslots, 0, "\(track.name) AI deslotted")
            XCTAssertGreaterThan(rival.completedLaps, 0, "\(track.name) AI did not complete a lap")
        }
    }

    func testSeededSimulationIsDeterministic() {
        let first = TestSupport.makeSimulation(seed: 42)
        let second = TestSupport.makeSimulation(seed: 42)
        XCTAssertTrue(TestSupport.startRace(first))
        XCTAssertTrue(TestSupport.startRace(second))
        TestSupport.step(first, seconds: 5, input: RaceInput(throttle: 0.8, brake: 0, boost: false))
        TestSupport.step(second, seconds: 5, input: RaceInput(throttle: 0.8, brake: 0, boost: false))
        XCTAssertEqual(first.cars[0].distance, second.cars[0].distance, accuracy: 0.0001)
        XCTAssertEqual(first.cars[1].distance, second.cars[1].distance, accuracy: 0.0001)
    }
}
