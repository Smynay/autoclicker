# 🖱️ AutoClicker for macOS

[![Release](https://img.shields.io/github/v/release/Smynay/autoclicker)](https://github.com/Smynay/autoclicker/releases)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2012%2B-black)]()
[![Language](https://img.shields.io/badge/language-Swift-orange)]()

**Auto clicker for macOS that lives in the menu bar.** One hotkey (`⌥⌘K`) starts and stops mouse auto-clicking anywhere on the system — including fullscreen apps, games, and Chromium browsers. Pure Swift, zero dependencies, one built binary, nothing else.

<p align="center">
  <img src="docs/menu.png" alt="AutoClicker menu-bar popup: Run, click speed selector (1–50 clicks per second), spread mode, Quit" width="380" />
</p>

## Download

Grab the zip from the [latest release](https://github.com/Smynay/autoclicker/releases/latest), unzip, run `AutoClicker.app`.

On the first launch macOS asks for *Accessibility* permission once — the app opens the correct System Settings pane automatically. mac staying out of your way: no Dock icon, no windows, no settings dialog — just a 🖱 icon in the menu bar.

## What it does

| | |
|---|---|
| 🖱 **Click anywhere** | Clicks always happen at the current **cursor position** — park the mouse over the target and turn on |
| ⌥⌘K | Global hotkey toggles the clicker on/off |
| 1 – 50 clicks per second | Pick speed from a check-marked menu |
| 🎲 **Spread mode** | Random intervals (±50 % jitter) for a human-like cadence |
| 🖨 **Custom icons** | Menu-bar template + app `.icns`, both drawn 100 % in code 

## Usage

| | |
|---|---|
| `⌥⌘K` | Start / stop auto-clicking |
| Menu → **Click speed** | The clicked rate |
| Menu → **Spread mode** | Randomized intervals |
| Menu → **Quit** | Stop and exit |

## Build from source

```bash
./build.sh              # macOS 12+, Xcode Command Line Tools
open build/AutoClicker.app
```

Build pipeline: compiles the app (`src/AutoclickerApp.swift`), draws and embeds icons (`src/IconGen.swift` → iconset → `.icns`), assembles the `.app` bundle, signs it (stable identity if available) and, in `release` mode, zips the distribution into `build/dist/`.

```bash
./build.sh 1.2.0 release
```

## Releases & CI

Pushing a tag (`git tag v1.2.0 && git push --tags v1.2.0`) triggers the GitHub Actions pipeline: a macOS runner builds the app and attaches the zip to the release automatically.

For CI builds to keep their Accessibility grant across updates, define repo secrets **Settings → Secrets**:
- `SIGNING_CERT_P12` — base64 of the signing identity exported as PKCS#12;
- `SIGNING_CERT_PASSWORD` — its passphrase.

Without secrets the pipeline falls back to ad-hoc signing - fine for new installs, an update may need one extra permission toggle.

## Why Accessibility is required

macOS allows synthetic mouse/keyboard events only to apps trusted under *Accessibility*. On the first launch (or **after a rebuild** with changed signature) AutoClicker opens the right pane and shows a dialog:

```
System Settings → Privacy & Security → Accessibility → ✅ AutoClicker
```

The menu also includes a dedicated **Grant Accessibility access…** shortcut that jumps straight to the correct pane.

## How it works

| Part | Implementation |
|---|---|
| Scheduling | Dedicated thread, absolute-time deadline loop — the next tick is scheduled from the previous *target* time, so system-hurry overhead never accumulates |
| Click dispatch | `CGEvent` synthesized events: `mouseMoved` + `leftMouseDown` + 30 ms-delayed `leftMouseUp`, posted via `.cghidEventTap` with the `.hidSystemState` source |
| Hotkey | Carbon `RegisterEventHotKey` |
| Coordinates | Cursor location rounded to a whole pixel — macOS fractional coordinates otherwise make the cursor drift over time |
| Packaging | The `.app` bundle is assembled by hand: executable, `Info.plist` with `LSUIElement` (menu-bar-only app), iconset → `icns`, strict code signature check |

## macOS event-dispatch quirks (worth knowing if you fork)

- Unsigned builds get their synthetic clicks silently dropped — always codesign (`build.sh` verifies with `codesign --verify --strict` and refuses to ship a broken bundle).
- Chromium ignores repeated mouse-downs at the same integer position unless a fresh `mouseMoved` immediately precedes them.
- Down/up events must carry the *same* `mouseEventClickState` value, or Chromium splits one click into drag state.
- Accessibility grant is cached per *code signature* — with ad-hoc signing each rebuild changes the signature and permission disappears without a warning.

## File map

```
src/AutoclickerApp.swift    main app: menu bar, hotkey, click engine
src/IconGen.swift           vector icon generator (menu-bar + .icns pipeline)
build.sh                    full build pipeline → build/AutoClicker.app
test/counter.html           local click counter for manual CPS measurement
test/mousectl.swift         CLI helper: simulate mouse moves/clicks and ⌥⌘K
test/atomic.mjs             Playwright-based end-to-end verification
```

## License

MIT — see [LICENSE](LICENSE).
