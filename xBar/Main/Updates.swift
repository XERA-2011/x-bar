//
//  Updates.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Observation
import SwiftUI

/// Manager for app updates.
@MainActor
@Observable
final class UpdatesManager: NSObject {
    /// A Boolean value that indicates whether the user can check for updates.
    var canCheckForUpdates = true

    /// The date of the last update check.
    var lastUpdateCheckDate: Date?

    /// The shared app state.
    private(set) weak var appState: AppState?

    /// Opens a URL on the user's behalf.
    @ObservationIgnored
    var openURL: @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }

    func performSetup(with appState: AppState) {
        self.appState = appState
    }

    @objc func checkForUpdates() {
        lastUpdateCheckDate = Date.now
        openURL(Constants.releasesURL)
    }
}
