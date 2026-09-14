#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIGURATION="${1:-release}"
echo "==> Building xBar (${CONFIGURATION})..."

cd "${ROOT_DIR}"

SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
SWIFT_EXEC="${ROOT_DIR}/scripts/swiftc-wrapper" \
swift build -c "${CONFIGURATION}"

if [[ "${CONFIGURATION}" == "release" ]]; then
    PRODUCT_DIR="${ROOT_DIR}/.build/out/Products/Release"
else
    PRODUCT_DIR="${ROOT_DIR}/.build/out/Products/Debug"
fi

EXECUTABLE="${PRODUCT_DIR}/xBar"
if [[ ! -f "${EXECUTABLE}" ]]; then
    echo "Error: Executable not found at ${EXECUTABLE}"
    exit 1
fi

DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/xBar.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "==> Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}" "${RESOURCES}"

# Copy executable
cp -p "${EXECUTABLE}" "${MACOS}/xBar"

# Create PkgInfo
echo -n "APPL????" > "${CONTENTS}/PkgInfo"

# Create Info.plist
cat << 'EOF' > "${CONTENTS}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>xBar</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.xera.xbar</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>xBar</string>
	<key>CFBundleDisplayName</key>
	<string>xBar</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2026 xBar. All rights reserved.</string>
	<key>NSSupportsAutomaticGraphicsSwitching</key>
	<true/>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>com.xera.xbar</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>xbar</string>
				<string>xmenubar</string>
			</array>
		</dict>
	</array>
	<key>XBarDonateURL</key>
	<string>https://github.com/XERA-2011/sponsor</string>
	<key>XBarRepositoryURL</key>
	<string>https://github.com/XERA-2011/x-bar</string>
	<key>XBarSkyLightFrameworkPath</key>
	<string>/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight</string>
	<key>XMenuBarDonateURL</key>
	<string>https://github.com/XERA-2011/sponsor</string>
	<key>XMenuBarRepositoryURL</key>
	<string>https://github.com/XERA-2011/x-bar</string>
	<key>XMenuBarSkyLightFrameworkPath</key>
	<string>/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight</string>
</dict>
</plist>
EOF

# Copy Documentation & Assets (from xBar or fallback XMenuBar during migration)
SOURCE_DIR="${ROOT_DIR}/xBar"
if [[ ! -d "${SOURCE_DIR}" ]]; then
    SOURCE_DIR="${ROOT_DIR}/XMenuBar"
fi

cp -p "${SOURCE_DIR}/Resources/Acknowledgements.md" "${RESOURCES}/"
cp -p "${SOURCE_DIR}/Resources/Localizable.xcstrings" "${RESOURCES}/"


# Copy all png assets directly into Resources for NSImage(named:) lookup
while IFS= read -r png; do
    filename="$(basename "$png")"
    name="${filename%.*}"
    cp -p "$png" "${RESOURCES}/${filename}"
    cp -p "$png" "${RESOURCES}/${name}@2x.png"
done < <(find "${SOURCE_DIR}/Resources/Assets.xcassets" -name "*.png")

# Copy AppIcon.icns
if [[ -f "${SOURCE_DIR}/Resources/AppIcon.icns" ]]; then
    cp -p "${SOURCE_DIR}/Resources/AppIcon.icns" "${RESOURCES}/AppIcon.icns"
elif [[ -f "/tmp/AppIcon.icns" ]]; then
    cp -p /tmp/AppIcon.icns "${RESOURCES}/AppIcon.icns"
fi

# Ad-hoc codesign
echo "==> Signing ${APP_BUNDLE}..."
codesign --force --deep -s - --identifier "com.xera.xbar" "${APP_BUNDLE}"

echo "==> Successfully created ${APP_BUNDLE}"
ls -lh "${APP_BUNDLE}/Contents/MacOS/xBar"
