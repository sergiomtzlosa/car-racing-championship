import SwiftUI

@MainActor
enum ApexMenuCommand: CaseIterable {
    case quickRace
    case pursuit
    case championship
    case garage
    case trackEditor
    case mainMenu
    case mute

    func title(isMuted: Bool) -> String {
        switch self {
        case .quickRace: return "Quick Race"
        case .pursuit: return "Pursuit"
        case .championship: return "Championship"
        case .garage: return "Garage"
        case .trackEditor: return "Track Editor"
        case .mainMenu: return "Main Menu"
        case .mute: return isMuted ? "Unmute Audio" : "Mute Audio"
        }
    }

    var shortcutKey: KeyEquivalent {
        switch self {
        case .quickRace: return "n"
        case .pursuit: return "p"
        case .championship: return "c"
        case .garage: return "g"
        case .trackEditor: return "e"
        case .mainMenu: return "m"
        case .mute: return "m"
        }
    }

    var shortcutModifiers: EventModifiers {
        switch self {
        case .quickRace, .garage, .trackEditor:
            return [.command]
        case .pursuit, .championship, .mainMenu:
            return [.command, .shift]
        case .mute:
            return [.command, .option]
        }
    }

    func perform(on app: AppModel) {
        switch self {
        case .quickRace: app.openQuickSetup()
        case .pursuit: app.openPursuitSetup()
        case .championship: app.openChampionship()
        case .garage: app.openGarage()
        case .trackEditor: app.openEditor()
        case .mainMenu: app.goToMenu()
        case .mute: app.toggleMute()
        }
    }
}

struct ApexCommands: Commands {
    @ObservedObject var app: AppModel

    var body: some Commands {
        CommandMenu("Apex") {
            Button(ApexMenuCommand.quickRace.title(isMuted: app.isMuted)) {
                ApexMenuCommand.quickRace.perform(on: app)
            }
            .keyboardShortcut(ApexMenuCommand.quickRace.shortcutKey,
                              modifiers: ApexMenuCommand.quickRace.shortcutModifiers)
            Button(ApexMenuCommand.pursuit.title(isMuted: app.isMuted)) {
                ApexMenuCommand.pursuit.perform(on: app)
            }
            .keyboardShortcut(ApexMenuCommand.pursuit.shortcutKey,
                              modifiers: ApexMenuCommand.pursuit.shortcutModifiers)
            Button(ApexMenuCommand.championship.title(isMuted: app.isMuted)) {
                ApexMenuCommand.championship.perform(on: app)
            }
            .keyboardShortcut(ApexMenuCommand.championship.shortcutKey,
                              modifiers: ApexMenuCommand.championship.shortcutModifiers)
            Divider()
            Button(ApexMenuCommand.garage.title(isMuted: app.isMuted)) {
                ApexMenuCommand.garage.perform(on: app)
            }
            .keyboardShortcut(ApexMenuCommand.garage.shortcutKey,
                              modifiers: ApexMenuCommand.garage.shortcutModifiers)
            Button(ApexMenuCommand.trackEditor.title(isMuted: app.isMuted)) {
                ApexMenuCommand.trackEditor.perform(on: app)
            }
            .keyboardShortcut(ApexMenuCommand.trackEditor.shortcutKey,
                              modifiers: ApexMenuCommand.trackEditor.shortcutModifiers)
            Divider()
            Button(ApexMenuCommand.mainMenu.title(isMuted: app.isMuted)) {
                ApexMenuCommand.mainMenu.perform(on: app)
            }
            .keyboardShortcut(ApexMenuCommand.mainMenu.shortcutKey,
                              modifiers: ApexMenuCommand.mainMenu.shortcutModifiers)
            Button(ApexMenuCommand.mute.title(isMuted: app.isMuted)) {
                ApexMenuCommand.mute.perform(on: app)
            }
            .keyboardShortcut(ApexMenuCommand.mute.shortcutKey,
                              modifiers: ApexMenuCommand.mute.shortcutModifiers)
        }
    }
}
