import Foundation

enum TrackCatalog {
    static let sunsetID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let harborID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let loopID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let nightID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

    private static func date(_ value: TimeInterval) -> Date { Date(timeIntervalSince1970: value) }

    static let sunsetSpeedway: TrackLayout = {
        var track = TrackLayout(
            id: sunsetID,
            name: "Sunset Speedway",
            pieces: [
                TrackPiece(kind: .startFinish, length: 6),
                TrackPiece(kind: .chicane, length: 4),
                TrackPiece(kind: .curveWide180, radius: 3.5),
                TrackPiece(kind: .straightLong, length: 10),
                TrackPiece(kind: .curveWide180, radius: 3.5)
            ],
            environment: .dusk,
            isBuiltIn: true
        )
        track.createdAt = date(1000)
        track.updatedAt = date(1000)
        return track
    }()

    static let harborHairpins: TrackLayout = {
        var track = TrackLayout(
            id: harborID,
            name: "Harbor Hairpins",
            pieces: [
                TrackPiece(kind: .startFinish, length: 6),
                TrackPiece(kind: .curveSharp90, radius: 1.9),
                TrackPiece(kind: .crossover, length: 4),
                TrackPiece(kind: .curveSharp90, radius: 1.9),
                TrackPiece(kind: .straightLong, length: 6),
                TrackPiece(kind: .curveSharp90, radius: 1.9),
                TrackPiece(kind: .chicane, length: 4),
                TrackPiece(kind: .curveSharp90, radius: 1.9)
            ],
            environment: .club,
            isBuiltIn: true
        )
        track.createdAt = date(2000)
        track.updatedAt = date(2000)
        return track
    }()

    static let loop360: TrackLayout = {
        var track = TrackLayout(
            id: loopID,
            name: "Loop 360",
            pieces: [
                TrackPiece(kind: .startFinish, length: 6),
                TrackPiece(kind: .curveSharp90, radius: 2.0),
                TrackPiece(kind: .loop360, length: 4),
                TrackPiece(kind: .curveSharp90, radius: 2.0),
                TrackPiece(kind: .bridge, length: 6),
                TrackPiece(kind: .curveSharp90, radius: 2.0),
                TrackPiece(kind: .straightShort, length: 4),
                TrackPiece(kind: .curveSharp90, radius: 2.0)
            ],
            environment: .dusk,
            isBuiltIn: true
        )
        track.createdAt = date(3000)
        track.updatedAt = date(3000)
        return track
    }()

    static let nightGrandPrix: TrackLayout = {
        var track = TrackLayout(
            id: nightID,
            name: "Night Grand Prix",
            pieces: [
                TrackPiece(kind: .startFinish, length: 6),
                TrackPiece(kind: .chicane, length: 4),
                TrackPiece(kind: .curveWide90, radius: 3.0),
                TrackPiece(kind: .straightShort, length: 4),
                TrackPiece(kind: .curveWide90, radius: 3.0),
                TrackPiece(kind: .bridge, length: 10),
                TrackPiece(kind: .curveWide90, radius: 3.0),
                TrackPiece(kind: .crossover, length: 4),
                TrackPiece(kind: .curveWide90, radius: 3.0)
            ],
            environment: .night,
            isBuiltIn: true
        )
        track.createdAt = date(4000)
        track.updatedAt = date(4000)
        return track
    }()

    static let builtIn: [TrackLayout] = [
        sunsetSpeedway,
        harborHairpins,
        loop360,
        nightGrandPrix
    ]

    static func layout(for id: UUID, custom: [TrackLayout]) -> TrackLayout? {
        builtIn.first(where: { $0.id == id }) ?? custom.first(where: { $0.id == id })
    }

    static func starterLayout() -> TrackLayout {
        var track = TrackLayout(
            name: "My Circuit",
            pieces: [
                TrackPiece(kind: .startFinish, length: 6),
                TrackPiece(kind: .chicane, length: 4),
                TrackPiece(kind: .curveWide180, radius: 3.5),
                TrackPiece(kind: .straightLong, length: 10),
                TrackPiece(kind: .curveWide180, radius: 3.5)
            ],
            environment: .club,
            isBuiltIn: false
        )
        track.createdAt = Date()
        track.updatedAt = Date()
        return track
    }

    static func blankLayout() -> TrackLayout {
        TrackLayout(
            name: "New Circuit",
            pieces: [TrackPiece(kind: .startFinish, length: 8)],
            environment: .club,
            isBuiltIn: false
        )
    }
}
