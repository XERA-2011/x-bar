//
//  Constants.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation

/// App-specific constants for the main XMenuBar target.
/// System-framework paths shared with XPC targets live in `SharedConstants`.
nonisolated enum Constants {
    // swiftlint:disable force_unwrapping

    /// The version string in the app's bundle.
    static let versionString = Bundle.main.versionString!

    /// The build string in the app's bundle.
    static let buildString = Bundle.main.buildString!

    /// The user-readable copyright string in the app's bundle.
    static let copyrightString = Bundle.main.copyrightString!

    /// The app's bundle identifier.
    static let bundleIdentifier = Bundle.main.bundleIdentifier!

    /// The app's display name.
    static let displayName = Bundle.main.displayName

    // swiftlint:enable force_unwrapping

    /// The brightness threshold above which the menu bar is considered "bright".
    /// When the menu bar brightness exceeds this value, items should use dark colors.
    /// Used for non-notched displays.
    static let menuBarBrightnessThreshold: CGFloat = 0.67

    /// The brightness threshold for notched displays.
    /// Matches the non-notched threshold to avoid biasing toward dark text on
    /// notched displays where the black notch area lowers the sampled average.
    static let notchedDisplayBrightnessThreshold: CGFloat = 0.67

    // MARK: - App URLs (from Info.plist)

    /// Info.plist key used to configure the repository URL.
    static let repositoryURLInfoPlistKey = "XBarRepositoryURL"
    private static let legacyRepositoryURLInfoPlistKey = "XMenuBarRepositoryURL"

    /// Info.plist key used to configure the donation URL.
    static let donateURLInfoPlistKey = "XBarDonateURL"
    private static let legacyDonateURLInfoPlistKey = "XMenuBarDonateURL"

    /// The project's GitHub repository URL.
    static let repositoryURL: URL = requiredInfoPlistURL(repositoryURLInfoPlistKey, fallbackKey: legacyRepositoryURLInfoPlistKey)

    /// The URL for filing issues.
    static let issuesURL = repositoryURL.appendingPathComponent("issues")

    /// The URL for downloading preview builds.
    static let releasesURL = repositoryURL.appendingPathComponent("releases")

    /// The URL for sponsoring/donating.
    static let donateURL: URL = requiredInfoPlistURL(donateURLInfoPlistKey, fallbackKey: legacyDonateURLInfoPlistKey)

    // MARK: - Helpers

    /// Returns a required URL from the bundle's Info.plist.
    private static func requiredInfoPlistURL(_ key: String, fallbackKey: String? = nil) -> URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           let url = URL(string: value),
           url.scheme != nil {
            return url
        }
        if let fallback = fallbackKey,
           let value = Bundle.main.object(forInfoDictionaryKey: fallback) as? String,
           let url = URL(string: value),
           url.scheme != nil {
            return url
        }
        fatalError("Missing or invalid Info.plist URL for key: \(key)")
    }

    /// The arrow character used in menu path descriptions (→).
    /// Extracted so translators see %@ instead of a unicode arrow.
    static let menuArrow = "\u{2192}"
}
