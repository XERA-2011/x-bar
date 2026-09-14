//
//  Updates.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Combine
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

    /// Tracks whether the updater has been started.
    private var hasStartedUpdater = false

    /// Tracks whether the running check was started by the macOS
    /// compatibility alert.
    ///
    /// That alert promises the user a build for a macOS this one does not
    /// support. A background check that finds nothing is silent, so the
    /// promise has to survive the check to be kept: an empty alpha feed
    /// sends them to the releases page rather than nowhere.
    @ObservationIgnored
    private var isCheckingAfterCompatibilityWarning = false

    /// Opens a URL on the user's behalf.
    ///
    /// Injectable so a test can watch the compatibility alert's fallback fire
    /// without handing the running system a browser window.
    @ObservationIgnored
    var openURL: @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }

    /// Storage for internal observers.
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    var automaticallyChecksForUpdates: Bool = false
    var automaticallyDownloadsUpdates: Bool = false
    var updateChannel: UpdateChannel = .stable

    func performSetup(with appState: AppState) {
        self.appState = appState
    }

    func startUpdaterIfNeeded() {}

    @objc func checkForUpdates() {
        lastUpdateCheckDate = Date.now
        openURL(Constants.releasesURL)
    }

    func checkForUpdatesInBackground() {}
}

// MARK: - UpdateChannel

nonisolated enum UpdateChannel: String, CaseIterable, Identifiable {
    case stable
    case beta
    case alpha

    var id: String { rawValue }

    static func availableCases(on version: OperatingSystemVersion) -> [UpdateChannel] {
        [.stable]
    }

    var localized: LocalizedStringKey {
        LocalizedStringKey(rawValue.capitalized)
    }
}
