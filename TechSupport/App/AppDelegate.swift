import Cocoa
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let defaultWindowSize = NSSize(width: 460, height: 740)
    private static let minimumWindowSize = NSSize(width: 380, height: 520)

    var statusItem: NSStatusItem!
    var window: NSWindow!
    var pinned = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "wrench.and.screwdriver", accessibilityDescription: "TechSupport")
            button.image?.isTemplate = true
            button.action = #selector(onMenuClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Build window first, show it, THEN set content (so terminal doesn't block window creation)
        let screen = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let w = Self.defaultWindowSize.width
        let h = Self.defaultWindowSize.height
        let x = screen.maxX - w - 20
        let y = screen.maxY - h - 20

        window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: w, height: h),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "TechSupport"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.minSize = Self.minimumWindowSize
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.backgroundColor = Theme.Colors.terminalBG

        // Set content and show
        let contentView = MainContentView()
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: w, height: h)
        window.contentView = hostingView

        window.makeKeyAndOrderFront(nil)

        // Force activation on next runloop tick to ensure window appears
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.window.makeKeyAndOrderFront(nil)
        }
    }

    @objc func onMenuClick() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleWindow()
        }
    }

    func toggleWindow() {
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(
            withTitle: window.isVisible ? "Hide" : "Show",
            action: #selector(menuToggle),
            keyEquivalent: ""
        )
        menu.addItem(.separator())

        let pinItem = NSMenuItem(
            title: pinned ? "Unpin" : "Pin on Top",
            action: #selector(menuPin),
            keyEquivalent: "p"
        )
        menu.addItem(pinItem)
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit TechSupport",
            action: #selector(menuQuit),
            keyEquivalent: "q"
        )

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func menuToggle() { toggleWindow() }
    @objc func menuQuit() { NSApp.terminate(nil) }

    @objc func menuPin() {
        pinned.toggle()
        window.level = pinned ? .floating : .normal
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        window.orderOut(nil)
        return false
    }
}
