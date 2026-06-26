import Foundation
import simd

struct TrackFrame {
    var s: Float
    var position: SIMD3<Float>
    var forward: SIMD3<Float>
    var up: SIMD3<Float>
    var left: SIMD3<Float>
    var curvature: Float
    var pieceIndex: Int
    var pieceT: Float
    var kind: TrackPieceKind

    // The path builder stores the horizontal basis vector using the historical
    // name `left`, but cross(forward, up) points to the car's right side.
    // Keep that storage convention and build a proper right-handed body frame:
    // local +X = right side, +Y = up, -Z = forward.
    var right: SIMD3<Float> { left }

    var orientation: simd_quatf {
        let matrix = simd_float3x3(columns: (left, up, -forward))
        return simd_quatf(matrix)
    }

    var pose: TrackPose {
        TrackPose(
            position: position,
            orientation: orientation,
            forward: forward,
            up: up,
            left: -left,
            s: s,
            curvature: curvature,
            pieceIndex: pieceIndex,
            pieceT: pieceT,
            kind: kind
        )
    }
}

struct TrackPose {
    var position: SIMD3<Float>
    var orientation: simd_quatf
    var forward: SIMD3<Float>
    var up: SIMD3<Float>
    var left: SIMD3<Float>
    var s: Float
    var curvature: Float
    var pieceIndex: Int
    var pieceT: Float
    var kind: TrackPieceKind

    var right: SIMD3<Float> { -left }

    var carMatrix: simd_float4x4 {
        simd_matrix4x4(orientation)
    }
}

struct LanePath {
    var laneIndex: Int
    var frames: [TrackFrame]
    var cumulative: [Float]
    var length: Float
    var pieceStartDistances: [Int: Float]

    func normalizedDistance(_ distance: Float) -> Float {
        guard length > 0 else { return 0 }
        var value = distance.truncatingRemainder(dividingBy: length)
        if value < 0 { value += length }
        return value
    }

    func pose(at distance: Float) -> TrackPose {
        guard !frames.isEmpty else {
            return TrackPose(
                position: SIMD3<Float>(0, 0, 0),
                orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
                forward: SIMD3<Float>(1, 0, 0),
                up: SIMD3<Float>(0, 1, 0),
                left: SIMD3<Float>(0, 0, 1),
                s: 0,
                curvature: 0,
                pieceIndex: 0,
                pieceT: 0,
                kind: .straightLong
            )
        }

        let target = normalizedDistance(distance)
        let index = max(0, min(frames.count - 1, insertionIndex(for: target)))
        let frame = frames[index]
        var result = frame.pose
        result.s = target

        if frames.count > 1, index < frames.count - 1 {
            let next = frames[index + 1]
            let span = max(0.0001, next.s - frame.s)
            let t = max(0, min(1, (target - frame.s) / span))
            if t > 0 {
                result.position = frame.position + (next.position - frame.position) * t
                result.orientation = simd_slerp(frame.orientation, next.orientation, t)
                result.forward = result.orientation.act(SIMD3<Float>(0, 0, -1))
                result.up = result.orientation.act(SIMD3<Float>(0, 1, 0))
                result.left = -result.orientation.act(SIMD3<Float>(1, 0, 0))
                result.curvature = frame.curvature + (next.curvature - frame.curvature) * t
            }
        }
        return result
    }

    func pieceStart(for pieceIndex: Int) -> Float {
        pieceStartDistances[pieceIndex] ?? 0
    }

    func frameIndex(at distance: Float) -> Int {
        guard !frames.isEmpty else { return 0 }
        let target = normalizedDistance(distance)
        return max(0, min(frames.count - 1, insertionIndex(for: target)))
    }

    func frame(at distance: Float) -> TrackFrame? {
        guard !frames.isEmpty else { return nil }
        return frames[frameIndex(at: distance)]
    }

    private func insertionIndex(for distance: Float) -> Int {
        guard cumulative.count > 1 else { return 0 }
        var low = 0
        var high = cumulative.count - 1
        while low < high {
            let mid = (low + high) / 2
            if cumulative[mid] <= distance {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return max(0, low - 1)
    }
}

struct BuiltTrack {
    var layout: TrackLayout
    var centerFrames: [TrackFrame]
    var lanePaths: [LanePath]
    var isClosed: Bool
    var closureError: Float
    var closureHeadingDot: Float
    var boundsMin: SIMD3<Float>
    var boundsMax: SIMD3<Float>
    var length: Float
    var pieceRanges: [Range<Float>]
    var startFrame: TrackFrame

    var center: SIMD3<Float> {
        (boundsMin + boundsMax) * 0.5
    }

    var size: SIMD3<Float> {
        boundsMax - boundsMin
    }

    func lanePath(_ index: Int) -> LanePath? {
        guard !lanePaths.isEmpty else { return nil }
        return lanePaths[max(0, min(lanePaths.count - 1, index))]
    }

    var validationMessage: String {
        if centerFrames.isEmpty { return "Track is empty." }
        if !isClosed {
            return String(format: "Track is open. Gap: %.2f units.", closureError)
        }
        if length < 8 { return "Track is too short." }
        return "Circuit ready."
    }
}
