import AppKit
import SwiftUI

/// Owns the retained, secondary Help window. The window is created once and
/// reused so opening Help never disturbs the main game window's state.
@MainActor
final class HelpWindowController: NSWindowController {
    static let shared = HelpWindowController()

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered,
                              defer: false)
        window.title = "Apex Slot Racing Help"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 960, height: 640)
        window.backgroundColor = NSColor(calibratedRed: 0.027, green: 0.035, blue: 0.047, alpha: 1)
        let host = NSHostingController(rootView: HelpView(onClose: { [weak window] in
            window?.close()
        }))
        window.contentViewController = host
        window.contentView?.setAccessibilityIdentifier("help.window")
        window.center()
        self.init(window: window)
    }

    func showHelp() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
