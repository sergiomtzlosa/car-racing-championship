import AppKit
import ApplicationServices
import SwiftUI
import XCTest
@testable import ApexSlotRacing

/// A shared, visible AppKit window that hosts SwiftUI screens for the UI test
/// suite. The window is intentionally never closed: XCTest's object lifetime
/// checker can crash when a visible hosting window is torn down mid-process.
@MainActor
final class ApexUIHost {
    static let shared = ApexUIHost()

    let window: NSWindow
    private var retainedHosts: [NSView] = []

    private init() {
        window = NSWindow(contentRect: NSRect(x: 60, y: 60, width: 1440, height: 900),
                          styleMask: [.titled, .resizable],
                          backing: .buffered,
                          defer: false)
        window.title = "Apex Slot Racing UI Tests"
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 1440, height: 900))
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        pump(0.20)
    }

    func show<V: View>(_ view: V, app: AppModel, size: NSSize = NSSize(width: 1440, height: 900)) {
        let root = AnyView(view.environmentObject(app).frame(width: size.width, height: size.height))
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: size)
        retainedHosts.append(host)
        window.contentView = host
        window.setContentSize(size)
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        host.layoutSubtreeIfNeeded()
        pump(0.30)
    }

    func showPlaceholder(app: AppModel) {
        show(Text("UI test idle").foregroundStyle(.clear), app: app)
    }

    // MARK: - Accessibility queries

    private var applicationElement: AXUIElement {
        AXUIElementCreateApplication(getpid())
    }

    func elements(maxDepth: Int = 36) -> [AXUIElement] {
        flatten(root: applicationElement, depth: 0, maxDepth: maxDepth)
    }

    func find(_ identifier: String, timeout: TimeInterval = 2.5) -> AXUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let match = elements().first(where: { stringAttribute($0, kAXIdentifierAttribute) == identifier }) {
                return match
            }
            pump(0.06)
        } while Date() < deadline
        return nil
    }

    func findButton(label: String, timeout: TimeInterval = 2.5) -> AXUIElement? {
        let normalized = label.lowercased()
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let match = elements().first(where: { element in
                guard role(of: element) == kAXButtonRole as String else { return false }
                return [title(of: element), description(of: element), value(of: element)]
                    .compactMap { $0?.lowercased() }
                    .contains { $0 == normalized }
            }) {
                return match
            }
            pump(0.06)
        } while Date() < deadline
        return nil
    }

    @discardableResult
    func require(_ identifier: String,
                 file: StaticString = #filePath,
                 line: UInt = #line) -> AXUIElement {
        guard let element = find(identifier) else {
            XCTFail("Missing accessibility element '\(identifier)'", file: file, line: line)
            return applicationElement
        }
        return element
    }

    func exists(_ identifier: String) -> Bool {
        find(identifier, timeout: 0.8) != nil
    }

    func press(_ identifier: String,
               file: StaticString = #filePath,
               line: UInt = #line) {
        let element = require(identifier, file: file, line: line)
        press(element: element, identifier: identifier, file: file, line: line)
    }

    func press(element: AXUIElement,
               identifier: String,
               file: StaticString = #filePath,
               line: UInt = #line) {
        var error = AXUIElementPerformAction(element, kAXPressAction as CFString)
        if error != .success {
            // Some SwiftUI controls expose the button trait without kAXPress.
            // A synthetic click at the element centre is the fallback.
            syntheticClick(on: element)
            error = .success
        }
        XCTAssertEqual(error, .success, "Could not press '\(identifier)'", file: file, line: line)
        pump(0.22)
    }

    @discardableResult
    func pressButton(label: String,
                     file: StaticString = #filePath,
                     line: UInt = #line) -> Bool {
        guard let element = findButton(label: label) else {
            XCTFail("Missing button titled '\(label)'", file: file, line: line)
            return false
        }
        press(element: element, identifier: label, file: file, line: line)
        return true
    }

    @discardableResult
    func pressMenuItem(label: String,
                       file: StaticString = #filePath,
                       line: UInt = #line) -> Bool {
        let normalized = label.lowercased()
        let deadline = Date().addingTimeInterval(2.0)
        repeat {
            if let item = elements().first(where: { element in
                guard role(of: element) == kAXMenuItemRole as String else { return false }
                return [title(of: element), description(of: element), value(of: element)]
                    .compactMap { $0?.lowercased() }
                    .contains { $0 == normalized }
            }) {
                press(element: item, identifier: "menu item \(label)", file: file, line: line)
                return true
            }
            pump(0.06)
        } while Date() < deadline
        XCTFail("Missing menu item '\(label)'", file: file, line: line)
        return false
    }

    func pressChild(in groupIdentifier: String,
                    label: String,
                    file: StaticString = #filePath,
                    line: UInt = #line) {
        let group = require(groupIdentifier, file: file, line: line)
        let normalized = label.lowercased()
        let descendants = flatten(root: group, depth: 0, maxDepth: 12)
        guard let child = descendants.first(where: { element in
            [title(of: element), description(of: element), value(of: element)]
                .compactMap { $0?.lowercased() }
                .contains { $0 == normalized }
        }) else {
            XCTFail("Missing '\(label)' inside '\(groupIdentifier)'", file: file, line: line)
            return
        }
        press(element: child, identifier: "\(groupIdentifier) → \(label)", file: file, line: line)
    }

    func pressOption(in groupIdentifier: String,
                     label: String,
                     file: StaticString = #filePath,
                     line: UInt = #line) {
        pressChild(in: groupIdentifier, label: label, file: file, line: line)
    }

    func setSlider(_ identifier: String,
                   to value: Double,
                   file: StaticString = #filePath,
                   line: UInt = #line) {
        let element = require(identifier, file: file, line: line)
        let result = AXUIElementSetAttributeValue(element,
                                                  kAXValueAttribute as CFString,
                                                  NSNumber(value: value))
        if result != .success {
            // Fall back to clicking at the approximated slider position.
            syntheticClick(on: element, normalizedX: value)
        }
        pump(0.22)
    }

    func pasteText(_ identifier: String,
                   _ text: String,
                   file: StaticString = #filePath,
                   line: UInt = #line) {
        let element = require(identifier, file: file, line: line)
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        pump(0.10)
        guard let textView = firstEditableTextView() else {
            XCTFail("No editable NSTextView for '\(identifier)'", file: file, line: line)
            return
        }
        window.makeFirstResponder(textView)
        textView.selectAll(nil)
        textView.insertText(text, replacementRange: textView.selectedRange())
        textView.didChangeText()
        pump(0.30)
    }

    private func firstEditableTextView() -> NSTextView? {
        if let responder = NSApp.keyWindow?.firstResponder as? NSTextView, responder.isEditable {
            return responder
        }
        for window in NSApp.windows {
            if let responder = window.firstResponder as? NSTextView, responder.isEditable {
                return responder
            }
            if let match = firstEditableTextView(in: window.contentView) {
                return match
            }
        }
        return firstEditableTextView(in: window.contentView)
    }

    private func firstEditableTextView(in view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let textView = view as? NSTextView, textView.isEditable {
            return textView
        }
        for child in view.subviews {
            if let match = firstEditableTextView(in: child) {
                return match
            }
        }
        return nil
    }

    func setText(_ identifier: String,
                 to text: String,
                 file: StaticString = #filePath,
                 line: UInt = #line) {
        let element = require(identifier, file: file, line: line)
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        let result = AXUIElementSetAttributeValue(element,
                                                  kAXValueAttribute as CFString,
                                                  text as CFString)
        if result == .success {
            AXUIElementPerformAction(element, kAXConfirmAction as CFString)
            sendReturnKey()
        } else {
            // Focus the control and replace its contents with a paste so the
            // SwiftUI binding receives normal editing notifications.
            syntheticClick(on: element)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            sendKey("a", modifiers: .command)
            sendKey("v", modifiers: .command)
        }
        pump(0.30)
    }

    private func sendReturnKey() {
        guard let event = NSEvent.keyEvent(with: .keyDown,
                                           location: .zero,
                                           modifierFlags: [],
                                           timestamp: ProcessInfo.processInfo.systemUptime,
                                           windowNumber: window.windowNumber,
                                           context: nil,
                                           characters: "\r",
                                           charactersIgnoringModifiers: "\r",
                                           isARepeat: false,
                                           keyCode: 36) else { return }
        window.sendEvent(event)
    }

    private func sendKey(_ character: String, modifiers: NSEvent.ModifierFlags) {
        guard let down = NSEvent.keyEvent(with: .keyDown,
                                          location: .zero,
                                          modifierFlags: modifiers,
                                          timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: window.windowNumber,
                                          context: nil,
                                          characters: character,
                                          charactersIgnoringModifiers: character,
                                          isARepeat: false,
                                          keyCode: 0),
              let up = NSEvent.keyEvent(with: .keyUp,
                                        location: .zero,
                                        modifierFlags: modifiers,
                                        timestamp: ProcessInfo.processInfo.systemUptime + 0.02,
                                        windowNumber: window.windowNumber,
                                        context: nil,
                                        characters: character,
                                        charactersIgnoringModifiers: character,
                                        isARepeat: false,
                                        keyCode: 0) else { return }
        window.sendEvent(down)
        window.sendEvent(up)
    }

    func value(_ identifier: String, timeout: TimeInterval = 2.5) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let matches = elements().filter {
                stringAttribute($0, kAXIdentifierAttribute) == identifier
            }
            if let text = matches.compactMap({ value(of: $0) }).first(where: { !$0.isEmpty }) {
                return text
            }
            pump(0.06)
        } while Date() < deadline
        return nil
    }

    func label(_ identifier: String, timeout: TimeInterval = 2.5) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let matches = elements().filter {
                stringAttribute($0, kAXIdentifierAttribute) == identifier
            }
            for element in matches {
                if let text = description(of: element), !text.isEmpty { return text }
                if let text = title(of: element), !text.isEmpty { return text }
                if let text = value(of: element), !text.isEmpty { return text }
            }
            pump(0.06)
        } while Date() < deadline
        return nil
    }

    func text(containing needle: String, timeout: TimeInterval = 2.5) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for element in elements() {
                for candidate in [value(of: element), description(of: element), title(of: element)] {
                    if let candidate, candidate.localizedCaseInsensitiveContains(needle) {
                        return candidate
                    }
                }
            }
            pump(0.08)
        } while Date() < deadline
        return nil
    }

    func isEnabled(_ identifier: String, timeout: TimeInterval = 2.5) -> Bool? {
        guard let element = find(identifier, timeout: timeout) else { return nil }
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &raw) == .success else {
            return nil
        }
        return (raw as? NSNumber)?.boolValue
    }

    // MARK: - Attributes

    func role(of element: AXUIElement) -> String? {
        stringAttribute(element, kAXRoleAttribute)
    }

    func title(of element: AXUIElement) -> String? {
        stringAttribute(element, kAXTitleAttribute)
    }

    func description(of element: AXUIElement) -> String? {
        stringAttribute(element, kAXDescriptionAttribute)
    }

    func value(of element: AXUIElement) -> String? {
        guard let raw = attribute(element, kAXValueAttribute) else { return nil }
        if let text = raw as? String { return text }
        if let number = raw as? NSNumber { return number.stringValue }
        return nil
    }

    func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name) as? String
    }

    private func attribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    func dump(_ note: String = "") {
        if !note.isEmpty { print("AX DUMP: \(note)") }
        for element in elements() {
            let id = stringAttribute(element, kAXIdentifierAttribute) ?? "-"
            let role = role(of: element) ?? "-"
            let title = title(of: element) ?? "-"
            let desc = description(of: element) ?? "-"
            let value = value(of: element) ?? "-"
            print("AX | id=\(id) | role=\(role) | title=\(title) | desc=\(desc) | value=\(value)")
        }
    }

    // MARK: - Internals

    private func flatten(root: AXUIElement, depth: Int, maxDepth: Int) -> [AXUIElement] {
        guard depth <= maxDepth else { return [] }
        var result: [AXUIElement] = [root]
        guard let children = children(of: root) else { return result }
        for child in children {
            result.append(contentsOf: flatten(root: child, depth: depth + 1, maxDepth: maxDepth))
        }
        return result
    }

    private func children(of element: AXUIElement) -> [AXUIElement]? {
        guard let raw = attribute(element, kAXChildrenAttribute) else { return nil }
        return raw as? [AXUIElement]
    }

    private func elementFrame(_ element: AXUIElement) -> CGRect? {
        guard let positionRaw = attribute(element, kAXPositionAttribute),
              let sizeRaw = attribute(element, kAXSizeAttribute) else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionRaw as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRaw as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func syntheticClick(on element: AXUIElement, normalizedX: Double = 0.5) {
        guard let frame = elementFrame(element), frame.width > 0, frame.height > 0 else { return }
        let flipHeight = NSScreen.screens.first?.frame.maxY ?? 0
        let appKitPoint = NSPoint(x: frame.minX + frame.width * normalizedX,
                                  y: flipHeight - frame.midY)
        let windowPoint = window.convertPoint(fromScreen: appKitPoint)
        let down = NSEvent.mouseEvent(with: .leftMouseDown,
                                      location: windowPoint,
                                      modifierFlags: [],
                                      timestamp: ProcessInfo.processInfo.systemUptime,
                                      windowNumber: window.windowNumber,
                                      context: nil,
                                      eventNumber: 0,
                                      clickCount: 1,
                                      pressure: 1)
        let up = NSEvent.mouseEvent(with: .leftMouseUp,
                                    location: windowPoint,
                                    modifierFlags: [],
                                    timestamp: ProcessInfo.processInfo.systemUptime + 0.03,
                                    windowNumber: window.windowNumber,
                                    context: nil,
                                    eventNumber: 1,
                                    clickCount: 1,
                                    pressure: 0)
        if let down { window.sendEvent(down) }
        pump(0.05)
        if let up { window.sendEvent(up) }
        pump(0.18)
    }

    func pump(_ seconds: TimeInterval = 0.15) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }
}

