#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_DIR="${BUILD_DIR}/Slotr.app"
DMG_PATH="${BUILD_DIR}/Slotr.dmg"
STAGING_DIR="/tmp/Slotr_DMG_Staging"

# Build app if not present
if [ ! -d "${APP_DIR}" ]; then
    echo "📦 Slotr.app not found, building..."
    bash "${SCRIPT_DIR}/build_app.sh"
fi

echo "📀 Preparing DMG staging directory..."
rm -rf "${STAGING_DIR}" "${DMG_PATH}"
mkdir -p "${STAGING_DIR}"

# Copy Slotr.app
cp -R "${APP_DIR}" "${STAGING_DIR}/"
xattr -cr "${STAGING_DIR}/Slotr.app" 2>/dev/null || true

# Create symlink to /Applications for standard drag-and-drop installer
ln -s /Applications "${STAGING_DIR}/Applications"

# Add Quick Start note
cat << 'EOF' > "${STAGING_DIR}/INSTALLATION.txt"
Slotr — Window Snapping & Unlimited Workspace Layouts

To install:
1. Drag Slotr into the Applications folder.
2. Open Slotr from Applications (or Spotlight).
3. On first launch, grant Accessibility permission when prompted in:
   System Settings > Privacy & Security > Accessibility.
4. Save and recall as many workspace layouts as you need. Keyboard shortcuts are available for the first eight slots.

Global Hotkeys:
- Recall Slots 1..8:  Control + Option + 1..8
- Save to Slots 1..8: Control + Option + Shift + 1..8
- Snap Left Half:     Control + Option + Left Arrow
- Snap Right Half:    Control + Option + Right Arrow
- Maximize:           Control + Option + Up Arrow / Return
- Restore Size:       Control + Option + Down Arrow
EOF

echo "💿 Creating DMG with hdiutil..."
hdiutil create \
    -volname "Slotr" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

echo "🔏 Signing DMG..."
codesign -s - --force "${DMG_PATH}"

rm -rf "${STAGING_DIR}"
echo "🎉 DMG successfully created at ${DMG_PATH} ($(du -h "${DMG_PATH}" | cut -f1))"
