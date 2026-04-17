import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let onPick: () -> Void
    private let onPickBg: () -> Void
    private let onToggle: () -> Void
    private let onSwap: () -> Void

    init(
        onPick: @escaping () -> Void,
        onPickBg: @escaping () -> Void,
        onToggle: @escaping () -> Void,
        onSwap: @escaping () -> Void
    ) {
        self.onPick = onPick
        self.onPickBg = onPickBg
        self.onToggle = onToggle
        self.onSwap = onSwap
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "eyedropper",
                accessibilityDescription: "Farbauswahl"
            )
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            onToggle()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Pick Foreground", action: #selector(menuPickFg), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Pick Background", action: #selector(menuPickBg), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Swap Colors", action: #selector(menuSwap), keyEquivalent: "").target = self
        menu.addItem(.separator())

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(menuToggleLaunch), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = Settings.shared.launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Preferences…", action: #selector(menuPrefs), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Farbauswahl", action: #selector(menuQuit), keyEquivalent: "q").target = self

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil  // reset so left-click works next time
    }

    @objc private func menuPickFg() { onPick() }
    @objc private func menuPickBg() { onPickBg() }
    @objc private func menuSwap() { onSwap() }
    @objc private func menuPrefs() { NotificationCenter.default.post(name: .openPreferences, object: nil) }
    @objc private func menuQuit() { NSApp.terminate(nil) }
    @objc private func menuToggleLaunch() { Settings.shared.launchAtLogin.toggle() }
}
