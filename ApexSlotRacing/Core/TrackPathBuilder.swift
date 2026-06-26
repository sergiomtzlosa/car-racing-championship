import Foundation
import simd

enum TrackPathBuilder {
    static let sampleSpacing: Float = 0.055
    static let laneHalfSpacing: Float = 0.62

    private struct LocalSample {
        var position: SIMD3<Float>
        var forward: SIMD3<Float>
        var up: SIMD3<Float>
        var left: SIMD3<Float>
        var t: Float
    }

    private struct WorldRigidFrame {
        var position: SIMD3<Float>
        var forward: SIMD3<Float>
        var up: SIMD3<Float>
        var left: SIMD3<Float>
    }

    static func build(_ layout: TrackLayout) -> BuiltTrack {
        var centerFrames: [TrackFrame] = []
        var pieceRanges: [Range<Float>] = []
        var current = WorldRigidFrame(
            position: SIMD3<Float>(0, 0, 0),
            forward: SIMD3<Float>(1, 0, 0),
            up: SIMD3<Float>(0, 1, 0),
            left: SIMD3<Float>(0, 0, 1)
        )
        let startPosition = current.position
        let startForward = current.forward
        var total: Float = 0
        var startFrame = TrackFrame(
            s: 0,
            position: current.position,
            forward: current.forward,
            up: current.up,
            left: current.left,
            curvature: 0,
            pieceIndex: 0,
            pieceT: 0,
            kind: layout.pieces.first?.kind ?? .straightLong
        )

        for (pieceIndex, piece) in layout.pieces.enumerated() {
            let localSamples = makeLocalSamples(for: piece)
            let pieceStart = total
            var appendedForPiece = false

            for (sampleIndex, sample) in localSamples.enumerated() {
                let worldPosition = current.position
                    + current.forward * sample.position.x
                    + current.up * sample.position.y
                    + current.left * sample.position.z

                if let last = centerFrames.last,
                   sampleIndex == 0,
                   simd_distance(worldPosition, last.position) < 0.0005 {
                    continue
                }

                if !centerFrames.isEmpty {
                    if let last = centerFrames.last {
                        total += simd_distance(worldPosition, last.position)
                    }
                }

                let worldForward = simd_normalize(
                    current.forward * sample.forward.x
                    + current.up * sample.forward.y
                    + current.left * sample.forward.z
                )
                var worldUp = simd_normalize(
                    current.forward * sample.up.x
                    + current.up * sample.up.y
                    + current.left * sample.up.z
                )
                var worldLeft = simd_normalize(
                    current.forward * sample.left.x
                    + current.up * sample.left.y
                    + current.left * sample.left.z
                )

                // Re-orthogonalize to avoid accumulation drift.
                worldLeft = simd_normalize(worldLeft - worldForward * simd_dot(worldLeft, worldForward))
                worldUp = simd_normalize(simd_cross(worldLeft, worldForward))

                if centerFrames.isEmpty {
                    startFrame = TrackFrame(
                        s: 0,
                        position: worldPosition,
                        forward: worldForward,
                        up: worldUp,
                        left: worldLeft,
                        curvature: 0,
                        pieceIndex: pieceIndex,
                        pieceT: sample.t,
                        kind: piece.kind
                    )
                }

                centerFrames.append(
                    TrackFrame(
                        s: total,
                        position: worldPosition,
                        forward: worldForward,
                        up: worldUp,
                        left: worldLeft,
                        curvature: 0,
                        pieceIndex: pieceIndex,
                        pieceT: sample.t,
                        kind: piece.kind
                    )
                )
                appendedForPiece = true
            }

            if let last = localSamples.last {
                let worldPosition = current.position
                    + current.forward * last.position.x
                    + current.up * last.position.y
                    + current.left * last.position.z
                let worldForward = simd_normalize(
                    current.forward * last.forward.x
                    + current.up * last.forward.y
                    + current.left * last.forward.z
                )
                var worldUp = simd_normalize(
                    current.forward * last.up.x
                    + current.up * last.up.y
                    + current.left * last.up.z
                )
                var worldLeft = simd_normalize(
                    current.forward * last.left.x
                    + current.up * last.left.y
                    + current.left * last.left.z
                )
                worldLeft = simd_normalize(worldLeft - worldForward * simd_dot(worldLeft, worldForward))
                worldUp = simd_normalize(simd_cross(worldLeft, worldForward))
                current = WorldRigidFrame(
                    position: worldPosition,
                    forward: worldForward,
                    up: worldUp,
                    left: worldLeft
                )
            }

            pieceRanges.append(pieceStart..<total)
            _ = appendedForPiece
        }

        if centerFrames.isEmpty {
            return emptyTrack(layout: layout)
        }

        // Curvature is computed on the centreline.  Loops are handled by the
        // loop threshold in the vehicle controller, not by lateral grip.
        for index in centerFrames.indices {
            let previous = centerFrames[max(0, index - 1)]
            let next = centerFrames[min(centerFrames.count - 1, index + 1)]
            let ds = max(0.0001, next.s - previous.s)
            let angle = acos(max(-1, min(1, simd_dot(previous.forward, next.forward))))
            // A bridge's ramp bends vertically, not laterally. Cornering grip
            // must not treat that rise as a hairpin. The same applies to the
            // vertical loop, which is governed by its own minimum-speed rule.
            let kind = centerFrames[index].kind
            centerFrames[index].curvature = (kind.isLoop || kind == .bridge) ? 0 : angle / ds
        }

        let endPosition = current.position
        let closureError = simd_distance(startPosition, endPosition)
        let headingDot = simd_dot(startForward, current.forward)
        let isClosed = closureError < 0.22 && headingDot > 0.995

        var lanePaths: [LanePath] = []
        for laneIndex in 0..<max(2, layout.laneCount) {
            lanePaths.append(makeLanePath(centerFrames: centerFrames,
                                          laneIndex: laneIndex,
                                          layout: layout,
                                          closed: isClosed))
        }

        var boundsMin = centerFrames[0].position
        var boundsMax = centerFrames[0].position
        for frame in centerFrames {
            boundsMin = simd_min(boundsMin, frame.position)
            boundsMax = simd_max(boundsMax, frame.position)
        }
        for lane in lanePaths {
            for frame in lane.frames {
                boundsMin = simd_min(boundsMin, frame.position)
                boundsMax = simd_max(boundsMax, frame.position)
            }
        }

        return BuiltTrack(
            layout: layout,
            centerFrames: centerFrames,
            lanePaths: lanePaths,
            isClosed: isClosed,
            closureError: closureError,
            closureHeadingDot: headingDot,
            boundsMin: boundsMin,
            boundsMax: boundsMax,
            length: total,
            pieceRanges: pieceRanges,
            startFrame: startFrame
        )
    }

