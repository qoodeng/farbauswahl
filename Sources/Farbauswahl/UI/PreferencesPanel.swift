import AppKit
import WebKit

final class PreferencesPanel: NSWindow, WKNavigationDelegate, WKScriptMessageHandler {
    private let webView: WKWebView

    init() {
        let config = WKWebViewConfiguration()
        let userController = WKUserContentController()
        config.userContentController = userController

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 280, height: 370), configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 370),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )

        let leakAvoider = LeakAvoidingMessageHandler(delegate: self)
        userController.add(leakAvoider, name: "farbauswahl")
        title = "Preferences"
        contentView = webView
        isReleasedWhenClosed = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .windowBackgroundColor

        contentMinSize = NSSize(width: 280, height: 370)
        contentMaxSize = NSSize(width: 280, height: 370)

        webView.navigationDelegate = self
        loadHTML()
    }

    private func loadHTML() {
        guard let url = Bundle.module.url(forResource: "preferences", withExtension: "html") else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let s = Settings.shared
        let js = """
        loadSettings({
          launchAtLogin: \(s.launchAtLogin),
          floatAboveWindows: \(s.floatAboveWindows),
          autoCopyOnPick: \(s.autoCopyOnPick),
          hideWhilePicking: \(s.hideWhilePicking),
          appearance: "\(s.appearance)",
          font: "\(s.font)"
        });
        """
        webView.evaluateJavaScript(js)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        if action == "setSetting", let key = body["key"] as? String {
            if let value = body["value"] as? Bool {
                switch key {
                case "launchAtLogin": Settings.shared.launchAtLogin = value
                case "floatAboveWindows":
                    Settings.shared.floatAboveWindows = value
                    NotificationCenter.default.post(name: .settingsChanged, object: nil)
                case "autoCopyOnPick": Settings.shared.autoCopyOnPick = value
                case "hideWhilePicking": Settings.shared.hideWhilePicking = value
                default: break
                }
            } else if let value = body["value"] as? String {
                switch key {
                case "appearance": Settings.shared.appearance = value
                case "font": Settings.shared.font = value
                default: break
                }
            }
        }
    }

    func show() {
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}
