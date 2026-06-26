import AppKit
import GameKit
import SwiftUI

@MainActor
final class GameCenterService: NSObject, ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var statusText = "Local records active"
    @Published private(set) var playerAlias = ""

    static let leaderboardBestLapPrefix = "apex.bestlap."
    static let leaderboardChampionship = "apex.championship.points"
    static let leaderboardPursuit = "apex.pursuit.wins"

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                    self.statusText = self.isAuthenticated ? "Game Center connected" : "Game Center unavailable — local records active"
                    NSLog("ApexSlotRacing Game Center: \(error.localizedDescription)")
                    return
                }
                if let viewController {
                    self.present(viewController)
                }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                self.playerAlias = GKLocalPlayer.local.displayName
                self.statusText = self.isAuthenticated ? "Game Center connected" : "Local records active"
            }
        }
    }

    func report(profile: PlayerProfile, championshipPoints: Int = 0) {
        guard isAuthenticated else { return }
        for (trackName, lap) in profile.bestLaps where lap > 0 {
            let id = Self.leaderboardBestLapPrefix + sanitize(trackName)
            GKLeaderboard.submitScore(Int(lap * 1000), context: 0, player: GKLocalPlayer.local, leaderboardIDs: [id]) { error in
                if let error { NSLog("ApexSlotRacing leaderboard error: \(error.localizedDescription)") }
            }
        }
        if championshipPoints > 0 {
            GKLeaderboard.submitScore(championshipPoints, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [Self.leaderboardChampionship]) { error in
                if let error { NSLog("ApexSlotRacing leaderboard error: \(error.localizedDescription)") }
            }
        }
        if profile.pursuitsWon > 0 {
            GKLeaderboard.submitScore(profile.pursuitsWon, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [Self.leaderboardPursuit]) { error in
                if let error { NSLog("ApexSlotRacing leaderboard error: \(error.localizedDescription)") }
            }
        }
    }

    func reportAchievement(id: String, percent: Double = 100) {
        guard isAuthenticated else { return }
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = min(100, max(0, percent))
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { error in
            if let error { NSLog("ApexSlotRacing achievement error: \(error.localizedDescription)") }
        }
    }

    func showDashboard() {
        guard isAuthenticated else {
            authenticate()
            return
        }
        let controller = GKGameCenterViewController(state: .default)
        controller.gameCenterDelegate = self
        present(controller)
    }

    private func present(_ controller: NSViewController) {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow,
              let host = window.contentViewController else {
            return
        }
        if host.presentedViewControllers?.contains(where: { $0 === controller }) == true { return }
        host.presentAsSheet(controller)
    }

    private func sanitize(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}

extension GameCenterService: GKGameCenterControllerDelegate {
    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        Task { @MainActor in
            gameCenterViewController.dismiss(nil)
        }
    }
}
