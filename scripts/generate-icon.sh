#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${ROOT_DIR}/xBar"
if [[ ! -d "${SOURCE_DIR}" ]]; then
    SOURCE_DIR="${ROOT_DIR}/XMenuBar"
fi
OUTPUT_ICNS="${SOURCE_DIR}/Resources/AppIcon.icns"
TMP_DIR="/tmp/xbar_icon_gen_$$"

mkdir -p "${TMP_DIR}/AppIcon.iconset"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "==> Rendering 1024x1024 base icon..."
BASE_PNG="${TMP_DIR}/base.png" \
swift -e '
import AppKit
import CoreGraphics

func createSquirclePath(rect: NSRect, radius: CGFloat) -> CGPath {
    return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func createCapsulePath(rect: NSRect) -> CGPath {
    let radius = rect.height / 2.0
    return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("No cgContext") }

let iconRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircleR: CGFloat = 185
let squircle = createSquirclePath(rect: iconRect, radius: squircleR)

// Base Squircle Shadow & Fill
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: NSColor(white: 0, alpha: 0.20).cgColor)
ctx.setFillColor(NSColor.white.cgColor)
ctx.addPath(squircle)
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle)
ctx.clip()

// Symbol Brand Black (#0a0a0a)
let brandBlack = NSColor(srgbRed: 10.0 / 255.0, green: 10.0 / 255.0, blue: 10.0 / 255.0, alpha: 1.0)

// Outer frame of the symbol (Variant 2: Classic Balanced, height 454px, vertically centered)
let frameWidth: CGFloat = 584.0
let frameHeight: CGFloat = 454.0
let frameRadius: CGFloat = 92.0
let frameY = iconRect.midY - frameHeight / 2.0
let frameRect = NSRect(x: iconRect.midX - frameWidth / 2.0,
                       y: frameY,
                       width: frameWidth,
                       height: frameHeight)
let framePath = createSquirclePath(rect: frameRect, radius: frameRadius)

let strokeW: CGFloat = 34.0
ctx.setStrokeColor(brandBlack.cgColor)
ctx.setLineWidth(strokeW)
ctx.addPath(framePath)
ctx.strokePath()

// Inner capsule top bar (pure semicircle on both ends: radius = height / 2)
let innerGap: CGFloat = 28.0
let topBarGap = strokeW / 2.0 + innerGap
let barHeight: CGFloat = 114.0
let barRect = NSRect(x: frameRect.minX + topBarGap,
                     y: frameRect.maxY - topBarGap - barHeight,
                     width: frameRect.width - 2 * topBarGap,
                     height: barHeight)
let barPath = createCapsulePath(rect: barRect)

ctx.setFillColor(brandBlack.cgColor)
ctx.addPath(barPath)
ctx.fillPath()

// Outer squircle border line
ctx.setStrokeColor(NSColor(white: 0, alpha: 0.08).cgColor)
ctx.setLineWidth(2.0)
ctx.addPath(squircle)
ctx.strokePath()

ctx.restoreGState()

image.unlockFocus()

if let tiff = image.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try! png.write(to: URL(fileURLWithPath: ProcessInfo.processInfo.environment["BASE_PNG"]!))
}
'

echo "==> Generating iconset variants..."
sips -z 16 16     "${TMP_DIR}/base.png" --out "${TMP_DIR}/AppIcon.iconset/icon_16x16.png" >/dev/null
sips -z 32 32     "${TMP_DIR}/base.png" --out "${TMP_DIR}/AppIcon.iconset/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "${TMP_DIR}/base.png" --out "${TMP_DIR}/AppIcon.iconset/icon_32x32.png" >/dev/null
sips -z 64 64     "${TMP_DIR}/base.png" --out "${TMP_DIR}/AppIcon.iconset/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "${TMP_DIR}/base.png" --out "${TMP_DIR}/AppIcon.iconset/icon_128x128.png" >/dev/null
sips -z 256 256   "${TMP_DIR}/base.png" --out "${TMP_DIR}/AppIcon.iconset/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "${TMP_DIR}/base.png" --out "${TMP_DIR}/AppIcon.iconset/icon_256x256.png" >/dev/null
sips -z 512 512   "${TMP_DIR}/base.png" --out "${TMP_DIR}/AppIcon.iconset/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "${TMP_DIR}/base.png" --out "${TMP_DIR}/AppIcon.iconset/icon_512x512.png" >/dev/null
sips -z 1024 1024 "${TMP_DIR}/base.png" --out "${TMP_DIR}/AppIcon.iconset/icon_512x512@2x.png" >/dev/null

echo "==> Compiling to ${OUTPUT_ICNS}..."
iconutil -c icns "${TMP_DIR}/AppIcon.iconset" -o "${OUTPUT_ICNS}"
cp -p "${OUTPUT_ICNS}" "/tmp/AppIcon.icns"

ls -lh "${OUTPUT_ICNS}"
echo "==> Successfully generated AppIcon.icns!"
