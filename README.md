# Hidden Icons

**A featherweight menu bar hider for macOS.** Hide the menu bar icons you don't need with one click. Bring them back with one click.

Hidden Icons is an open-source alternative to [Hidden Bar](https://github.com/dwarvesf/hidden) built around a single goal: the smallest possible memory footprint.

| | Hidden Icons | Hidden Bar |
|---|---|---|
| Physical memory footprint | **~11 MB** | ~300 MB, as reported by users |
| App bundle size | ~0.3 MB (56 KB zipped) | — |
| Frameworks loaded | AppKit, Foundation | SwiftUI, Combine, … |
| Permissions required | none | none |

*Footprint measured with `footprint` right after launch on macOS 26 (Apple Silicon). Activity Monitor's "Memory" column shows a similar value.*

## Features

- **One-click hide/show** — click the chevron and everything to its left slides out of sight; click again and it's back.
- **⌘-drag to arrange** — hold ⌘ and place the chevron to the right of the icons you want hidden, exactly like Apple's own menu bar icons. macOS remembers the position across launches.
- **Launch at login** — toggle in the right-click menu.
- **Auto-collapse** — optionally re-hides the bar 30 seconds after expanding, and waits while your cursor rests on the menu bar.
- **Start collapsed** — optionally hide the icons automatically at launch.
- **No permissions, no tracking** — the app doesn't monitor input, doesn't touch other apps, and has no network access. The sandbox keeps it that way.

## Install

Grab the latest build from **[hiddenicons.jakub.gradzewi.cz](https://hiddenicons.jakub.gradzewi.cz)** — the page includes a step-by-step first-launch guide (the app is unsigned, so Gatekeeper asks for a one-time confirmation).

Prefer building it yourself? See below.

## Build from source

Requirements: Xcode 26+ and macOS 14 or newer to run.

```bash
git clone https://github.com/TrueJacobG/hiddenicons.git
cd hiddenicons
open app/hiddenicons/hiddenicons.xcodeproj
# ⌘R
```

Or from the command line:

```bash
xcodebuild -project app/hiddenicons/hiddenicons.xcodeproj \
  -scheme hiddenicons -configuration Release build
```

> If you sign builds locally without a paid Apple Developer account, ad-hoc signing works fine:
> `xcodebuild ... CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=`

## Package a release

`scripts/package.sh` builds the Release configuration (universal binary, ad-hoc signed) and zips it:

```bash
scripts/package.sh            # → hiddenicons.zip next to the script
scripts/package.sh --serve    # also copies it into the webpage's public/ folder
```

## How it works

Two status items, public APIs only. The user sees one chevron; right next to it sits an invisible separator item (a few points wide, no icon). Collapsing inflates the separator's length to roughly twice the widest attached display (bounded by the 10,000pt `NSStatusItem` maximum), which pushes everything to its left off the screen. The chevron sits to the separator's right and is never resized, so it always stays visible and one more click brings everything back. Because macOS gives no control over where new status items are inserted, the app measures both items shortly after launch and assigns the roles by actual position — the left one becomes the separator.

Keep the chevron to the right of the icons you want hidden (⌘-drag to arrange, exactly like Apple's own icons). If an item is ⌘-dragged off the bar, macOS remembers that via the items' `autosaveName`; the app makes both items visible again on every launch so it can never become unreachable.

## Why it stays small

- **Pure AppKit** — no SwiftUI, no Combine, no storyboards. The process never loads those frameworks.
- **No windows** — everything lives in two status items; there is no settings window.
- **Event-driven** — zero polling. The only timer in the process runs while the bar is expanded and auto-collapse is enabled.
- **Almost no assets** — the status icons are system SF Symbols (or nothing at all); the asset catalog holds just the app icon.

## Project structure

```
app/hiddenicons/          Xcode project + sources
  hiddenicons/
    main.swift            AppKit bootstrap (no SwiftUI lifecycle)
    AppDelegate.swift     Launch behavior
    MenuBarController.swift  The two status items + hide/show logic
    Preferences.swift     The two toggles (UserDefaults)
    LoginItem.swift       SMAppService "launch at login" wrapper
scripts/
  package.sh              Build + zip a release
  make-icon.swift         Regenerates the app icon
webpage/                  Landing page (lives in its own private repository)
```

## License

[MIT](LICENSE) © Jakub Gradzewicz
