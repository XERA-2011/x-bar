#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"

TAG="${1:-}"

if [[ -z "${TAG}" ]]; then
    echo "Usage: ./scripts/release.sh <tag-name>"
    echo "Example: ./scripts/release.sh v1.0.0"
    exit 1
fi

cd "${ROOT_DIR}"

# 1. Package release artifacts
"${SCRIPT_DIR}/package.sh"

# 2. Check if GitHub CLI is available
if ! command -v gh >/dev/null 2>&1; then
    echo "Error: GitHub CLI (gh) is not installed."
    echo "Install it via 'brew install gh' or manually upload the files in dist/ to GitHub Releases."
    exit 1
fi

# 3. Create or update release
echo "==> Publishing release ${TAG} to GitHub..."
gh release create "${TAG}" \
    "${DIST_DIR}/xBar.dmg" \
    "${DIST_DIR}/xBar.zip" \
    "${DIST_DIR}/SHA256SUMS.txt" \
    --title "${TAG}" \
    --generate-notes

echo "==> Release ${TAG} published successfully!"
