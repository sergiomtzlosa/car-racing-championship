import AppKit
import SwiftUI
import XCTest
@testable import ApexSlotRacing

/// Renders every app screen (plus the editor validation sheet and race
/// overlays) at the two supported audit sizes. Screenshots are attached to the
/// test result; set APEX_WRITE_UI_AUDIT=0 to skip writing them to /tmp.
@MainActor
final class UIScreenSnapshotTests: ApexUITestCase {
    func testEveryScreenRendersAtAuditedSizes() throws {
        try snap(MainMenuView(), name: "menu")
        try snap(HelpView(), name: "help")

        app.openQuickSetup()
        try snap(RaceSetupView(mode: .quick), name: "quick-setup")

        app.openPursuitSetup()
        try snap(RaceSetupView(mode: .pursuit), name: "pursuit-setup")

        app.openGarage()
        try snap(GarageView(), name: "garage")

        app.openEditor()
        try snap(TrackEditorView(), name: "editor")

        let readyModel = TrackEditorModel(layout: TrackCatalog.starterLayout())
        try snap(TrackValidationSheet(model: readyModel, onClose: {}, onTestDrive: {}),
                 name: "validation-ready",
                 sizes: [NSSize(width: 590, height: 430)])

        let openLayout = TrackLayout(name: "Open Circuit",
                                     pieces: [TrackPiece(kind: .startFinish, length: 6),
                                              TrackPiece(kind: .straightShort, length: 4)])
        let openModel = TrackEditorModel(layout: openLayout)
        try snap(TrackValidationSheet(model: openModel, onClose: {}, onTestDrive: {}),
                 name: "validation-open",
                 sizes: [NSSize(width: 590, height: 430)])

        app.openSettings()
        try snap(SettingsView(), name: "settings")

        app.openGameCenter()
        try snap(GameCenterView(), name: "game-center")

        try snap(ChampionshipView(), name: "championship-setup")
        app.startChampionship(fieldSize: 6, difficulty: .medium)
        try snap(ChampionshipView(), name: "championship-active")
        completeChampionship()
        XCTAssertEqual(app.championship?.completed, true)
        app.openChampionship()
        try snap(ChampionshipView(), name: "championship-complete")

        let track = TrackCatalog.sunsetSpeedway
        let config = TestSupport.config(track: track, mode: .quick, laps: 3)
        app.startQuickRace(track: track,
                           car: .standard(for: .gt),
                           difficulty: .medium,
                           laps: 3,
                           environment: .dusk)
        let result = TestSupport.raceResult(track: track,
                                            mode: .quick,
                                            playerTime: 42.5,
                                            rivalTime: 43.1,
                                            rivalName: "V. Rossi")
        app.finishRace(result, config: config)
        try snap(ResultsView(result: app.lastRaceResult ?? result), name: "results")

        let session = RaceSession(settings: .default)
        try snap(ZStack { Color.black; RaceHUD(config: config, session: session) },
                 name: "race-hud")

        let pursuitConfig = TestSupport.config(track: TrackCatalog.loop360, mode: .pursuit, laps: 3)
        let pursuitSession = RaceSession(settings: .default)
        try snap(ZStack { Color.black; RaceHUD(config: pursuitConfig, session: pursuitSession) },
                 name: "pursuit-hud")

        let pauseSession = RaceSession(settings: .default)
        pauseSession.togglePause()
        try snap(ZStack {
            Color(hex: "#161B22")
            RacePauseOverlay(config: config, session: pauseSession, onQuit: {})
        }, name: "pause-overlay")

        let finishSession = RaceSession(settings: .default)
        finishSession.finish(result)
        try snap(ZStack {
            Color(hex: "#161B22")
            RaceFinishOverlay(config: config,
                              result: result,
                              session: finishSession,
                              onComplete: { _ in },
                              onQuit: {})
        }, name: "finish-overlay")
    }

    private func completeChampionship() {
        for _ in 0..<4 {
            guard let season = app.championship,
                  let config = ChampionshipDirector.makeRaceConfig(state: season,
                                                                  playerCar: app.profile.carConfig),
                  let context = config.championshipContext else {
                return XCTFail("Could not prepare championship round")
            }
            let result = TestSupport.raceResult(track: config.track,
                                                mode: .championship,
                                                playerTime: 40,
                                                rivalTime: 50,
                                                rivalName: context.rivalName,
                                                playerPosition: 1,
                                                rivalPosition: 2,
                                                context: context)
            app.finishRace(result, config: config)
        }
    }

    private func snap<V: View>(_ view: V,
                               name: String,
                               sizes: [NSSize] = [NSSize(width: 1440, height: 900),
                                                  NSSize(width: 1180, height: 760)]) throws {
        for size in sizes {
            let host = NSHostingView(rootView: view
                .environmentObject(app)
                .preferredColorScheme(.dark)
                .frame(width: size.width, height: size.height))
            host.appearance = NSAppearance(named: .darkAqua)
            host.frame = NSRect(origin: .zero, size: size)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.20))
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                return XCTFail("Could not create bitmap for \(name) at \(Int(size.width)) px")
            }
            host.cacheDisplay(in: host.bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else {
                return XCTFail("Could not encode PNG for \(name) at \(Int(size.width)) px")
            }
            XCTAssertGreaterThan(rep.pixelsWide, 100, "\(name) width")
            XCTAssertGreaterThan(rep.pixelsHigh, 100, "\(name) height")
            XCTAssertGreaterThan(png.count, 8_000, "\(name) produced an unexpectedly small image")

            let colors = sampledColorCount(rep)
            XCTAssertGreaterThan(colors, 8, "\(name) at \(Int(size.width)) appears blank")

            let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            attachment.name = "\(name)-\(Int(size.width))x\(Int(size.height))"
            attachment.lifetime = .keepAlways
            add(attachment)

            if ProcessInfo.processInfo.environment["APEX_WRITE_UI_AUDIT"] != "0" {
                let suffix = size.width == 1440 ? "" : "-\(Int(size.width))"
                let path = "/tmp/apex-ui-audit-\(name)\(suffix).png"
                try png.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
    }

    private func sampledColorCount(_ rep: NSBitmapImageRep) -> Int {
        guard let data = rep.bitmapData else { return 0 }
        let samplesWide = min(rep.pixelsWide, 48)
        let samplesHigh = min(rep.pixelsHigh, 30)
        var colors = Set<UInt32>()
        for y in stride(from: 0, to: rep.pixelsHigh, by: max(1, rep.pixelsHigh / samplesHigh)) {
            for x in stride(from: 0, to: rep.pixelsWide, by: max(1, rep.pixelsWide / samplesWide)) {
                let offset = y * rep.bytesPerRow + x * max(1, rep.bitsPerPixel / 8)
                let value = data[offset]
                let value2 = data[offset + min(1, rep.bitsPerPixel / 8 - 1)]
                let value3 = data[offset + min(2, rep.bitsPerPixel / 8 - 1)]
                colors.insert(UInt32(value) << 16 | UInt32(value2) << 8 | UInt32(value3))
            }
        }
        return colors.count
    }
}
