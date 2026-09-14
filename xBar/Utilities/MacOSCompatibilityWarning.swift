//
//  MacOSCompatibilityWarning.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit

enum MacOSCompatibilityWarning {
    /// The first macOS this build does not support.
    static nonisolated let firstUnsupportedMajorVersion = 27

    static nonisolated func shouldShow(for version: OperatingSystemVersion) -> Bool {
        version.majorVersion >= firstUnsupportedMajorVersion
    }

    /// The alert an unsupported system is owed: what it says, and what its
    /// default button does.
    nonisolated struct Prompt: Equatable {
        let title: String
        let message: String
        let confirmButtonTitle: String
    }

    /// The prompt for a system, or `nil` when the system is supported and no
    /// alert is due.
    static nonisolated func prompt(for version: OperatingSystemVersion) -> Prompt? {
        guard shouldShow(for: version) else {
            return nil
        }

        let release = version.majorVersion
        return Prompt(
            title: String(localized: "macOS \(release) Is Not Yet Supported"),
            message: String(
                localized: "This version of xBar may not yet be compatible with macOS \(release). Preview builds and updates are available on GitHub Releases."
            ),
            confirmButtonTitle: String(localized: "View Releases")
        )
    }

    /// Warns about the running macOS if needed.
    @MainActor
    static func showIfNeeded(updatesManager: UpdatesManager? = nil) {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        guard let prompt = prompt(for: version) else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = prompt.title
        alert.informativeText = prompt.message
        alert.addButton(withTitle: prompt.confirmButtonTitle)
        alert.addButton(withTitle: String(localized: "Continue"))

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        NSWorkspace.shared.open(Constants.releasesURL)
    }
}
