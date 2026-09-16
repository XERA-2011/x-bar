//
//  SharedConstants.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation

/// Constants shared across the app.
/// App-only constants live in `Constants`.
nonisolated enum SharedConstants {
    // MARK: - System Framework Paths

    /// Info.plist key used to configure the SkyLight private framework path.
    static let skyLightFrameworkPathInfoPlistKey = "XBarSkyLightFrameworkPath"
    private static let legacySkyLightFrameworkPathInfoPlistKey = "XMenuBarSkyLightFrameworkPath"

    /// Path to the SkyLight private framework for window capture APIs.
    static let skyLightFrameworkPath: String = requiredInfoPlistString(
        skyLightFrameworkPathInfoPlistKey,
        fallbackKey: legacySkyLightFrameworkPathInfoPlistKey
    )

    // MARK: - Accessibility

    /// Ceiling, in seconds, on a single accessibility message.
    ///
    /// Every AX call is synchronous IPC tied to the target's event loop, so an
    /// app that stops pumping blocks us for the system default of six seconds
    /// — the delay behind #767. Healthy calls return in well under 100 ms.
    ///
    /// The main app bounds this in `applicationWillFinishLaunching` (where it
    /// is overridable via the `axMessagingTimeout` default).
    static let axMessagingTimeout = 1.0

    // MARK: - Menu Bar Host

    /// Bundle identifier of the process that hosts the menu bar's status
    /// items on this OS. Maintenance tools use it to locate (and reset) the
    /// preference domain holding every saved status-item position.
    static let menuBarHostingBundleID = "com.apple.controlcenter"

    // MARK: - Helpers

    /// Returns a required string from the bundle's Info.plist.
    private static func requiredInfoPlistString(_ key: String, fallbackKey: String? = nil) -> String {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return value
        }
        if let fallback = fallbackKey, let value = Bundle.main.object(forInfoDictionaryKey: fallback) as? String {
            return value
        }
        fatalError("Missing or invalid Info.plist string for key: \(key)")
    }
}