    private static func makeLanePath(centerFrames: [TrackFrame],
                                     laneIndex: Int,
                                     layout: TrackLayout,
                                     closed: Bool) -> LanePath {
        var frames: [TrackFrame] = []
        var cumulative: [Float] = []
        var pieceStarts: [Int: Float] = [:]
        var total: Float = 0
        var side: Float = laneIndex == 0 ? 1 : -1
        var previousPiece = -1

        for center in centerFrames {
            if center.pieceIndex != previousPiece {
                if previousPiece >= 0,
                   previousPiece < layout.pieces.count,
                   layout.pieces[previousPiece].kind == .crossover {
                    side = -side
                }
                previousPiece = center.pieceIndex
                pieceStarts[center.pieceIndex] = total
            }

            var offset = side * laneHalfSpacing
            if center.kind == .crossover {
                let blend = smootherstep(center.pieceT)
                offset = side * laneHalfSpacing * (1 - 2 * blend)
            }

            let position = center.position + center.left * offset
            if !frames.isEmpty {
                total += simd_distance(position, frames[frames.count - 1].position)
            }
            var frame = center
            frame.position = position
            frame.s = total
            frames.append(frame)
            cumulative.append(total)
        }

        let length = total
        return LanePath(laneIndex: laneIndex,
                        frames: frames,
                        cumulative: cumulative,
                        length: length,
                        pieceStartDistances: pieceStarts)
    }

