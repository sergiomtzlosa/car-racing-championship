import AppKit
import SwiftUI

@main
struct ApexSlotRacingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var app = ApexSlotRacingApp.makeAppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1440, height: 900)
        .commands {
            ApexCommands(app: app)
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    private static func makeAppModel() -> AppModel {
        if isRunningTests {
            // The test suite creates its own isolated AppModel instances. Keep
            // the host process away from live Game Center and the login
            // keychain so system shields never cover the accessibility tree.
            return AppModel(authenticateGameCenter: false,
                            cloudTokenStore: InMemoryCloudAITokenStore())
        }
        return AppModel()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = NSColor(calibratedRed: 0.027, green: 0.035, blue: 0.047, alpha: 1)
            window.minSize = NSSize(width: 1180, height: 760)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AudioDirector.shared.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
