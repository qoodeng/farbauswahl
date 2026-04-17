import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var preferencesPanel: PreferencesPanel?
    private var hotkeyManager: HotkeyManager!
    private var pickerPanel: PickerPanel!
    let colorLibrary = ColorLibrary()
    let colorHistory = ColorHistory()

    private var foregroundColor: ColorValue?
    private var backgroundColor: ColorValue?
    private var currentFix: ColorValue?
    private var fixJustApplied = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        ColorNames.shared.load()
        pickerPanel = PickerPanel()

        // JS → Swift bridge
        pickerPanel.bridge.onPickForeground = { [weak self] in self?.pickForeground() }
        pickerPanel.bridge.onPickBackground = { [weak self] in self?.pickBackground() }
        pickerPanel.bridge.onSwap = { [weak self] in self?.swapColors() }
        pickerPanel.bridge.onSave = { [weak self] in self?.saveToLibrary() }
        pickerPanel.bridge.onApplyFix = { [weak self] in self?.applyFix() }

        // Local window key handlers
        pickerPanel.onUndo = { [weak self] in self?.undo() }
        pickerPanel.onRedo = { [weak self] in self?.redo() }
        pickerPanel.onCopyForeground = { [weak self] in self?.copyForeground() }
        pickerPanel.onCopyBackground = { [weak self] in self?.copyBackground() }
        pickerPanel.onCopyAllText = { [weak self] in self?.copyAllText() }
        pickerPanel.onCopyAllJSON = { [weak self] in self?.copyAllJSON() }

        pickerPanel.bridge.onSetForeground = { [weak self] hex in
            let color = ColorValue(hex: hex)
            self?.foregroundColor = color
            self?.colorHistory.push(color)
            self?.updatePanel()
        }
        pickerPanel.bridge.onSetBackground = { [weak self] hex in
            self?.backgroundColor = ColorValue(hex: hex)
            self?.updatePanel()
        }
        pickerPanel.bridge.onOpenPickerForeground = { [weak self] in self?.openColorPanel(forBackground: false) }
        pickerPanel.bridge.onOpenPickerBackground = { [weak self] in self?.openColorPanel(forBackground: true) }

        pickerPanel.bridge.onRemoveFromLibrary = { [weak self] hex in
            guard let self else { return }
            if let entry = self.colorLibrary.entries.first(where: { $0.color.hex == hex }) {
                self.colorLibrary.remove(id: entry.id)
                self.updatePanel()
            }
        }

        // Window level from settings
        pickerPanel.level = Settings.shared.floatAboveWindows ? .floating : .normal

        // Status bar
        statusBarController = StatusBarController(
            onPick: { [weak self] in self?.pickForeground() },
            onPickBg: { [weak self] in self?.pickBackground() },
            onToggle: { [weak self] in self?.togglePanel() },
            onSwap: { [weak self] in self?.swapColors() }
        )

        // Global hotkeys
        hotkeyManager = HotkeyManager { [weak self] action in
            guard let self else { return }
            switch action {
            case .pickForeground: self.pickForeground()
            case .pickBackground: self.pickBackground()
            case .swap: self.swapColors()
            case .save: self.saveToLibrary()
            case .applyFix: self.applyFix()
            }
        }

        NotificationCenter.default.addObserver(forName: .openPreferences, object: nil, queue: .main) { [weak self] _ in
            self?.openPreferences()
        }
        NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: .main) { [weak self] _ in
            self?.pickerPanel.level = Settings.shared.floatAboveWindows ? .floating : .normal
            self?.applyAppearance()
            self?.updatePanel()
        }
        applyAppearance()

        // Restore last-picked colors if any
        if let fgHex = Settings.shared.lastForeground {
            foregroundColor = ColorValue(hex: fgHex)
        }
        if let bgHex = Settings.shared.lastBackground {
            backgroundColor = ColorValue(hex: bgHex)
        }
        if foregroundColor != nil {
            updatePanel(andShow: true)
        } else {
            pickerPanel.show()
        }
    }

    // MARK: - Picking

    private func pickForeground() {
        if Settings.shared.hideWhilePicking { pickerPanel.orderOut(nil) }
        pickColor { [weak self] color in
            guard let self else { return }
            self.foregroundColor = color
            self.colorHistory.push(color)
            if Settings.shared.autoCopyOnPick {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(color.hex, forType: .string)
            }
            self.updatePanel(andShow: true)
        }
    }

    private func pickBackground() {
        if Settings.shared.hideWhilePicking { pickerPanel.orderOut(nil) }
        pickColor { [weak self] color in
            guard let self else { return }
            self.backgroundColor = color
            self.colorHistory.push(color)
            self.updatePanel(andShow: true)
        }
    }

    private func swapColors() {
        guard let fg = foregroundColor, let bg = backgroundColor else { return }
        foregroundColor = bg
        backgroundColor = fg
        updatePanel()
    }

    private func saveToLibrary() {
        guard let fg = foregroundColor else { return }
        colorLibrary.add(color: fg)
        updatePanel()
    }

    private func applyFix() {
        guard let fix = currentFix else { return }
        foregroundColor = fix
        currentFix = nil
        fixJustApplied = true
        colorHistory.push(fix)
        updatePanel()
    }

    private func undo() {
        if let color = colorHistory.undo() {
            foregroundColor = color
            updatePanel()
        }
    }

    private func redo() {
        if let color = colorHistory.redo() {
            foregroundColor = color
            updatePanel()
        }
    }

    // MARK: - Copy

    private func copyForeground() {
        guard let fg = foregroundColor else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fg.hex, forType: .string)
    }

    private func copyBackground() {
        guard let bg = backgroundColor else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(bg.hex, forType: .string)
    }

    private func copyAllText() {
        guard let fg = foregroundColor else { return }
        let bg = backgroundColor ?? ColorValue(hex: "#FFFFFF")
        let formatted = FormattedColor(color: fg)
        let contrast = ContrastChecker.check(foreground: fg, background: bg)

        var lines: [String] = []
        if let name = formatted.colorName { lines.append("Name: \(name)") }
        for v in formatted.values { lines.append("\(v.label): \(v.value)") }
        lines.append("P3: \(formatted.p3)")
        lines.append("")
        lines.append("Background: \(bg.hex)")
        lines.append("WCAG: \(contrast.wcagRatioString)")
        lines.append("APCA: Lc \(contrast.apcaLcString)")

        let text = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copyAllJSON() {
        guard let fg = foregroundColor else { return }
        let bg = backgroundColor ?? ColorValue(hex: "#FFFFFF")
        let formatted = FormattedColor(color: fg)
        let contrast = ContrastChecker.check(foreground: fg, background: bg)

        var dict: [String: Any] = [
            "foreground": fg.hex,
            "background": bg.hex,
            "wcagRatio": contrast.wcagRatio,
            "apcaLc": contrast.apcaLc,
        ]
        if let name = formatted.colorName { dict["colorName"] = name }
        var formats: [String: String] = [:]
        for v in formatted.values { formats[v.label] = v.value }
        formats["P3"] = formatted.p3
        dict["formats"] = formats

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(json, forType: .string)
        }
    }

    // MARK: - System Color Panel

    private var colorPanelTarget: ColorPanelTarget = .foreground

    private enum ColorPanelTarget { case foreground, background }

    private func openColorPanel(forBackground: Bool) {
        colorPanelTarget = forBackground ? .background : .foreground
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = true
        if forBackground, let bg = backgroundColor {
            panel.color = bg.nsColor
        } else if let fg = foregroundColor {
            panel.color = fg.nsColor
        }
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        panel.orderFront(nil)
    }

    @objc private func colorPanelChanged(_ sender: NSColorPanel) {
        let nsColor = sender.color.usingColorSpace(.sRGB) ?? sender.color
        let color = ColorValue(r: nsColor.redComponent, g: nsColor.greenComponent, b: nsColor.blueComponent)
        switch colorPanelTarget {
        case .foreground:
            foregroundColor = color
        case .background:
            backgroundColor = color
        }
        updatePanel()
    }

    // MARK: - Helpers

    private func pickColor(completion: @escaping (ColorValue) -> Void) {
        // Disconnect system color panel if open
        let panel = NSColorPanel.shared
        if panel.isVisible { panel.setTarget(nil); panel.setAction(nil) }

        let sampler = NSColorSampler()
        sampler.show { color in
            guard let color else { return }
            let nsColor = color.usingColorSpace(.sRGB) ?? color
            let r = nsColor.redComponent
            let g = nsColor.greenComponent
            let b = nsColor.blueComponent
            let colorValue = ColorValue(r: r, g: g, b: b)
            DispatchQueue.main.async { completion(colorValue) }
        }
    }

    private func updatePanel(andShow: Bool = false) {
        guard let fg = foregroundColor else { return }
        let bg = backgroundColor ?? ColorValue(hex: "#FFFFFF")
        Settings.shared.lastForeground = fg.hex
        Settings.shared.lastBackground = bg.hex
        currentFix = ContrastChecker.fix(fg, against: bg)
        let applied = fixJustApplied
        fixJustApplied = false
        pickerPanel.update(
            foreground: fg,
            background: bg,
            history: colorHistory,
            library: colorLibrary,
            fix: currentFix,
            fixApplied: applied
        )
        if andShow { pickerPanel.show() }
    }

    private func togglePanel() {
        if pickerPanel.isVisible {
            pickerPanel.close()
        } else {
            pickerPanel.show()
        }
    }

    private func applyAppearance() {
        let appearance: NSAppearance?
        switch Settings.shared.appearance {
        case "light": appearance = NSAppearance(named: .aqua)
        case "dark": appearance = NSAppearance(named: .darkAqua)
        default: appearance = nil  // system
        }
        pickerPanel.appearance = appearance
        preferencesPanel?.appearance = appearance
    }

    private func openPreferences() {
        if preferencesPanel == nil {
            preferencesPanel = PreferencesPanel()
        }
        preferencesPanel?.show()
    }

    // MARK: - URL Scheme

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleURL(url)
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "farbauswahl" else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        let host = url.host ?? ""

        switch host {
        case "pick":
            if parts.first == "background" { pickBackground() }
            else { pickForeground() }
        case "copy":
            switch parts.first {
            case "background": copyBackground()
            case "text": copyAllText()
            case "json": copyAllJSON()
            default: copyForeground()
            }
        case "swap":
            swapColors()
        case "set":
            if parts.count >= 2 {
                let color = ColorValue(hex: parts[1])
                if parts.first == "background" {
                    backgroundColor = color
                } else {
                    foregroundColor = color
                    colorHistory.push(color)
                }
                updatePanel(andShow: true)
            }
        default:
            break
        }
    }
}