    private static func emptyTrack(layout: TrackLayout) -> BuiltTrack {
        let start = TrackFrame(
            s: 0,
            position: SIMD3<Float>(0, 0, 0),
            forward: SIMD3<Float>(1, 0, 0),
            up: SIMD3<Float>(0, 1, 0),
            left: SIMD3<Float>(0, 0, 1),
            curvature: 0,
            pieceIndex: 0,
            pieceT: 0,
            kind: .straightLong
        )
        return BuiltTrack(
            layout: layout,
            centerFrames: [start],
            lanePaths: [],
            isClosed: false,
            closureError: 0,
            closureHeadingDot: 0,
            boundsMin: SIMD3<Float>(0, 0, 0),
            boundsMax: SIMD3<Float>(0, 0, 0),
            length: 0,
            pieceRanges: [],
            startFrame: start
        )
    }

    // MARK: - Local piece geometry

    private static func makeLocalSamples(for piece: TrackPiece) -> [LocalSample] {
        switch piece.kind {
        case .startFinish, .straightLong, .straightShort:
            return straightSamples(length: piece.effectiveLength)
        case .curveSharp90:
            return curveSamples(radius: piece.effectiveRadius, sweep: .pi / 2, mirrored: piece.mirrored)
        case .curveWide90:
            return curveSamples(radius: piece.effectiveRadius, sweep: .pi / 2, mirrored: piece.mirrored)
        case .curveWide180:
            return curveSamples(radius: piece.effectiveRadius, sweep: .pi, mirrored: piece.mirrored)
        case .curve45:
            return curveSamples(radius: piece.effectiveRadius, sweep: .pi / 4, mirrored: piece.mirrored)
        case .closureArc:
            return curveSamples(radius: piece.effectiveRadius,
                                sweep: min(2 * .pi, max(0.001, piece.effectiveArcSweep)),
                                mirrored: piece.mirrored)
        case .chicane:
            return chicaneSamples(length: piece.effectiveLength, amplitude: 1.05, mirrored: piece.mirrored)
        case .crossover:
            return straightSamples(length: piece.effectiveLength)
        case .bridge:
            return bridgeSamples(length: piece.effectiveLength, height: 1.55)
        case .loop360:
            return loopSamples(length: piece.effectiveLength, radius: 1.25)
        }
    }

    private static func straightSamples(length: Float) -> [LocalSample] {
        let count = max(3, Int(length / sampleSpacing) + 1)
        var samples: [LocalSample] = []
        samples.reserveCapacity(count)
        for index in 0..<count {
            let t = Float(index) / Float(count - 1)
            samples.append(LocalSample(
                position: SIMD3<Float>(length * t, 0, 0),
                forward: SIMD3<Float>(1, 0, 0),
                up: SIMD3<Float>(0, 1, 0),
                left: SIMD3<Float>(0, 0, 1),
                t: t
            ))
        }
        return samples
    }

    private static func curveSamples(radius: Float, sweep: Float, mirrored: Bool) -> [LocalSample] {
        let arcLength = radius * sweep
        let count = max(6, Int(arcLength / sampleSpacing) + 1)
        let sign: Float = mirrored ? -1 : 1
        var samples: [LocalSample] = []
        samples.reserveCapacity(count)
        for index in 0..<count {
            let t = Float(index) / Float(count - 1)
            let theta = -Float.pi / 2 + sweep * t
            let position = SIMD3<Float>(
                radius * cos(theta),
                0,
                sign * (radius + radius * sin(theta))
            )
            let tangent = simd_normalize(SIMD3<Float>(
                -sin(theta),
                0,
                sign * cos(theta)
            ))
            let up = SIMD3<Float>(0, 1, 0)
            let left = simd_normalize(simd_cross(tangent, up))
            samples.append(LocalSample(
                position: position,
                forward: tangent,
                up: up,
                left: left,
                t: t
            ))
        }
        return samples
    }

    private static func chicaneSamples(length: Float, amplitude: Float, mirrored: Bool) -> [LocalSample] {
        let count = max(8, Int(length / sampleSpacing) + 1)
        let sign: Float = mirrored ? -1 : 1
        var samples: [LocalSample] = []
        samples.reserveCapacity(count)
        for index in 0..<count {
            let t = Float(index) / Float(count - 1)
            let z = sign * amplitude * pow(sin(Float.pi * t), 2)
            let dzdt = sign * amplitude * Float.pi * sin(2 * Float.pi * t)
            let position = SIMD3<Float>(length * t, 0, z)
            let tangent = simd_normalize(SIMD3<Float>(length, 0, dzdt))
            let up = SIMD3<Float>(0, 1, 0)
            let left = simd_normalize(simd_cross(tangent, up))
            samples.append(LocalSample(
                position: position,
                forward: tangent,
                up: up,
                left: left,
                t: t
            ))
        }
        return samples
    }

