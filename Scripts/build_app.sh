#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_DIR="${BUILD_DIR}/Slotr.app"
CLANG_CACHE="/tmp/clang-cache"

mkdir -p "${BUILD_DIR}" "${CLANG_CACHE}"

# Generate icons if missing
if [ ! -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]; then
    echo "📦 Icons missing, generating AppIcon.icns..."
    bash "${SCRIPT_DIR}/generate_icons.sh"
fi

echo "🚀 Compiling Slotr native binary..."

SWIFT_SOURCES=(
    "${PROJECT_DIR}/Sources/Slotr/Models/SnapZone.swift"
    "${PROJECT_DIR}/Sources/Slotr/Models/SavedLayout.swift"
    "${PROJECT_DIR}/Sources/Slotr/Models/WindowHistory.swift"
    "${PROJECT_DIR}/Sources/Slotr/Models/AppSettings.swift"
    "${PROJECT_DIR}/Sources/Slotr/Managers/AccessibilityManager.swift"
    "${PROJECT_DIR}/Sources/Slotr/Managers/WindowManager.swift"
    "${PROJECT_DIR}/Sources/Slotr/Managers/SlotManager.swift"
    "${PROJECT_DIR}/Sources/Slotr/Managers/DesktopManager.swift"
    "${PROJECT_DIR}/Sources/Slotr/Managers/HotkeyManager.swift"
    "${PROJECT_DIR}/Sources/Slotr/UI/DesignComponents.swift"
    "${PROJECT_DIR}/Sources/Slotr/UI/HUDOverlay.swift"
    "${PROJECT_DIR}/Sources/Slotr/UI/SnapGridButtons.swift"
    "${PROJECT_DIR}/Sources/Slotr/UI/SlotCardView.swift"
    "${PROJECT_DIR}/Sources/Slotr/UI/MenuBarView.swift"
    "${PROJECT_DIR}/Sources/Slotr/UI/DesktopCardView.swift"
    "${PROJECT_DIR}/Sources/Slotr/UI/MainDashboardView.swift"
    "${PROJECT_DIR}/Sources/Slotr/AppDelegate.swift"
    "${PROJECT_DIR}/Sources/Slotr/main.swift"
)

swiftc \
    -O \
    -module-cache-path "${CLANG_CACHE}" \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Carbon \
    -framework ServiceManagement \
    -target arm64-apple-macos13.0 \
    "${SWIFT_SOURCES[@]}" \
    -o "${BUILD_DIR}/Slotr_bin"

echo "📂 Assembling Slotr.app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

mv "${BUILD_DIR}/Slotr_bin" "${APP_DIR}/Contents/MacOS/Slotr"
chmod +x "${APP_DIR}/Contents/MacOS/Slotr"

cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
echo -n "APPLsltr" > "${APP_DIR}/Contents/PkgInfo"

echo "🔏 Signing application bundle (ad-hoc with hardened runtime)..."
xattr -cr "${APP_DIR}" 2>/dev/null || true
codesign \
    -s - \
    --force \
    --deep \
    --options runtime \
    --entitlements "${PROJECT_DIR}/Resources/Slotr.entitlements" \
    "${APP_DIR}"

codesign --verify --deep --strict "${APP_DIR}"
echo "✅ Slotr.app successfully built and verified at ${APP_DIR}"
