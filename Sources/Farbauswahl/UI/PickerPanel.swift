import AppKit
import WebKit

final class PickerPanel: NSWindow, WKNavigationDelegate {
    private let webView: WKWebView
    let bridge: WebBridge
    private var hasBeenPositioned = false
    private var pageReady = false
    private var pendingUpdate: (() -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?

    init() {
        let config = WKWebViewConfiguration()
        let userController = WKUserContentController()
        config.userContentController = userController

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 320, height: 560), configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        bridge = WebBridge()
        // Use leakAvoider to break the retain cycle:
        // WKUserContentController strongly retains the handler
        let leakAvoider = LeakAvoidingMessageHandler(delegate: bridge)
        userController.add(leakAvoider, name: "farbauswahl")

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: true
        )

        title = "Farbauswahl"
        contentView = webView
        isReleasedWhenClosed = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .windowBackgroundColor
        level = .floating
        isMovableByWindowBackground = true

        contentMinSize = NSSize(width: 320, height: 100)
        contentMaxSize = NSSize(width: 320, height: 2000)

        bridge.onResize = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.resizeToFitContent()
            }
        }

        webView.navigationDelegate = self
        loadHTML()
        installKeyMonitor()
    }

    private func loadHTML() {
        guard let url = Bundle.module.url(forResource: "app", withExtension: "html") else {
            FileHandle.standardError.write(Data("[Farbauswahl] app.html not found in bundle\n".utf8))
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageReady = true
        if let pending = pendingUpdate {
            pending()
            pendingUpdate = nil
        }
        resizeToFitContent()
    }

    var onCopyForeground: (() -> Void)?
    var onCopyBackground: (() -> Void)?
    var onCopyAllText: (() -> Void)?
    var onCopyAllJSON: (() -> Void)?
    var currentValues: [(label: String, value: String)] = []
    private var keyMonitor: Any?

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isKeyWindow else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            switch (event.keyCode, flags) {
            case (12, [.command]):                          // ⌘Q
                NSApp.terminate(nil); return nil
            case (8, [.command]):                           // ⌘C
                self.onCopyForeground?(); return nil
            case (6, [.command]):                           // ⌘Z
                self.onUndo?(); return nil
            case (6, [.command, .shift]):                   // ⌘⇧Z
                self.onRedo?(); return nil
            case (8, [.command, .option]):                  // ⌘⌥C
                self.onCopyAllText?(); return nil
            case (8, [.command, .option, .shift]):           // ⇧⌘⌥C
                self.onCopyAllJSON?(); return nil
            case (43, [.command]):                          // ⌘, (keyCode 43 = comma)
                NotificationCenter.default.post(name: .openPreferences, object: nil); return nil
            case (let k, [.command]) where (18...28).contains(k):
                let numIndex: Int
                switch k {
                case 18: numIndex = 0
                case 19: numIndex = 1
                case 20: numIndex = 2
                case 21: numIndex = 3
                case 23: numIndex = 4
                case 22: numIndex = 5
                case 26: numIndex = 6
                case 28: numIndex = 7
                default: numIndex = -1
                }
                if numIndex >= 0 && numIndex < self.currentValues.count {
                    let val = self.currentValues[numIndex].value
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(val, forType: .string)
                    self.webView.evaluateJavaScript("copyValue('\(self.escapeJS(val))')") { _, _ in }
                }
                return nil
            default:
                return event
            }
        }
    }

    deinit {
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
    }

    func update(foreground: ColorValue, background: ColorValue, history: ColorHistory, library: ColorLibrary, fix: ColorValue? = nil, fixApplied: Bool = false) {
        if pageReady {
            executeUpdate(foreground: foreground, background: background, history: history, library: library, fix: fix, fixApplied: fixApplied)
        } else {
            pendingUpdate = { [weak self] in
                self?.executeUpdate(foreground: foreground, background: background, history: history, library: library, fix: fix, fixApplied: fixApplied)
            }
        }
    }

    private func executeUpdate(foreground: ColorValue, background: ColorValue, history: ColorHistory, library: ColorLibrary, fix: ColorValue?, fixApplied: Bool) {
        let formatted = FormattedColor(color: foreground)
        // Store for ⌘1–⌘8 shortcuts
        var vals: [(label: String, value: String)] = []
        if let name = formatted.colorName { vals.append(("Name", name)) }
        vals += formatted.values.map { ($0.label, $0.value) }
        vals.append(("P3", formatted.p3))
        currentValues = vals
        let contrast = ContrastChecker.check(foreground: foreground, background: background)

        var fixData = "null"
        if let f = fix {
            let fixContrast = ContrastChecker.check(foreground: f, background: background)
            fixData = """
            {"hex":"\(f.hex)","wcag":"\(fixContrast.wcagRatioString)","apca":"\(fixContrast.apcaLcString)"}
            """
        }

        let historyHexes = history.entries.prefix(20).map { "\"\($0.hex)\"" }.joined(separator: ",")
        let libraryHexes = library.colors(limit: 20).map { "\"\($0.hex)\"" }.joined(separator: ",")

        let valuesJSON = formatted.values.map {
            "{\"label\":\"\($0.label)\",\"value\":\"\(escapeJS($0.value))\"}"
        }.joined(separator: ",")

        let js = """
        updateUI({
          fg: "\(foreground.hex)",
          bg: "\(background.hex)",
          displayProfile: "\(escapeJS(NSScreen.main?.colorSpace?.localizedName ?? "Unknown"))",
          gamut: "\(Self.displayGamut())",
          colorName: \(formatted.colorName.map { "\"\(escapeJS($0))\"" } ?? "null"),
          p3: "\(escapeJS(formatted.p3))",
          values: [\(valuesJSON)],
          wcagRatio: "\(contrast.wcagRatioString)",
          wcagAALarge: \(contrast.aaLarge),
          wcagAA: \(contrast.aaNormal),
          wcagAAA: \(contrast.aaaNormal),
          apcaLc: "\(contrast.apcaLcString)",
          apcaBody: \(contrast.apcaBody),
          apcaLarge: \(contrast.apcaLarge),
          apcaFine: \(contrast.apcaFine),
          fix: \(fixData),
          fixApplied: \(fixApplied),
          history: [\(historyHexes)],
          library: [\(libraryHexes)],
          libraryCount: \(library.entries.count),
          luminance: "\(String(format: "%.3f", foreground.relativeLuminance))",
          font: "\(Settings.shared.font)"
        });
        """

        webView.evaluateJavaScript(js) { [weak self] _, error in
            if let error {
                FileHandle.standardError.write(Data("[Farbauswahl] JS error: \(error)\n".utf8))
            }
            self?.resizeToFitContent()
        }
    }

    func show() {
        if !hasBeenPositioned, let screen = NSScreen.main {
            let x = (screen.frame.width - frame.width) / 2 + screen.frame.origin.x
            let y = (screen.frame.height - frame.height) / 2 + screen.frame.origin.y
            setFrameOrigin(NSPoint(x: x, y: y))
            hasBeenPositioned = true
        }
        if !isVisible {
            makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func displayGamut() -> String {
        guard let name = NSScreen.main?.colorSpace?.localizedName?.lowercased() else { return "Unknown" }
        if name.contains("p3") { return "Display P3" }
        if name.contains("adobe") { return "Adobe RGB" }
        return "sRGB"
    }

    private func resizeToFitContent() {
        webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
            guard let self, let height = result as? CGFloat else { return }
            let titleBarHeight: CGFloat = 28
            let newHeight = height + titleBarHeight + 4
            let origin = self.frame.origin
            let newY = origin.y + self.frame.height - newHeight
            self.setFrame(NSRect(x: origin.x, y: newY, width: 320, height: newHeight), display: true)
        }
    }

    private func escapeJS(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "'", with: "\\'")
         .replacingOccurrences(of: "\n", with: "\\n")
         .replacingOccurrences(of: "\r", with: "\\r")
    }
}

