# Slotr ◧

**Slotr** is a high-performance native macOS app that brings intelligent window snapping and **8 instant-recall workspace layout slots** to your Mac.

Built with native Swift, AppKit, SwiftUI, and macOS Accessibility APIs.

---

## ✨ Features

- **Intuitive Window Snapping**:
  - Snap active windows to **Halves** (Left, Right, Top, Bottom)
  - **Full Screen / Maximize** and **Center Window**
  - **Quarters** (Top-Left, Top-Right, Bottom-Left, Bottom-Right)
  - **Thirds** (Left 1/3, Center 1/3, Right 1/3, Left 2/3, Right 2/3)
  - Multi-display awareness (automatically computes snap boundaries based on each monitor's usable area excluding the Dock and Menu Bar).

- **Snap Memory & Undo**:
  - Remembers the original pre-snap position and size of every window.
  - Clicking the same snap action a second time toggles the window back to its original size.
  - Dedicated **Restore Original Size & Position** button and `⌃⌥↓` shortcut.

- **8 Workspace Layout Slots**:
  - Save full desktop arrangements of all running apps and their window coordinates into 8 independent slots.
  - Instantly recall and reposition all windows simultaneously with a single click or keyboard shortcut.
  - If a saved app isn't currently running when recalled, Slotr automatically launches it and restores its frame.
  - Rename slots (e.g., *"Coding & Terminal"*, *"Trading Dashboard"*, *"Social & Music"*).
  - Persisted automatically to `UserDefaults` and `~/Library/Application Support/Slotr/slots.json`.

- **Global Hotkeys**:
  - `⌃ ⌥ 1` to `⌃ ⌥ 8`: Instant Recall Slot 1 through 8.
  - `⌃ ⌥ ⇧ 1` to `⌃ ⌥ ⇧ 8`: Save Current Layout to Slot 1 through 8.
  - `⌃ ⌥ ←`: Snap Left Half.
  - `⌃ ⌥ →`: Snap Right Half.
  - `⌃ ⌥ ↑` or `⌃ ⌥ ↩`: Maximize Window.
  - `⌃ ⌥ ↓`: Restore Original Window Size & Position.
  - `⌃ ⌥ C`: Center Window.

- **Dual Mode UI**:
  - Full Interactive Dashboard window displaying all 8 slots side-by-side with snap controls.
  - Top Menu Bar extra with quick popover for rapid access.
  - Translucent on-screen HUD overlay showing feedback when snapping or recalling slots.

---

## 🚀 Quick Start & Installation

### Option 1: Install from DMG
1. Open `build/Slotr.dmg`.
2. Drag `Slotr.app` into your **Applications** folder.
3. Launch **Slotr**.
4. On first launch, grant Accessibility permission when prompted in:
   `System Settings > Privacy & Security > Accessibility`
   Turn the toggle **ON** for Slotr.
5. Slotr will automatically detect the permission and activate.

### Option 2: Build from Source
```bash
# Build the native app bundle
make build

# Package into a release DMG
make dmg

# Run the app directly
make run
```

---

## 🛠 Project Architecture

```
macsnap/
├── Package.swift                     # Swift Package Manager manifest
├── Sources/
│   └── Slotr/
│       ├── main.swift                # App entry point
│       ├── AppDelegate.swift         # Window & status bar controller
│       ├── Models/
│       │   ├── SnapZone.swift        # Geometric snap target definitions
│       │   ├── SavedLayout.swift     # Codable models for the 8 slots
│       │   └── WindowHistory.swift   # Pre-snap frame cache & toggle logic
│       ├── Managers/
│       │   ├── AccessibilityManager.swift # Permission checking & live observer
│       │   ├── WindowManager.swift   # AXUIElement window manipulation & screen math
│       │   ├── SlotManager.swift     # 8-slot persistence & instantaneous recall
│       │   └── HotkeyManager.swift   # Carbon global hotkeys
│       └── UI/
│           ├── MainDashboardView.swift # Full interactive dashboard window
│           ├── MenuBarView.swift     # Menu bar popover interface
│           ├── SlotCardView.swift    # Interactive card for each slot
│           ├── SnapGridButtons.swift # Grid of visual snap buttons
│           └── HUDOverlay.swift      # Floating translucent notification bezel
├── Scripts/
│   ├── generate_icons.sh             # Generates AppIcon.icns
│   ├── build_app.sh                  # Compiles native binary & creates .app bundle
│   └── package_dmg.sh                # Packages .app into Slotr.dmg
├── Resources/
│   ├── Info.plist                    # Bundle metadata
│   ├── Slotr.entitlements            # Security entitlements
│   └── AppIcon.icns                  # macOS application icon
├── Makefile                          # Build automation targets
├── MAC_APP_STORE_GUIDE.md            # Complete guide for Mac App Store publication
└── README.md
```

---

## 📦 What It Takes to Put Slotr on the Mac App Store

See the full guide in [MAC_APP_STORE_GUIDE.md](file:///Users/suriya/main/ws/github/macsnap/MAC_APP_STORE_GUIDE.md).