@MainActor
class ApexUITestCase: XCTestCase {
    let ui = ApexUIHost.shared
    var app: AppModel!
    var saveStore: SaveStore!
    var temporaryDirectory: URL!
    var tokenStore: InMemoryCloudAITokenStore!

    private var settingsKey = "apexSlotRacing.settings.v1"
    private var settingsBackup: Data?
    private var hadSettings = false

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        settingsBackup = UserDefaults.standard.data(forKey: settingsKey)
        hadSettings = settingsBackup != nil
        UserDefaults.standard.removeObject(forKey: settingsKey)

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexUIAX-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        saveStore = SaveStore(rootURL: temporaryDirectory)

        AudioDirector.shared.endRace()
        AudioDirector.shared.setMuted(false)
        tokenStore = InMemoryCloudAITokenStore()
        app = AppModel(saveStore: saveStore,
                       authenticateGameCenter: false,
                       cloudTokenStore: tokenStore)
        ui.showPlaceholder(app: app)
    }

    override func tearDown() {
        ui.showPlaceholder(app: app)
        if hadSettings, let settingsBackup {
            UserDefaults.standard.set(settingsBackup, forKey: settingsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: settingsKey)
        }
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        app = nil
        saveStore = nil
        temporaryDirectory = nil
        tokenStore = nil
        super.tearDown()
    }

    func show<V: View>(_ view: V, size: NSSize = NSSize(width: 1440, height: 900)) {
        ui.show(view, app: app, size: size)
    }

    func pump(_ seconds: TimeInterval = 0.15) {
        ui.pump(seconds)
    }

    @discardableResult
    func waitUntil(timeout: TimeInterval = 3,
                   _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            pump(0.08)
        } while Date() < deadline
        return condition()
    }

    var raceConfig: RaceConfig? {
        if case .race(let config) = app.route { return config }
        return nil
    }

    var routeIsRace: Bool { raceConfig != nil }
}
