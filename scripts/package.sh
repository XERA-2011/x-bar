#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/xBar.app"
DMG_PATH="${DIST_DIR}/xBar.dmg"
ZIP_PATH="${DIST_DIR}/xBar.zip"
CHECKSUMS_PATH="${DIST_DIR}/SHA256SUMS.txt"

echo "==> Packaging xBar..."

# 1. Build release app if not already built
if [[ ! -d "${APP_BUNDLE}" ]]; then
    echo "==> Application bundle not found. Building release app first..."
    "${SCRIPT_DIR}/build-app.sh" release
fi

cd "${ROOT_DIR}"

# 2. Package ZIP using ditto (preserves macOS metadata and resource forks)
echo "==> Creating ${ZIP_PATH}..."
rm -f "${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

# 3. Package DMG
echo "==> Creating ${DMG_PATH}..."
rm -f "${DMG_PATH}"

STAGING_DIR="$(mktemp -d -t xbar_dmg_staging_XXXXXX)"
trap 'rm -rf "${STAGING_DIR}"' EXIT

cp -R "${APP_BUNDLE}" "${STAGING_DIR}/xBar.app"
ln -s /Applications "${STAGING_DIR}/Applications"

CREATE_DMG="${ROOT_DIR}/tools/create-dmg/create-dmg"
BG_IMAGE="${ROOT_DIR}/assets/dmg-background@2x.png"

if [[ -x "${CREATE_DMG}" ]] || command -v create-dmg >/dev/null 2>&1; then
    CMD="${CREATE_DMG}"
    if [[ ! -x "${CMD}" ]]; then
        CMD="create-dmg"
    fi
    echo "==> Using create-dmg for styled disk image..."
    BG_ARGS=()
    if [[ -f "${BG_IMAGE}" ]]; then
        BG_ARGS=(--background "${BG_IMAGE}")
    fi
    "${CMD}" \
        --volname "xBar" \
        "${BG_ARGS[@]}" \
        --window-pos 200 120 \
        --window-size 582 300 \
        --icon-size 100 \
        --hide-extension "xBar.app" \
        --icon "xBar.app" 150 150 \
        --icon "Applications" 436 150 \
        --hdiutil-retries 10 \
        "${DMG_PATH}" \
        "${STAGING_DIR}" || {
            echo "Warning: create-dmg failed, falling back to native hdiutil..."
            rm -f "${DMG_PATH}"
            hdiutil create -volname "xBar" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_PATH}"
        }
else
    echo "==> create-dmg not found; using native macOS hdiutil..."
    hdiutil create -volname "xBar" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_PATH}"
fi

# Optional: Code sign the DMG if identity is available, otherwise ad-hoc sign
if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
    echo "==> Signing DMG with identity: ${CODE_SIGN_IDENTITY}..."
    codesign --force --sign "${CODE_SIGN_IDENTITY}" "${DMG_PATH}"
else
    echo "==> Ad-hoc signing DMG..."
    codesign --force -s - "${DMG_PATH}" 2>/dev/null || true
fi

# 4. Generate SHA256 checksums
echo "==> Generating SHA256 checksums..."
cd "${DIST_DIR}"
shasum -a 256 "xBar.dmg" "xBar.zip" > "${CHECKSUMS_PATH}"

echo "==> Packaging complete!"
echo "----------------------------------------"
ls -lh "${DMG_PATH}" "${ZIP_PATH}" "${CHECKSUMS_PATH}"
echo "----------------------------------------"
cat "${CHECKSUMS_PATH}"
echo "----------------------------------------"
