import XCTest
import simd
@testable import ApexSlotRacing

final class SerializationTests: XCTestCase {
    func testTrackJSONRoundTripPreservesLayout() throws {
        let store = SaveStore(rootURL: try TestSupport.temporaryDirectory())
        var original = TrackCatalog.starterLayout()
        original.name = "Test Grand Tour"
        original.environment = .night
        original.createdAt = Date(timeIntervalSince1970: 100_000)
        original.updatedAt = Date(timeIntervalSince1970: 123_456)

        let data = try store.encodeTrack(original)
        let decoded = try store.decodeTrack(data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.pieces.count, original.pieces.count)
        XCTAssertEqual(decoded.environment, .night)
    }

    func testTrackValidationAcceptsClosedCircuitAndRejectsBadInput() throws {
        let closed = try TrackFileService.validate(data: SaveStore.shared.encodeTrack(TrackCatalog.starterLayout()))
        XCTAssertEqual(closed.name, TrackCatalog.starterLayout().name)

        var open = TrackCatalog.blankLayout()
        open.pieces = [TrackPiece(kind: .startFinish)]
        XCTAssertThrowsError(try TrackFileService.validate(data: SaveStore.shared.encodeTrack(open))) { error in
            guard case TrackCodecError.openCircuit = error else {
                return XCTFail("Expected open circuit, got \(error)")
            }
        }

        var duplicate = TrackCatalog.starterLayout()
        duplicate.pieces.append(TrackPiece(kind: .startFinish))
        XCTAssertThrowsError(try TrackFileService.validate(data: SaveStore.shared.encodeTrack(duplicate))) { error in
            XCTAssertEqual((error as? TrackCodecError)?.errorDescription, TrackCodecError.duplicateStart.errorDescription)
        }

        var unsupported = TrackCatalog.starterLayout()
        unsupported.schemaVersion = 99
        XCTAssertThrowsError(try TrackFileService.validate(data: SaveStore.shared.encodeTrack(unsupported))) { error in
            guard case TrackCodecError.unsupportedSchema(99) = error else {
                return XCTFail("Expected unsupported schema, got \(error)")
            }
        }

        XCTAssertThrowsError(try TrackFileService.validate(data: Data("not json".utf8))) { error in
            guard case TrackCodecError.invalidJSON = error else {
                return XCTFail("Expected invalid JSON, got \(error)")
            }
        }
        XCTAssertThrowsError(try TrackFileService.validate(text: "")) { _ in }
    }

    func testSaveStorePersistsCustomTracksAndProfile() throws {
        let directory = try TestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore(rootURL: directory)

        var track = TrackCatalog.starterLayout()
        track.name = "Saved Customer Circuit"
        store.saveTrack(track)
        var duplicate = track
        duplicate.id = UUID()
        duplicate.name = "Second Circuit"
        store.saveTrack(duplicate)

        let loaded = store.loadCustomTracks()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertTrue(loaded.allSatisfy { !$0.isBuiltIn })
        XCTAssertTrue(loaded.contains(where: { $0.name == "Saved Customer Circuit" }))

        var profile = PlayerProfile.fresh()
        profile.playerName = "Test Driver"
        profile.wins = 3
        profile.unlockedCars.append(CarModelKind.rally.rawValue)
        store.saveProfile(profile)
        XCTAssertEqual(store.loadProfile(), profile)

        store.deleteTrack(id: track.id)
        XCTAssertEqual(store.loadCustomTracks().count, 1)
    }

    func testRaceResultAndConfigurationCodec() throws {
        let result = TestSupport.raceResult(track: TrackCatalog.sunsetSpeedway,
                                            mode: .championship,
                                            playerTime: 42,
                                            rivalTime: 43,
                                            rivalName: "V. Rossi",
                                            context: ChampionshipRaceContext(roundIndex: 0,
                                                                              rivalName: "V. Rossi",
                                                                              rivalColorHex: "#2E7BE8",
                                                                              rivalSkill: 0.9))
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(RaceResult.self, from: data)
        XCTAssertEqual(decoded, result)
        XCTAssertEqual(decoded.mode, .championship)
        XCTAssertEqual(decoded.championshipContext?.rivalSkill, 0.9)
    }

    func testTrackEditorAddsReplacesAndAutoCloses() {
        let model = TrackEditorModel(layout: TrackCatalog.starterLayout())
        XCTAssertTrue(model.isClosed)
        let initialRevision = model.geometryRevision
        model.add(.straightShort)
        XCTAssertGreaterThan(model.geometryRevision, initialRevision)
        XCTAssertFalse(model.isClosed)

        XCTAssertEqual(model.layout.pieces.filter { $0.kind == .startFinish }.count, 1)
        model.add(.startFinish)
        XCTAssertEqual(model.layout.pieces.filter { $0.kind == .startFinish }.count, 1)
        XCTAssertTrue(model.messageIsError)

        let selectedID = model.layout.pieces.last?.id
        model.select(model.layout.pieces.last!)
        model.replaceSelected(with: .straightLong)
        XCTAssertEqual(model.layout.pieces.last?.id, selectedID)
        XCTAssertEqual(model.layout.pieces.last?.kind, .straightLong)
        XCTAssertTrue(model.canUndo)
        model.undo()
        XCTAssertEqual(model.layout.pieces.last?.kind, .straightShort)

        let open = TrackLayout(name: "Auto Close Test", pieces: [
            TrackPiece(kind: .startFinish, length: 6),
            TrackPiece(kind: .curveWide180, radius: 3),
            TrackPiece(kind: .straightLong, length: 8),
            TrackPiece(kind: .curveWide180, radius: 3)
        ])
        let closer = TrackEditorModel(layout: open)
        XCTAssertFalse(closer.isClosed)
        closer.autoClose()
        XCTAssertTrue(closer.built.isClosed, closer.message ?? "")
        XCTAssertLessThan(closer.built.closureError, 0.22)

        closer.loadStarter()
        XCTAssertTrue(closer.isClosed)
        closer.loadBlank()
        XCTAssertFalse(closer.isClosed)
    }

