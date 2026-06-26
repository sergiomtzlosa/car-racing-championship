import Foundation

enum ChampionshipDirector {
    static let pointsTable = [10, 6, 4, 2]

    private static let rivalNames = [
        "V. Rossi", "K. Tanaka", "M. Okafor", "L. Novak",
        "S. Vidal", "R. Lindqvist", "A. Moreau", "J. Park"
    ]

    private static let rivalColors = [
        "#2E7BE8", "#2FB37A", "#E0B32A", "#9D5BE8",
        "#E85D93", "#37B9D8", "#E07828", "#C9D2DC"
    ]

    static func newSeason(profile: PlayerProfile, fieldSize: Int, difficulty: Difficulty) -> ChampionshipState {
        let field = max(2, min(8, fieldSize))
        let tracks = TrackCatalog.builtIn
        let player = ChampionshipEntrant(
            id: UUID(),
            name: profile.playerName.isEmpty ? "YOU" : profile.playerName,
            colorHex: profile.carConfig.primaryHex,
            carModel: profile.carConfig.model,
            skill: 1.0,
            isPlayer: true
        )

        var entrants: [ChampionshipEntrant] = [player]
        let baseSkill: Float
        switch difficulty {
        case .easy: baseSkill = 0.82
        case .medium: baseSkill = 0.90
        case .hard: baseSkill = 0.95
        }
        let models = CarModelKind.allCases
        for index in 0..<(field - 1) {
            entrants.append(
                ChampionshipEntrant(
                    id: UUID(),
                    name: rivalNames[index % rivalNames.count],
                    colorHex: rivalColors[index % rivalColors.count],
                    carModel: models[(index + 1) % models.count],
                    skill: min(0.995, baseSkill + Float(index) * 0.014),
                    isPlayer: false
                )
            )
        }

        let rounds = tracks.enumerated().map { index, track in
            ChampionshipRound(
                id: UUID(),
                index: index,
                trackID: track.id,
                trackName: track.name,
                completed: false,
                playerPosition: 0,
                playerPoints: 0,
                winnerName: "",
                results: [:]
            )
        }

        return ChampionshipState(
            id: UUID(),
            name: "Apex Championship",
            difficulty: difficulty,
            entrants: entrants,
            rounds: rounds,
            currentRoundIndex: 0,
            completed: false,
            championName: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    static func currentRound(of state: ChampionshipState) -> ChampionshipRound? {
        guard state.currentRoundIndex >= 0, state.currentRoundIndex < state.rounds.count else { return nil }
        return state.rounds[state.currentRoundIndex]
    }

    static func track(for round: ChampionshipRound) -> TrackLayout? {
        TrackCatalog.builtIn.first(where: { $0.id == round.trackID })
    }

    static func makeRaceConfig(state: ChampionshipState, playerCar: CarConfig) -> RaceConfig? {
        guard !state.completed,
              let round = currentRound(of: state),
              let track = track(for: round),
              let rival = rival(for: state) else {
            return nil
        }
        var rivalCar = CarConfig.standard(for: rival.carModel)
        rivalCar.primaryHex = rival.colorHex
        return RaceConfig(
            mode: .championship,
            track: track,
            playerCar: playerCar,
            opponentCar: rivalCar,
            difficulty: state.difficulty,
            laps: 3,
            pursuitRole: .pursuer,
            opponentName: rival.name,
            championshipContext: ChampionshipRaceContext(
                roundIndex: round.index,
                rivalName: rival.name,
                rivalColorHex: rival.colorHex,
                rivalSkill: rival.skill
            )
        )
    }

    static func rival(for state: ChampionshipState) -> ChampionshipEntrant? {
        let standings = standings(state: state)
        let ai = standings.filter { !$0.isPlayer }
        guard !ai.isEmpty else { return nil }
        return ai[state.currentRoundIndex % ai.count]
    }

    static func standings(state: ChampionshipState) -> [ChampionshipEntrant] {
        state.entrants.sorted { lhs, rhs in
            if lhs.points != rhs.points { return lhs.points > rhs.points }
            if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
            if lhs.podiums != rhs.podiums { return lhs.podiums > rhs.podiums }
            let lb = lhs.bestLap == 0 ? Double.greatestFiniteMagnitude : lhs.bestLap
            let rb = rhs.bestLap == 0 ? Double.greatestFiniteMagnitude : rhs.bestLap
            return lb < rb
        }
    }

    @discardableResult
    static func recordRound(state: inout ChampionshipState, result: RaceResult) -> ChampionshipRound? {
        guard state.currentRoundIndex < state.rounds.count else { return nil }
        let roundIndex = state.currentRoundIndex
        var round = state.rounds[roundIndex]
        let playerResult = result.cars.first(where: { $0.isPlayer })
        let rivalResult = result.cars.first(where: { !$0.isPlayer })
        let playerTime = max(1, playerResult?.totalTime ?? result.cars.map(\.totalTime).min() ?? 60)
        let rivalTime = max(1, rivalResult?.totalTime ?? playerTime * 1.01)
        let reference = (playerTime + rivalTime) * 0.5

        var times: [UUID: Double] = [:]
        for (index, entrant) in state.entrants.enumerated() {
            let time: Double
            if entrant.isPlayer {
                time = playerTime
            } else if entrant.name == rivalResult?.name {
                time = rivalTime
            } else {
                var random = SeededUnitRandom(seed: UInt64(roundIndex + 1) &* 0x9E3779B97F4A7C15 &+ UInt64(index + 7))
                let skillDelta = Double(0.92 - entrant.skill)
                time = reference * (0.995 + skillDelta * 0.33) + Double(random.next()) * 1.6
            }
            times[entrant.id] = time
        }

        let ranked = state.entrants
            .map { (entrant: $0, time: times[$0.id] ?? playerTime) }
            .sorted { $0.time < $1.time }

        for (position, row) in ranked.enumerated() {
            guard let entrantIndex = state.entrants.firstIndex(where: { $0.id == row.entrant.id }) else { continue }
            let points = position < pointsTable.count ? pointsTable[position] : 0
            state.entrants[entrantIndex].points += points
            if position == 0 { state.entrants[entrantIndex].wins += 1 }
            if position < 3 { state.entrants[entrantIndex].podiums += 1 }

            let lap: Double
            if row.entrant.isPlayer {
                lap = result.playerBestLap
            } else if row.entrant.name == rivalResult?.name {
                lap = rivalResult?.bestLap ?? 0
            } else {
                var random = SeededUnitRandom(seed: UInt64(roundIndex + 3) &* 0xD1B54A32D192ED03 &+ UInt64(entrantIndex + 1))
                lap = (row.time / 3.0) * (0.94 + Double(random.next()) * 0.08)
            }
            if lap > 0 {
                let existing = state.entrants[entrantIndex].bestLap
                if existing == 0 || lap < existing {
                    state.entrants[entrantIndex].bestLap = lap
                }
            }
        }

        let playerPosition = (ranked.firstIndex(where: { $0.entrant.isPlayer }) ?? 0) + 1
        let playerPoints = playerPosition <= pointsTable.count ? pointsTable[playerPosition - 1] : 0
        var namedTimes: [String: Double] = [:]
        for row in ranked {
            namedTimes[row.entrant.name] = row.time
        }

        round.completed = true
        round.playerPosition = playerPosition
        round.playerPoints = playerPoints
        round.winnerName = ranked.first?.entrant.name ?? ""
        round.results = namedTimes
        state.rounds[roundIndex] = round
        state.currentRoundIndex = roundIndex + 1
        state.updatedAt = Date()

        if state.currentRoundIndex >= state.rounds.count {
            state.completed = true
            state.championName = standings(state: state).first?.name
            state.updatedAt = Date()
        }
        return round
    }

    static func simulateQualifying(state: inout ChampionshipState) {
        guard let round = currentRound(of: state), let track = track(for: round) else { return }
        let built = TrackPathBuilder.build(track)
        let lapLength = max(8, Double(built.length))
        for index in state.entrants.indices {
            var random = SeededUnitRandom(seed: UInt64(round.index + 11) &* 0x94D049BB133111EB &+ UInt64(index + 1))
            let skill = max(0.7, Double(state.entrants[index].skill))
            let pace = 7.4 * skill
            let jitter = (Double(random.next()) - 0.5) * 0.85
            state.entrants[index].qualifyingTime = lapLength / pace + jitter
        }
        state.updatedAt = Date()
    }

    static func qualifyingOrder(state: ChampionshipState) -> [ChampionshipEntrant] {
        state.entrants
            .filter { $0.qualifyingTime > 0 }
            .sorted { $0.qualifyingTime < $1.qualifyingTime }
    }
}
