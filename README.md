# Slotr

Slotr is a native macOS app for snapping windows and saving unlimited desktop workspace layouts. It is built with Swift, SwiftUI, AppKit, and macOS Accessibility APIs.

Requires **macOS 13 or later**.

## Features

### Snap and tile windows

- Snap the target window to halves, quarters, thirds, two-thirds, center, or the full usable display area.
- Uses the selected window's display and respects the Dock, menu bar, and configured window gap.
- Remembers each window's original frame. Selecting the same snap zone again toggles it back; use Restore to return to its original position and size.
- Includes a Quick Snap Studio with a visual layout preview.

### Save and recall workspaces

- Save as many desktop layouts as you need, including each window's app and position.
- Search saved layouts by name or app, drag to reorder, and hover over a layout to see its saved windows, date, and display resolution.
- Choose a target window from the dashboard's **Select Target Window** strip, then snap or restore that window.
- Recall a layout with one click. If **Launch closed apps when recalling a layout** is enabled in Settings, Slotr opens saved apps that are not running.
- Layouts are stored in UserDefaults and in `~/Library/Application Support/Slotr/slots.json`.

### Menu bar and keyboard shortcuts

Slotr's menu bar popover provides quick access to saved workspaces and window snapping. Keyboard shortcuts are available for the first eight slot IDs; additional layouts can be saved and recalled from the dashboard or menu bar.

| Shortcut | Action |
| --- | --- |
| `⌃⌥1` through `⌃⌥8` | Recall slot 1 through 8 |
| `⌃⌥⇧1` through `⌃⌥⇧8` | Save the current layout to slot 1 through 8 |
| `⌃⌥←` / `⌃⌥→` | Snap left / right half |
| `⌃⌥↑` or `⌃⌥↩` | Maximize the target window |
| `⌃⌥↓` | Restore the original window frame |
| `⌃⌥C` | Center the target window |

## Installation and permissions

To install a release DMG, open `build/Slotr.dmg` and drag `Slotr.app` into Applications. Then launch Slotr.

Slotr needs macOS Accessibility permission to read and move other apps' windows. If permission is missing, Slotr opens the relevant System Settings page. Enable Slotr under **Privacy & Security → Accessibility** (the permission may be grouped under **Device Control & Data Access** on some macOS versions). Slotr checks the existing permission and does not ask you to enable it again when macOS already trusts the app.

Builds from this repository are ad-hoc signed. macOS may treat a new build as a different Accessibility identity and ask for permission again; a stable Developer ID signing identity is needed to avoid that behavior across builds.

## Build from source

```bash
# Build the native app bundle
make build

# Create build/Slotr.dmg
make dmg

# Build and launch the app
make run
```

## About

Slotr is developed by **Suriya Prakhash Deenadayalan** and is distributed under the [MIT License](LICENSE). See [www.slotr.suriyaprakhash.com](https://www.slotr.suriyaprakhash.com) for more information and updates.

## Project layout

- `Sources/Slotr/Managers/` — accessibility, desktop/Spaces discovery, window positioning, saved layouts, and shortcuts.
- `Sources/Slotr/Models/` — snap zones, layout models, and window history.
- `Sources/Slotr/UI/` — dashboard, menu bar, snap controls, and HUD.
- `Resources/` — app metadata and entitlements.
- `Scripts/` — icon generation, app bundling, and DMG packaging.
