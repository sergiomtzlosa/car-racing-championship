import Foundation
import simd

struct TrackClosurePlan {
    var pieces: [TrackPiece]
    var length: Float
    var arcCount: Int
    var straightCount: Int

    var summary: String {
        if straightCount == 1, arcCount == 0 {
            return String(format: "Auto-closed with a %.1f unit straight.", length)
        }
        return String(format: "Auto-closed with %d link piece%@ (%.1f units).",
                      pieces.count,
                      pieces.count == 1 ? "" : "s",
                      length)
    }
}

/// Builds a flat connector from the end of the current piece chain back to the
/// start/finish pose. A left-left or right-right two-arc route keeps the exit
/// tangent continuous and closes the loop without snapping the car sideways.
enum TrackClosurePlanner {
    private static let minimumRadius: Float = 1.9
    private static let maximumRadius: Float = 3.4
    private static let maximumGap: Float = 60
    private static let maximumRouteLength: Float = 180

    static func plan(from end: TrackFrame, to start: TrackFrame) -> TrackClosurePlan? {
        guard isFlat(end), isFlat(start),
              abs(end.position.y - start.position.y) < 0.06 else {
            return nil
        }

        let dx = start.position.x - end.position.x
        let dz = start.position.z - end.position.z
        let gap = sqrt(dx * dx + dz * dz)
        guard gap > 0.12, gap < maximumGap else { return nil }

        let rawRadius = min(maximumRadius, max(minimumRadius, gap * 0.32))
        let radius = (rawRadius * 10).rounded() / 10
        let startHeading = atan2(end.forward.z, end.forward.x)
        let goalHeading = atan2(start.forward.z, start.forward.x)

        let candidates = [
            route(side: 1, radius: radius, startHeading: startHeading, goalHeading: goalHeading, end: end, start: start),
            route(side: -1, radius: radius, startHeading: startHeading, goalHeading: goalHeading, end: end, start: start)
        ].compactMap { $0 }

        return candidates
            .filter { $0.length > 0.1 && $0.length <= maximumRouteLength }
            .min(by: { $0.length < $1.length })
    }

    private static func route(side: Float,
                              radius: Float,
                              startHeading: Float,
                              goalHeading: Float,
                              end: TrackFrame,
                              start: TrackFrame) -> TrackClosurePlan? {
        let leftX = -sin(startHeading)
        let leftZ = cos(startHeading)
        let endCenter = SIMD2<Float>(
            end.position.x + side * leftX * radius,
            end.position.z + side * leftZ * radius
        )

        let goalLeftX = -sin(goalHeading)
        let goalLeftZ = cos(goalHeading)
        let startCenter = SIMD2<Float>(
            start.position.x + side * goalLeftX * radius,
            start.position.z + side * goalLeftZ * radius
        )

        let delta = startCenter - endCenter
        let centerDistance = simd_length(delta)
        guard centerDistance > 0.001 else { return nil }

        let tangentHeading = atan2(delta.y, delta.x)
        let firstArc: Float
        let secondArc: Float
        if side > 0 {
            firstArc = positiveAngle(tangentHeading - startHeading)
            secondArc = positiveAngle(goalHeading - tangentHeading)
        } else {
            firstArc = positiveAngle(startHeading - tangentHeading)
            secondArc = positiveAngle(tangentHeading - goalHeading)
        }

        var pieces: [TrackPiece] = []
        var arcCount = 0
        var straightCount = 0

        if firstArc > 0.001 {
            pieces.append(TrackPiece(kind: .closureArc,
                                     radius: radius,
                                     mirrored: side < 0,
                                     arcSweep: roundedArc(firstArc)))
            arcCount += 1
        }

        if centerDistance > 0.02 {
            let kind: TrackPieceKind = centerDistance >= 6 ? .straightLong : .straightShort
            pieces.append(TrackPiece(kind: kind, length: centerDistance))
            straightCount += 1
        }

        if secondArc > 0.001 {
            pieces.append(TrackPiece(kind: .closureArc,
                                     radius: radius,
                                     mirrored: side < 0,
                                     arcSweep: roundedArc(secondArc)))
            arcCount += 1
        }

        guard !pieces.isEmpty else { return nil }
        let length = (firstArc + secondArc) * radius + centerDistance
        return TrackClosurePlan(pieces: pieces,
                                length: length,
                                arcCount: arcCount,
                                straightCount: straightCount)
    }

    private static func isFlat(_ frame: TrackFrame) -> Bool {
        abs(frame.up.y - 1) < 0.02 && abs(frame.forward.y) < 0.02
    }

    private static func positiveAngle(_ angle: Float) -> Float {
        let value = angle.truncatingRemainder(dividingBy: 2 * .pi)
        return value < 0 ? value + 2 * .pi : value
    }

    private static func roundedArc(_ angle: Float) -> Float {
        (angle * 100_000).rounded() / 100_000
    }
}
