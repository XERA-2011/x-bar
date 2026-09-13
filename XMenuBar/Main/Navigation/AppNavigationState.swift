//
//  AppNavigationState.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Observation

/// The model for app-wide navigation.
@MainActor
@Observable
final class AppNavigationState {
    var isAppFrontmost = false
    var isSettingsPresented = false
    var isIceBarPresented = false
    var settingsNavigationIdentifier: SettingsNavigationIdentifier = .general {
        didSet {
            // Reopen the settings window on the pane the user last used.
            Defaults.set(settingsNavigationIdentifier.rawValue, forKey: .lastSettingsPane)
        }
    }

    init() {
        // Reopen the settings window on the pane the user last used. A pane
        // Simple Mode hides would restore an unselectable sidebar row (Simple
        // Mode replaces navigation entirely), so fall back to the default
        // (General) in that case.
        if let rawValue = Defaults.string(forKey: .lastSettingsPane),
           let pane = SettingsNavigationIdentifier(rawValue: rawValue),
           !Defaults.bool(forKey: .simpleMode)
        {
            settingsNavigationIdentifier = pane
        }
    }
}
