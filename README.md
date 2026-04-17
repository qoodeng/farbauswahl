# Farbauswahl

A native macOS color picker for developers. 1MB, zero dependencies, instant launch.

Pick any color from your screen and get it in 8 formats — hex, RGB, HSL, HSB, OKLCH, Tailwind class, CSS variable, and SwiftUI literal. Dual foreground/background picking with WCAG 2.1 and APCA contrast checking. 30,000 named colors from [meodai/color-names](https://github.com/meodai/color-names).

## Install

```bash
git clone https://github.com/qoodeng/farbauswahl
cd farbauswahl
bash bundle.sh
open .build/Farbauswahl.app
```

Requires macOS 14+ and Xcode Command Line Tools (`xcode-select --install`).

### Download

Grab the zip from [Releases](https://github.com/qoodeng/farbauswahl/releases), unzip, drag to Applications. Then run once in Terminal:

```bash
xattr -cr /Applications/Farbauswahl.app
```

This clears the Gatekeeper quarantine flag (the app is unsigned). Then open normally.

For a release build:

```bash
bash bundle.sh release
```

## Usage

Click the eyedropper icon in the menu bar, or use keyboard shortcuts:

| Shortcut | Action |
|----------|--------|
| `⌘⇧C` | Pick foreground color |
| `⌘⇧V` | Pick background color |
| `⌘⇧X` | Swap foreground/background |
| `⌘C` | Copy foreground hex |
| `⌘1`–`⌘8` | Copy specific format |
| `⌘⌥C` | Copy all values as text |
| `⇧⌘⌥C` | Copy all values as JSON |
| `⌥S` | Save to library |
| `⌥F` | Apply contrast fix |
| `⌘Z` / `⌘⇧Z` | Undo / redo |
| `⌘,` | Preferences |
| `⌘Q` | Quit |

Click either swatch to pick from screen. Click the pencil icon to open the system color panel for manual input.

Right-click the menu bar icon for a full menu with Pick, Swap, Preferences, Launch at Login, and Quit.

Right-click any history or library swatch for Apply as Foreground, Apply as Background, Copy Hex, or Remove.

## Features

- **8 color formats** — Hex, RGB, HSL, HSB, OKLCH, Tailwind, CSS var, SwiftUI
- **Dual picking** — Foreground and background with swap
- **WCAG 2.1 contrast** — AA, AA Large, AAA with pass/fail badges
- **APCA contrast** — Lc value with Body, Large, Fine badges
- **Contrast fix** — One-click suggestion to meet AA, computed in OKLAB
- **30K color names** — Nearest match via Euclidean distance in OKLAB
- **Tailwind v3 matching** — Full default palette
- **Color history** — Last 20 picks with undo/redo
- **Color library** — Persistent storage at `~/.config/farbauswahl/library.json`
- **Display P3 output** — CSS `color(display-p3)` format
- **System color panel** — Manual color input via NSColorPanel
- **Font selector** — Ioskeley Mono, Geist Mono, or Helvetica in Preferences
- **Light/dark mode** — System, Light, or Dark in Preferences
- **URL scheme** — `farbauswahl://pick/foreground`, `set/foreground/FF0000`, etc.
- **Menu bar only** — No dock icon, always floating (configurable)
- **~1MB total** — 300K binary + 700K color names

## URL Scheme

```bash
open farbauswahl://pick/foreground
open farbauswahl://pick/background
open farbauswahl://swap
open farbauswahl://set/foreground/3B82F6
open farbauswahl://set/background/FFFFFF
open farbauswahl://copy/foreground
open farbauswahl://copy/background
open farbauswahl://copy/text
open farbauswahl://copy/json
```

## Architecture

Swift + AppKit shell with a WKWebView rendering an HTML/CSS/JS interface. The Swift layer handles color picking (NSColorSampler), global hotkeys (Carbon Events), clipboard, display profiles, and color math (OKLAB, WCAG, APCA). The HTML layer handles all rendering and user interaction, communicating with Swift via a bidirectional message bridge.

```
Sources/Farbauswahl/
  App/          — main.swift, AppDelegate, HotkeyManager, StatusBarController, Settings
  Color/        — ColorValue, ColorFormatter, ContrastChecker, ColorNames, TailwindColors
  Library/      — ColorHistory, ColorLibrary
  UI/           — PickerPanel (WKWebView window), PreferencesPanel
  Resources/    — app.html, preferences.html, colornames.csv
```

## Preferences

`⌘,` or right-click menu bar icon > Preferences

- **Launch at Login** — Register as a login item via SMAppService
- **Float Above Windows** — Keep picker window always on top
- **Auto-Copy on Pick** — Copy hex to clipboard immediately when picking
- **Hide While Picking** — Hide the window during color sampling
- **Mode** — System / Light / Dark appearance
- **Font** — Ioskeley Mono / Geist Mono / Helvetica

## Color Data

- Color names: [meodai/color-names](https://github.com/meodai/color-names) (30K entries, OKLAB nearest-match)
- Tailwind palette: Built-in v3 default colors (220 entries)
- Color science skill: [meodai/skill.color-expert](https://github.com/meodai/skill.color-expert)

## License

MIT
