//
//  MenuBarCaptureServiceConnection.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import Foundation

extension MenuBarCaptureService {
    /// In-process capture provider for menu bar items.
    final class Connection: Sendable {
        static let shared = Connection()

        private let diagLog = DiagLog(category: "MenuBarCaptureService.Connection")

        private init() {}

        func start() async {
            diagLog.debug("Capture service initialized in-process")
        }

        func syncLogging() async {
            // In-process: already using shared logger.
        }

        func recycle() async {
            // In-process: no helper process to recycle.
        }

        func capture(
            windowIDs: [CGWindowID],
            scale: CGFloat,
            option: CGWindowImageOption
        ) async -> [Frame] {
            let scale = CGFloat(scale)
            guard scale > 0, scale.isFinite else { return [] }

            let allowed = Set(Bridging.getMenuBarWindowList(option: .itemsOnly))
            let validIDs = MenuBarCaptureService.validatedWindowIDs(windowIDs, allowed: allowed)
            guard !validIDs.isEmpty else { return [] }

            var storage = [CGWindowID: CGRect]()
            var orderedIDs = [CGWindowID]()
            var boundsUnion = CGRect.null
            for windowID in validIDs {
                guard let bounds = Bridging.getWindowBounds(for: windowID) else { continue }
                guard Bridging.isValidCaptureBounds(bounds, scale: scale) else { continue }
                storage[windowID] = bounds
                orderedIDs.append(windowID)
                boundsUnion = boundsUnion.union(bounds)
            }
            guard !orderedIDs.isEmpty, Bridging.isValidCaptureBounds(boundsUnion, scale: scale) else {
                return []
            }

            let composite = Bridging.captureWindowsImage(
                windowIDs: orderedIDs,
                options: option
            )
            guard let composite else { return [] }

            let expectedWidth = boundsUnion.width * scale
            guard abs(CGFloat(composite.width) - expectedWidth) < 1 else { return [] }

            if let encoded = MenuBarCaptureService.encodeBGRA(composite),
               MenuBarCaptureService.isFullyTransparentBGRA(
                   pixels: encoded.pixels,
                   width: composite.width,
                   height: composite.height,
                   bytesPerRow: encoded.bytesPerRow
               )
            {
                return []
            }

            var frames = [Frame]()
            var batchBytes = 0
            for windowID in orderedIDs {
                guard let bounds = storage[windowID] else { continue }
                let cropRect = CGRect(
                    x: (bounds.origin.x - boundsUnion.origin.x) * scale,
                    y: (bounds.origin.y - boundsUnion.origin.y) * scale,
                    width: bounds.width * scale,
                    height: bounds.height * scale
                )
                guard let cropped = composite.cropping(to: cropRect),
                      let encoded = MenuBarCaptureService.encodeBGRA(cropped)
                else {
                    continue
                }
                batchBytes += encoded.pixels.count
                guard batchBytes <= 16 * 1024 * 1024 else { break }
                frames.append(
                    Frame(
                        windowID: windowID,
                        width: cropped.width,
                        height: cropped.height,
                        bytesPerRow: encoded.bytesPerRow,
                        scale: Double(scale),
                        pixels: encoded.pixels
                    )
                )
            }
            return frames
        }
    }
}
