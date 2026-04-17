#!/bin/bash
set -e

BINARY_NAME="Farbauswahl"
APP_NAME="Farbauswahl"
CONFIG="${1:-debug}"
BUNDLE_DIR=".build/${APP_NAME}.app"
CONTENTS="${BUNDLE_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

# Build
if [ "$CONFIG" = "release" ]; then
  swift build -c release
else
  swift build
fi

# Clean old bundle
rm -rf "${BUNDLE_DIR}"

# Create bundle structure
mkdir -p "${MACOS}" "${RESOURCES}"

# Copy binary
cp ".build/${CONFIG}/${BINARY_NAME}" "${MACOS}/${APP_NAME}"

# Copy SPM resource bundle
cp -r .build/${CONFIG}/Farbauswahl_Farbauswahl.bundle "${RESOURCES}/" || { echo "ERROR: Resource bundle not found"; exit 1; }

# Write Info.plist
cat > "${CONTENTS}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.farbauswahl.app</string>
    <key>CFBundleName</key>
    <string>Farbauswahl</string>
    <key>CFBundleDisplayName</key>
    <string>Farbauswahl</string>
    <key>CFBundleExecutable</key>
    <string>Farbauswahl</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>Farbauswahl URL Scheme</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>farbauswahl</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Copy app icon
cp AppIcon.icns "${RESOURCES}/AppIcon.icns" 2>/dev/null || true

# Create PkgInfo
echo -n "APPL????" > "${CONTENTS}/PkgInfo"

# Code sign
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Christian Stephens (H45U5SB635)}"
codesign --force --deep --options runtime --sign "${IDENTITY}" "${BUNDLE_DIR}"

echo "Built: ${BUNDLE_DIR}"
echo "Run:   open ${BUNDLE_DIR}"