/// Weak proxy to break WKUserContentController → handler retain cycle
extension Notification.Name {
    static let openPreferences = Notification.Name("openPreferences")
}

final class LeakAvoidingMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

final class WebBridge: NSObject, WKScriptMessageHandler {
    var onPickForeground: (() -> Void)?
    var onPickBackground: (() -> Void)?
    var onSwap: (() -> Void)?
    var onSave: (() -> Void)?
    var onApplyFix: (() -> Void)?
    var onResize: (() -> Void)?
    var onSetForeground: ((String) -> Void)?
    var onSetBackground: ((String) -> Void)?
    var onRemoveFromLibrary: ((String) -> Void)?
    var onOpenPickerForeground: (() -> Void)?
    var onOpenPickerBackground: (() -> Void)?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        switch action {
        case "copy":
            if let value = body["value"] as? String {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            }
        case "pickForeground":
            onPickForeground?()
        case "pickBackground":
            onPickBackground?()
        case "swap":
            onSwap?()
        case "save":
            onSave?()
        case "applyFix":
            onApplyFix?()
        case "resize":
            onResize?()  // Swiss mode toggle
        case "setForeground":
            if let hex = body["hex"] as? String { onSetForeground?(hex) }
        case "setBackground":
            if let hex = body["hex"] as? String { onSetBackground?(hex) }
        case "removeFromLibrary":
            if let hex = body["hex"] as? String { onRemoveFromLibrary?(hex) }
        case "openPickerForeground":
            onOpenPickerForeground?()
        case "openPickerBackground":
            onOpenPickerBackground?()
        default:
            break
        }
    }
}
