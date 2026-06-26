import AppKit

enum HapticsService {
    static func impact(_ strength: NSHapticFeedbackManager.FeedbackPattern = .alignment) {
        NSHapticFeedbackManager.defaultPerformer.perform(strength, performanceTime: .now)
    }

    static func deslot() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
