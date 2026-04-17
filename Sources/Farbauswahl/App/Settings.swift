import Foundation
import ServiceManagement

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private init() {}

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set {
            defaults.set(newValue, forKey: "launchAtLogin")
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    FileHandle.standardError.write(Data("[Farbauswahl] Login item error: \(error)\n".utf8))
                }
            }
        }
    }

    var floatAboveWindows: Bool {
        get { defaults.object(forKey: "floatAboveWindows") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "floatAboveWindows") }
    }

    var autoCopyOnPick: Bool {
        get { defaults.bool(forKey: "autoCopyOnPick") }
        set { defaults.set(newValue, forKey: "autoCopyOnPick") }
    }

    var hideWhilePicking: Bool {
        get { defaults.bool(forKey: "hideWhilePicking") }
        set { defaults.set(newValue, forKey: "hideWhilePicking") }
    }

    var lastForeground: String? {
        get { defaults.string(forKey: "lastForeground") }
        set { defaults.set(newValue, forKey: "lastForeground") }
    }

    var lastBackground: String? {
        get { defaults.string(forKey: "lastBackground") }
        set { defaults.set(newValue, forKey: "lastBackground") }
    }

    /// "ioskeley", "geist", or "helvetica"
    var font: String {
        get { defaults.string(forKey: "font") ?? "ioskeley" }
        set {
            defaults.set(newValue, forKey: "font")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// "system", "light", or "dark"
    var appearance: String {
        get { defaults.string(forKey: "appearance") ?? "system" }
        set {
            defaults.set(newValue, forKey: "appearance")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
}