    func testAutoCloseRoutesDanglingStraightBackToStart() {
        let model = TrackEditorModel(layout: TrackCatalog.starterLayout())
        model.add(.straightLong)

        XCTAssertFalse(model.isClosed)
        let pieceCount = model.layout.pieces.count
        model.autoClose()

        XCTAssertTrue(model.isClosed, model.message ?? "")
        XCTAssertFalse(model.messageIsError, model.message ?? "")
        XCTAssertGreaterThan(model.layout.pieces.count, pieceCount)
        XCTAssertTrue(model.layout.pieces.contains { $0.kind == .closureArc })
        XCTAssertLessThan(model.built.closureError, 0.22)
        XCTAssertTrue(model.canUndo)

        model.undo()
        XCTAssertFalse(model.isClosed)
        XCTAssertEqual(model.layout.pieces.count, pieceCount)
        XCTAssertTrue(model.canRedo)
        model.redo()
        XCTAssertTrue(model.isClosed)
    }

    func testAutoCloseHandlesVariedOpenLayouts() {
        let layouts: [(String, [TrackPiece])] = [
            ("Straight", [TrackPiece(kind: .startFinish, length: 8)]),
            ("Long tail", [TrackPiece(kind: .startFinish, length: 6), TrackPiece(kind: .straightLong, length: 10)]),
            ("Single bend", [TrackPiece(kind: .startFinish, length: 6), TrackPiece(kind: .curveWide90, radius: 3)]),
            ("Hairpin", [TrackPiece(kind: .startFinish, length: 6), TrackPiece(kind: .curveWide180, radius: 3)]),
            ("Chicane", [TrackPiece(kind: .startFinish, length: 6), TrackPiece(kind: .chicane, length: 5)]),
            ("Bridge", [TrackPiece(kind: .startFinish, length: 6), TrackPiece(kind: .bridge, length: 8)]),
            ("Loop", [TrackPiece(kind: .startFinish, length: 6), TrackPiece(kind: .loop360, length: 4)]),
            ("Compound", [
                TrackPiece(kind: .startFinish, length: 6),
                TrackPiece(kind: .curveSharp90, radius: 2),
                TrackPiece(kind: .straightLong, length: 7),
                TrackPiece(kind: .curve45, radius: 3)
            ])
        ]

        for (name, pieces) in layouts {
            let model = TrackEditorModel(layout: TrackLayout(name: name, pieces: pieces))
            XCTAssertFalse(model.isClosed, "\(name) should start open")
            model.autoClose()
            XCTAssertTrue(model.isClosed, "\(name): \(model.message ?? "no message")")
            XCTAssertFalse(model.messageIsError, "\(name): \(model.message ?? "no message")")
            XCTAssertLessThan(model.built.closureError, 0.22, name)
            for lane in model.built.lanePaths {
                let lapStart = lane.pose(at: 0).position
                let lapEnd = lane.pose(at: lane.length).position
                XCTAssertLessThan(simd_distance(lapStart, lapEnd), 0.01, name)
            }
        }
    }

    func testAutoCloseConnectorRoundTripsThroughJSON() throws {
        let model = TrackEditorModel(layout: TrackCatalog.starterLayout())
        model.add(.straightLong)
        model.autoClose()
        XCTAssertTrue(model.isClosed, model.message ?? "")

        model.layout.createdAt = Date(timeIntervalSince1970: 100_000)
        model.layout.updatedAt = Date(timeIntervalSince1970: 123_456)
        let store = SaveStore(rootURL: try TestSupport.temporaryDirectory())
        let data = try store.encodeTrack(model.layout)
        let decoded = try store.decodeTrack(data)
        XCTAssertEqual(decoded, model.layout)
        XCTAssertTrue(TrackPathBuilder.build(decoded).isClosed)
    }

    func testValidationReportExplainsOpenAndReadyCircuits() {
        let ready = TrackEditorModel(layout: TrackCatalog.starterLayout())
        XCTAssertTrue(ready.validationReport().isReady)
        XCTAssertTrue(ready.validationReport().issues.isEmpty)

        let open = TrackEditorModel(layout: TrackLayout(name: "Open", pieces: [
            TrackPiece(kind: .startFinish, length: 8),
            TrackPiece(kind: .curveWide90, radius: 3)
        ]))
        let report = open.validationReport()
        XCTAssertFalse(report.isReady)
        XCTAssertFalse(report.issues.isEmpty)
        XCTAssertFalse(report.suggestions.isEmpty)
        XCTAssertTrue(report.detail.contains("open"))
    }
}
