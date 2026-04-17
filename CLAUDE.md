# Farbauswahl

Native macOS color picker for developers. Swift + AppKit + WKWebView.

## Build & Run

```bash
bash bundle.sh          # debug build
bash bundle.sh release  # release build
open .build/Farbauswahl.app
```

Requires macOS 14+ and Xcode CLI tools.

## Architecture

Swift backend + HTML/CSS/JS frontend rendered in a WKWebView.

- **Swift** handles: color picking (NSColorSampler), global hotkeys (Carbon Events), clipboard, display profiles, color math (OKLAB, WCAG, APCA), settings (UserDefaults), URL scheme, system color panel (NSColorPanel)
- **HTML** handles: all rendering and user interaction, communicating via `window.webkit.messageHandlers.farbauswahl.postMessage()`
- **Bridge direction**: JS posts `{action, ...data}` to Swift; Swift calls `evaluateJavaScript("updateUI({...})")` to push state

## File Layout

```
Sources/Farbauswahl/
  App/
    main.swift              — Entry point, NSApplication.run()
    AppDelegate.swift       — Central controller, wires all components
    HotkeyManager.swift     — Global Carbon hotkeys (⌘⇧C/V/X, ⌥S/F)
    StatusBarController.swift — Menu bar icon + right-click menu
    Settings.swift          — UserDefaults wrapper (launch, float, autocopy, hide, appearance, font)
  Color/
    ColorValue.swift        — Core model: sRGB, HSL, HSB, OKLAB, OKLCH, P3, hex
    ColorFormatter.swift    — 8 format outputs + FormattedColor aggregate
    ContrastChecker.swift   — WCAG 2.1 ratio + APCA Lc + auto-fix via OKLAB binary search
    ColorNames.swift        — 30K named colors, OKLAB nearest-match
    TailwindColors.swift    — Tailwind v3 palette (220 colors), OKLAB nearest-match
  Library/
    ColorHistory.swift      — In-memory undo/redo stack (max 50)
    ColorLibrary.swift      — Persistent JSON at ~/.config/farbauswahl/library.json
  UI/
    PickerPanel.swift       — Main window (NSWindow + WKWebView + key monitor + bridge)
    PreferencesPanel.swift  — Settings window (NSWindow + WKWebView)
  Resources/
    app.html                — Main UI (HTML/CSS/JS, ~400 lines)
    preferences.html        — Settings UI
    colornames.csv          — meodai/color-names dataset
```

## Key Patterns

- **Single updateUI() call**: Swift pushes all state as one JS object. No incremental updates.
- **LeakAvoidingMessageHandler**: Weak proxy breaks WKUserContentController retain cycle. Used in both panels.
- **NSEvent.addLocalMonitorForEvents**: Intercepts ⌘C, ⌘Z, ⌘Q, ⌘1-8, ⌘, inside the WKWebView (which eats keyDown events).
- **pageReady + pendingUpdate**: Defers JS calls until HTML finishes loading.
- **resizeToFitContent()**: Measures `document.body.scrollHeight` and adjusts window height.
- **hasBeenPositioned**: Window centers on first show only, stays where user puts it.

## Color Math

- All colors normalized to sRGB on pick via `NSColor.usingColorSpace(.sRGB)`
- ΔE computed as Euclidean distance in OKLAB (fast, perceptually uniform)
- Contrast fix: binary search in OKLAB lightness, 32 iterations, converges on closest-to-original that meets 4.5:1
- APCA uses simplified 0.1.9 G4g exponents with soft clamp

## Settings Persistence

- `UserDefaults` via `Settings.shared`
- Library: JSON at `~/.config/farbauswahl/library.json`
- Last-picked colors: `UserDefaults` keys `lastForeground`, `lastBackground`

## CSS Theming

- Light mode is the base CSS; dark mode via `@media (prefers-color-scheme: dark)`
- Swift overrides via `NSAppearance` when user selects Light/Dark in preferences
- Font switching via body classes: `font-geist`, `font-helvetica` (default is Ioskeley Mono)
- Swiss mode CSS still present for Helvetica bold lowercase via `.swiss` class
- Fully monochrome UI — no chromatic colors except picked swatches

## Testing

```bash
pkill -f Farbauswahl; bash bundle.sh && open .build/Farbauswahl.app
```

URL scheme test:
```bash
open farbauswahl://set/foreground/FF0000
open farbauswahl://pick/foreground
```
