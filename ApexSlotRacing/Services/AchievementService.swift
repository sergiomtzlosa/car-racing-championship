import Foundation

struct AchievementDefinition: Identifiable {
    var id: String
    var title: String
    var detail: String
    var icon: String
}

enum AchievementService {
    static let all: [AchievementDefinition] = [
        AchievementDefinition(id: "apex.first.win", title: "First Blood", detail: "Win your first race.", icon: "flag.checkered"),
        AchievementDefinition(id: "apex.flawless", title: "Flawless Drive", detail: "Win a race without a deslot.", icon: "checkmark.seal.fill"),
        AchievementDefinition(id: "apex.loop.master", title: "Loop Master", detail: "Complete a vertical loop.", icon: "arrow.triangle.2.circlepath"),
        AchievementDefinition(id: "apex.pursuit.master", title: "Pursuit Master", detail: "Capture the fugitive in Pursuit.", icon: "light.beacon.max.fill"),
        AchievementDefinition(id: "apex.champion", title: "Champion", detail: "Win an Apex Championship.", icon: "trophy.fill"),
        AchievementDefinition(id: "apex.speed", title: "Terminal Velocity", detail: "Reach 300 km/h on the scale speedometer.", icon: "speedometer")
    ]

    static func definitions(for ids: [String]) -> [AchievementDefinition] {
        all.filter { ids.contains($0.id) }
    }

    static func evaluate(result: RaceResult, profile: inout PlayerProfile, champion: Bool, loopCompleted: Bool = false) -> [String] {
        var unlocked: [String] = []
        let playerCar = result.cars.first(where: { $0.isPlayer })

        if result.playerWon, result.mode != .qualifying {
            unlock("apex.first.win", profile: &profile, into: &unlocked)
            if result.playerDeslots == 0 {
                unlock("apex.flawless", profile: &profile, into: &unlocked)
            }
            if result.mode == .pursuit, result.playerWon {
                unlock("apex.pursuit.master", profile: &profile, into: &unlocked)
            }
        }
        if result.mode == .pursuit, result.playerWon {
            unlock("apex.pursuit.master", profile: &profile, into: &unlocked)
        }
        if champion {
            unlock("apex.champion", profile: &profile, into: &unlocked)
        }
        if loopCompleted {
            unlock("apex.loop.master", profile: &profile, into: &unlocked)
        }
        if (playerCar?.topSpeed ?? 0) >= 300 {
            unlock("apex.speed", profile: &profile, into: &unlocked)
        }
        return unlocked
    }

    private static func unlock(_ id: String, profile: inout PlayerProfile, into unlocked: inout [String]) {
        guard !profile.achievements.contains(id) else { return }
        profile.achievements.append(id)
        unlocked.append(id)
    }

    static func title(for id: String) -> String {
        all.first(where: { $0.id == id })?.title ?? id
    }
}