    private static func bridgeSamples(length: Float, height: Float) -> [LocalSample] {
        let count = max(10, Int(length / sampleSpacing) + 1)
        let ramp: Float = 0.2
        var samples: [LocalSample] = []
        samples.reserveCapacity(count)

        func profile(_ t: Float) -> Float {
            if t < ramp {
                return height * smoothstep(t / ramp)
            } else if t > 1 - ramp {
                return height * smoothstep((1 - t) / ramp)
            }
            return height
        }

        for index in 0..<count {
            let t = Float(index) / Float(count - 1)
            let x = length * t
            let y = profile(t)
            let dt: Float = 1.0 / Float(max(1, count - 1))
            // The smoothstep ramps have a zero slope at both ends. Use the
            // analytic endpoint slope instead of a one-sided finite difference
            // so the bridge exit frame is truly flat and the next piece starts
            // level with the table.
            let dy: Float
            if t <= 0 || t >= 1 {
                dy = 0
            } else {
                let yPrev = profile(t - dt)
                let yNext = profile(t + dt)
                dy = (yNext - yPrev) / (2 * dt)
            }
            let tangent = simd_normalize(SIMD3<Float>(length, dy, 0))
            let left = SIMD3<Float>(0, 0, 1)
            let up = simd_normalize(simd_cross(left, tangent))
            samples.append(LocalSample(
                position: SIMD3<Float>(x, y, 0),
                forward: tangent,
                up: up,
                left: left,
                t: t
            ))
        }
        return samples
    }

    private static func loopSamples(length: Float, radius: Float) -> [LocalSample] {
        let entry = max(0.8, length * 0.25)
        let exit = max(0.8, length - entry)
        let loopLength = 2 * Float.pi * radius
        let straightCount = max(3, Int((entry + exit) / sampleSpacing))
        let loopCount = max(20, Int(loopLength / 0.07))
        var samples: [LocalSample] = []
        samples.reserveCapacity(straightCount + loopCount)
        let totalApprox = entry + exit + loopLength
        var travelled: Float = 0

        for index in 0..<straightCount {
            let t = Float(index) / Float(max(1, straightCount - 1))
            let x = entry * t
            travelled = entry * t
            samples.append(LocalSample(
                position: SIMD3<Float>(x, 0, 0),
                forward: SIMD3<Float>(1, 0, 0),
                up: SIMD3<Float>(0, 1, 0),
                left: SIMD3<Float>(0, 0, 1),
                t: travelled / totalApprox
            ))
        }

        for index in 0..<loopCount {
            let t = Float(index) / Float(max(1, loopCount - 1))
            let theta = -Float.pi / 2 + 2 * Float.pi * t
            let position = SIMD3<Float>(
                entry + radius * cos(theta),
                radius + radius * sin(theta),
                0
            )
            let tangent = simd_normalize(SIMD3<Float>(-sin(theta), cos(theta), 0))
            let left = SIMD3<Float>(0, 0, 1)
            let up = simd_normalize(simd_cross(left, tangent))
            travelled = entry + loopLength * t
            samples.append(LocalSample(
                position: position,
                forward: tangent,
                up: up,
                left: left,
                t: travelled / totalApprox
            ))
        }

        for index in 1...straightCount {
            let t = Float(index) / Float(max(1, straightCount - 1))
            let x = entry + exit * t
            travelled = entry + loopLength + exit * t
            samples.append(LocalSample(
                position: SIMD3<Float>(x, 0, 0),
                forward: SIMD3<Float>(1, 0, 0),
                up: SIMD3<Float>(0, 1, 0),
                left: SIMD3<Float>(0, 0, 1),
                t: travelled / totalApprox
            ))
        }

        return samples
    }

    private static func smoothstep(_ value: Float) -> Float {
        let t = max(0, min(1, value))
        return t * t * (3 - 2 * t)
    }

    private static func smootherstep(_ value: Float) -> Float {
        let t = max(0, min(1, value))
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
}
