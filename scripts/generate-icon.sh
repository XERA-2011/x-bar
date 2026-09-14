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

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("No cgContext") }

let iconRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let path = NSBezierPath(roundedRect: iconRect, xRadius: 185, yRadius: 185)

ctx.saveGState()
let shadow = NSShadow()
shadow.shadowColor = NSColor(white: 0.0, alpha: 0.20)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 24
shadow.set()

NSColor.white.setFill()
path.fill()
ctx.restoreGState()

NSColor(white: 0.0, alpha: 0.08).setStroke()
path.lineWidth = 2.0
path.stroke()

let iconColor = NSColor(srgbRed: 10.0 / 255.0, green: 10.0 / 255.0, blue: 10.0 / 255.0, alpha: 1.0)
let config = NSImage.SymbolConfiguration(pointSize: 420, weight: .regular)
    .applying(NSImage.SymbolConfiguration(paletteColors: [iconColor]))

if let sf = NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
    let sfRect = NSRect(
        x: (1024 - sf.size.width) / 2,
        y: (1024 - sf.size.height) / 2,
        width: sf.size.width,
        height: sf.size.height
    )
    sf.draw(in: sfRect)
}

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
