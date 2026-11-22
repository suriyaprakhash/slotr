# Publishing Slotr to the Mac App Store (and Notarized DMG)

This guide covers everything required to distribute **Slotr** to the public, comparing **Mac App Store (MAS)** submission with **Direct Notarized DMG** distribution.

---

## 1. The Core Architectural Hurdle: Accessibility & App Sandbox

Before submitting to the Mac App Store, it is critical to understand Apple's security model for window managers:

1. **Mac App Store Guideline 2.4.5 (App Sandbox)**:
   - Every application on the Mac App Store **must** have App Sandbox enabled (`com.apple.security.app-sandbox = true`).
2. **Accessibility API (`AXUIElement`)**:
   - Window managers (Magnet, Rectangle, Slotr) use macOS Accessibility APIs to query and modify windows belonging to *other* process IDs (`kAXPositionAttribute`, `kAXSizeAttribute`).
   - Under a strict App Sandbox, cross-process Accessibility queries are blocked unless specific entitlements and permissions are granted.
3. **How Existing Store Apps Handle This**:
   - Apps like **Magnet**, **Moom**, and **BetterSnapTool** were either approved before sandboxing became strictly enforced, or use Apple-reviewed temporary exception entitlements with extensive reviewer documentation.
   - Modern open-source window managers (e.g. **Rectangle**, **Raycast**, **Aerospace**) choose **Direct Notarized Distribution (DMG)** because it provides full, unrestricted window manipulation and avoids sandbox rejections.

---

## 2. Step-by-Step: Mac App Store Submission

### Step 1: Apple Developer Account
- Enroll in the [Apple Developer Program](https://developer.apple.com/programs/) ($99 USD / year).
- If registering as an organization, you will need a D-U-N-S Number from Dun & Bradstreet.

### Step 2: Configure App ID & Entitlements
1. In the [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list), create an App ID:
   - **Bundle ID**: `com.yourcompany.slotr` (matching `Info.plist`)
   - Enable **App Sandbox**.
2. Update `Slotr.entitlements` for App Store mode:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>com.apple.security.app-sandbox</key>
       <true/>
       <key>com.apple.security.files.user-selected.read-write</key>
       <true/>
       <key>com.apple.security.temporary-exception.apple-events</key>
       <array>
           <string>com.apple.finder</string>
           <string>com.apple.systemevents</string>
       </array>
   </dict>
   </plist>
   ```

### Step 3: Create App Store Connect Record
1. Go to [App Store Connect](https://appstoreconnect.apple.com) > **My Apps** > **+** (New App).
2. Choose **macOS**.
3. Fill in:
   - **Name**: `Slotr — Window Manager & Layouts`
   - **Primary Language**: English
   - **Bundle ID**: Select your registered App ID
   - **SKU**: `slotr-01`
   - **Category**: `Utilities` (Primary) and `Productivity` (Secondary).

### Step 4: Prepare Listing Assets
- **App Icon**: 1024×1024 PNG (no transparency / alpha channel).
- **Screenshots**: At least 3 screenshots showing:
  1. Window Snapping in action (Left/Right halves, thirds, quarters).
  2. The 8 Layout Slots manager with active apps.
  3. Menu Bar popover and keyboard shortcuts.
  - Resolutions accepted: `2880 × 1800`, `1440 × 900`, `2560 × 1600`, or `1280 × 800`.
- **Privacy Policy**: A public URL stating your privacy practices.
  - Note: Slotr is 100% on-device and collects **zero user data**. In the App Privacy Nutrition Label, you select **"Data Not Collected"**.
- **Support URL & Marketing URL**.

### Step 5: Build and Sign the `.pkg` for the App Store
To submit to the App Store, macOS requires an installer package (`.pkg`) signed with your **Apple Distribution** certificate:

```bash
# 1. Sign the .app bundle with Apple Distribution certificate
codesign -s "Apple Distribution: Your Company Name (TEAM_ID)" \
    --force --deep --options runtime \
    --entitlements Resources/Slotr.entitlements \
    build/Slotr.app

# 2. Package into a signed .pkg
productbuild --component build/Slotr.app /Applications \
    --sign "3rd Party Mac Developer Installer: Your Company Name (TEAM_ID)" \
    build/Slotr.pkg
```

### Step 6: Upload to App Store Connect
Upload the `.pkg` using Apple's official **Transporter** app (available free in the Mac App Store) or command line:
```bash
xcrun altool --upload-app -f build/Slotr.pkg -t macos -u "your-apple-id@email.com" -p "app-specific-password"
```

### Step 7: App Review Notes (Crucial!)
Because Slotr requires Accessibility permissions to move windows, you **must** provide clear guidance to the Apple review team in the **Review Notes** section:
> *"Slotr is a window management utility. On first launch, the app prompts the user to enable Accessibility in System Settings > Privacy & Security > Accessibility. Once enabled, users can snap windows and recall saved layout slots. A demo screencast link is provided below demonstrating this workflow."*

Attach a 30-second screen recording showing:
1. Granting Accessibility in System Settings.
2. Snapping a window.
3. Saving and recalling a layout slot.

---

## 3. The Recommended Alternative: Direct Notarized DMG Distribution

Many developers distribute window managers directly via **Notarized DMG** (e.g. download from website, GitHub Releases, or Gumroad) because:
- **No Sandboxing Restrictions**: Full native performance and compatibility with all third-party apps.
- **Instant Updates**: Push updates directly to users without waiting for Apple App Review.
- **Zero Revenue Cut**: 100% of sales or donations stay with you.
- **Gatekeeper Safe**: When notarized with an Apple Developer ID, macOS opens the DMG seamlessly with zero security warnings.

### How to Notarize the DMG:

1. Sign with your **Developer ID Application** certificate:
   ```bash
   codesign -s "Developer ID Application: Your Name (TEAM_ID)" \
       --force --deep --options runtime \
       --entitlements Resources/Slotr.entitlements \
       build/Slotr.app
   
   # Re-package the DMG
   bash Scripts/package_dmg.sh
   
   # Sign the DMG
   codesign -s "Developer ID Application: Your Name (TEAM_ID)" build/Slotr.dmg
   ```

2. Submit to Apple Notary Service:
   ```bash
   xcrun notarytool submit build/Slotr.dmg \
       --apple-id "your-apple-id@email.com" \
       --password "app-specific-password" \
       --team-id "TEAM_ID" \
       --wait
   ```

3. Staple the Notarization Ticket to the DMG:
   ```bash
   xcrun stapler staple build/Slotr.dmg
   ```

Once stapled, anyone on macOS can download and open `Slotr.dmg` instantly!

---

## Summary Comparison

| Capability | Mac App Store (MAS) | Direct Notarized DMG |
| :--- | :--- | :--- |
| **User Trust & Discovery** | High (search in App Store) | Direct website / GitHub / Gumroad |
| **Sandboxing Requirement** | Mandatory (`com.apple.security.app-sandbox = true`) | Not required (Hardened Runtime only) |
| **Window Manipulation** | Subject to App Review scrutiny | 100% unrestricted native control |
| **Annual Fee** | $99/year (Apple Developer) | $99/year (for Developer ID certificate) |
| **Gatekeeper Experience** | Seamless | Seamless (when notarized & stapled) |
| **Review Turnaround** | 24 - 48 hours per update | Instantaneous deployment |
