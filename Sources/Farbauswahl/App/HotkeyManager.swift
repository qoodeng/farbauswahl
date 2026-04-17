import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    enum Action {
        case pickForeground  // ⌘⇧C
        case pickBackground  // ⌘⇧V
        case swap            // ⌘⇧X
        case save            // ⌥S
        case applyFix        // ⌥F
    }

    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private let onAction: (Action) -> Void

    init(onAction: @escaping (Action) -> Void) {
        self.onAction = onAction
        registerHotkeys()
    }

    deinit {
        hotKeyRefs.forEach { UnregisterEventHotKey($0) }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    private func registerHotkeys() {
        let cmdShift = UInt32(cmdKey | shiftKey)
        let optOnly = UInt32(optionKey)

        let keys: [(UInt32, UInt32, UInt32)] = [
            (8,  cmdShift, 1),  // ⌘⇧C pick fg
            (9,  cmdShift, 2),  // ⌘⇧V pick bg
            (7,  cmdShift, 3),  // ⌘⇧X swap
            (1,  optOnly,  4),  // ⌥S save
            (3,  optOnly,  5),  // ⌥F apply fix
        ]

        for (keyCode, mods, id) in keys {
            let hotKeyID = EventHotKeyID(signature: OSType(0x4642_4100 + id), id: id)
            var hotKeyRef: EventHotKeyRef?
            RegisterEventHotKey(keyCode, mods, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
            if let ref = hotKeyRef { hotKeyRefs.append(ref) }
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, event, ctx -> OSStatus in
            guard let ctx, let event else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(ctx).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

            let action: Action
            switch hotKeyID.id {
            case 1: action = .pickForeground
            case 2: action = .pickBackground
            case 3: action = .swap
            case 4: action = .save
            case 5: action = .applyFix
            default: return OSStatus(eventNotHandledErr)
            }

            DispatchQueue.main.async { manager.onAction(action) }
            return noErr
        }, 1, &eventType, userData, &eventHandler)
    }
}
