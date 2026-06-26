import Foundation
import XCTest
@testable import ApexSlotRacing

enum TestSupport {
    static func built(_ track: TrackLayout = TrackCatalog.sunsetSpeedway) -> BuiltTrack {
        TrackPathBuilder.build(track)
    }

    static func config(track: TrackLayout = TrackCatalog.sunsetSpeedway,
                       mode: RaceMode = .quick,
                       laps: Int = 2,
                       difficulty: Difficulty = .medium,
                       rivalName: String = "V. Rossi") -> RaceConfig {
        RaceConfig(mode: mode,
                   track: track,
                   playerCar: .standard(for: .gt),
                   opponentCar: .standard(for: .rally),
                   difficulty: difficulty,
                   laps: laps,
                   pursuitRole: .pursuer,
                   opponentName: rivalName,
                   championshipContext: nil)
    }

    static func makeSimulation(track: TrackLayout = TrackCatalog.sunsetSpeedway,
                               mode: RaceMode = .quick,
                               laps: Int = 2,
                               difficulty: Difficulty = .medium,
                               seed: UInt64 = 0xA9E7) -> RaceSimulation {
        RaceSimulation(builtTrack: built(track),
                       config: config(track: track, mode: mode, laps: laps, difficulty: difficulty),
                       seed: seed)
    }

    @discardableResult
    static func startRace(_ simulation: RaceSimulation) -> Bool {
        let input = RaceInput()
        for _ in 0..<600 where simulation.phase == .countdown {
            simulation.update(dt: 1.0 / 120.0, input: input)
        }
        return simulation.phase == .racing
    }

    static func step(_ simulation: RaceSimulation,
                     seconds: Double,
                     input: RaceInput = RaceInput()) {
        let steps = Int((seconds * 120.0).rounded())
        for _ in 0..<max(0, steps) {
            simulation.update(dt: 1.0 / 120.0, input: input)
        }
    }

    static func carResult(name: String,
                          isPlayer: Bool,
                          position: Int,
                          time: Double,
                          bestLap: Double = 2.4,
                          topSpeed: Double = 280,
                          deslots: Int = 0,
                          laps: Int = 2,
                          model: CarModelKind = .gt,
                          color: String = "#E83B2F") -> CarResult {
        CarResult(id: UUID(),
                  name: name,
                  carModel: model,
                  colorHex: color,
                  isPlayer: isPlayer,
                  position: position,
                  totalTime: time,
                  bestLap: bestLap,
                  averageSpeed: 180,
                  topSpeed: topSpeed,
                  deslots: deslots,
                  completedLaps: laps,
                  finished: true)
    }

    static func raceResult(track: TrackLayout,
                           mode: RaceMode = .championship,
                           playerTime: Double,
                           rivalTime: Double,
                           rivalName: String,
                           playerPosition: Int = 1,
                           rivalPosition: Int = 2,
                           context: ChampionshipRaceContext? = nil) -> RaceResult {
        let player = carResult(name: "Driver",
                               isPlayer: true,
                               position: playerPosition,
                               time: playerTime,
                               bestLap: playerTime / 3.0)
        let rival = carResult(name: rivalName,
                              isPlayer: false,
                              position: rivalPosition,
                              time: rivalTime,
                              bestLap: rivalTime / 3.0,
                              model: .rally,
                              color: "#2E7BE8")
        return RaceResult(id: UUID(),
                          trackID: track.id,
                          trackName: track.name,
                          mode: mode,
                          difficulty: .medium,
                          date: Date(),
                          playerWon: playerPosition == 1,
                          cars: [player, rival],
                          playerBestLap: player.bestLap,
                          playerTopSpeed: 280,
                          playerDeslots: 0,
                          championshipContext: context,
                          unlockMessages: [],
                          achievementMessages: [])
    }

    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexSlotRacingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func assertFinite(_ value: Float, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(value.isFinite, message.isEmpty ? "Expected a finite value" : message, file: file, line: line)
    }
}
