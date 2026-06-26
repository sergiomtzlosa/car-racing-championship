import XCTest
import simd
@testable import ApexSlotRacing

final class TrackPathTests: XCTestCase {
    func testAllBuiltInTracksAreClosedAndRaceable() {
        XCTAssertEqual(TrackCatalog.builtIn.count, 4)
        for track in TrackCatalog.builtIn {
            let built = TrackPathBuilder.build(track)
            XCTAssertTrue(built.isClosed, "\(track.name) should be closed (gap \(built.closureError))")
            XCTAssertLessThan(built.closureError, 0.22, track.name)
            XCTAssertGreaterThan(built.length, 20, track.name)
            XCTAssertEqual(built.layout.pieces.filter { $0.kind == .startFinish }.count, 1, track.name)
            XCTAssertEqual(built.centerFrames.count > 100, true, track.name)
            XCTAssertEqual(built.lanePaths.count, 2, track.name)
            XCTAssertEqual(built.validationMessage, "Circuit ready.", track.name)
        }
    }

    func testLanePathsAreContinuousAndFramesAreOrthonormal() {
        for track in TrackCatalog.builtIn {
            let built = TrackPathBuilder.build(track)
            for lane in built.lanePaths {
                XCTAssertGreaterThan(lane.length, 20, track.name)
                XCTAssertEqual(lane.frames.count, lane.cumulative.count, track.name)
                XCTAssertEqual(lane.frames.count, built.centerFrames.count, track.name)
                var previousPosition: SIMD3<Float>?
                for (index, frame) in lane.frames.enumerated() {
                    XCTAssertTrue(frame.position.x.isFinite)
                    XCTAssertTrue(frame.position.y.isFinite)
                    XCTAssertTrue(frame.position.z.isFinite)
                    XCTAssertEqual(simd_length(frame.forward), 1, accuracy: 0.002, "\(track.name) frame \(index)")
                    XCTAssertEqual(simd_length(frame.up), 1, accuracy: 0.002, "\(track.name) frame \(index)")
                    XCTAssertEqual(simd_length(frame.left), 1, accuracy: 0.002, "\(track.name) frame \(index)")
                    XCTAssertEqual(simd_dot(frame.forward, frame.up), 0, accuracy: 0.002)
                    XCTAssertEqual(simd_dot(frame.forward, frame.left), 0, accuracy: 0.002)
                    if let previousPosition {
                        let gap = simd_distance(previousPosition, frame.position)
                        XCTAssertLessThan(gap, 0.25, "\(track.name) frame \(index) teleports")
                    }
                    previousPosition = frame.position
                }
                XCTAssertEqual(lane.cumulative.last ?? 0, lane.length, accuracy: 0.01)
            }
        }
    }

    func testPoseSamplingWrapsAtLapBoundary() {
        let built = TrackPathBuilder.build(TrackCatalog.sunsetSpeedway)
        let lane = built.lanePaths[0]
        let atZero = lane.pose(at: 0)
        let atLap = lane.pose(at: lane.length)
        XCTAssertLessThan(simd_distance(atZero.position, atLap.position), 0.001)
        XCTAssertEqual(atLap.s, 0, accuracy: 0.001)
        XCTAssertLessThan(abs(lane.pose(at: -0.4).s - (lane.length - 0.4)), 0.01)
    }

    func testLoopFramesRotateContinuously() {
        let built = TrackPathBuilder.build(TrackCatalog.loop360)
        let loopFrames = built.centerFrames.filter { $0.kind == .loop360 }
        XCTAssertGreaterThan(loopFrames.count, 60)
        XCTAssertGreaterThan(loopFrames.map(\.position.y).max() ?? 0, 2.0)
        for index in 1..<loopFrames.count {
            let previous = loopFrames[index - 1]
            let current = loopFrames[index]
            XCTAssertGreaterThan(simd_dot(previous.forward, current.forward), 0.90, "loop forward flipped at \(index)")
            XCTAssertGreaterThan(simd_dot(previous.up, current.up), 0.90, "loop up flipped at \(index)")
        }
    }

    func testBridgeRaisesAndReturnsToTableHeight() {
        let built = TrackPathBuilder.build(TrackCatalog.nightGrandPrix)
        let bridgeFrames = built.centerFrames.filter { $0.kind == .bridge }
        XCTAssertGreaterThan(bridgeFrames.count, 30)
        XCTAssertGreaterThan(bridgeFrames.map(\.position.y).max() ?? 0, 1.2)
        guard let first = bridgeFrames.first, let last = bridgeFrames.last else {
            return XCTFail("No bridge frames")
        }
        XCTAssertLessThan(first.position.y, 0.02)
        XCTAssertLessThan(last.position.y, 0.02)
        XCTAssertEqual(last.forward.y, 0, accuracy: 0.001)
        XCTAssertEqual(last.up.y, 1, accuracy: 0.001)
    }

    func testCrossoverSwapsLaneOffsetsContinuously() {
        let built = TrackPathBuilder.build(TrackCatalog.harborHairpins)
        let centers = built.centerFrames.filter { $0.kind == .crossover }
        XCTAssertGreaterThan(centers.count, 5)
        guard let firstCenter = centers.first, let lastCenter = centers.last else {
            return XCTFail("No crossover centerline")
        }

        for lane in built.lanePaths {
            let frames = lane.frames.filter { $0.kind == .crossover }
            guard let first = frames.first, let last = frames.last else {
                return XCTFail("No crossover lane")
            }
            let startOffset = simd_dot(first.position - firstCenter.position, firstCenter.left)
            let endOffset = simd_dot(last.position - lastCenter.position, lastCenter.left)
            if lane.laneIndex == 0 {
                XCTAssertGreaterThan(startOffset, 0.15)
                XCTAssertLessThan(endOffset, -0.15)
            } else {
                XCTAssertLessThan(startOffset, -0.15)
                XCTAssertGreaterThan(endOffset, 0.15)
            }
        }

        let lane0 = built.lanePaths[0]
        for index in 1..<lane0.frames.count {
            let gap = simd_distance(lane0.frames[index - 1].position, lane0.frames[index].position)
            XCTAssertLessThan(gap, 0.25)
        }
    }

    func testStarterAndBlankLayoutsBuild() {
        let starter = TrackPathBuilder.build(TrackCatalog.starterLayout())
        XCTAssertTrue(starter.isClosed)
        XCTAssertEqual(starter.lanePaths.count, 2)

        let blank = TrackPathBuilder.build(TrackCatalog.blankLayout())
        XCTAssertFalse(blank.isClosed)
        XCTAssertFalse(blank.centerFrames.isEmpty)
        XCTAssertTrue(blank.validationMessage.contains("open"))
    }
}
