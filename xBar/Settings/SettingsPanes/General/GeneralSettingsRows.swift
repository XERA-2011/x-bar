//
//  GeneralSettingsRows.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import LaunchAtLogin
import SwiftUI

// The handful of general settings that both ``GeneralSettingsPane`` and
// ``SimpleModeSettingsPane`` offer.
//
// These are the settings a user would notice missing, so Simple Mode shows
// them too. Defining each row once keeps the two panes from drifting.
//
// Rows the full pane grows out of these — the hover delay, the rehide
// strategy, the always-hidden gestures — stay in ``GeneralSettingsPane``.
// They are what Simple Mode exists to leave out.

// MARK: - LaunchAtLoginRow

/// Whether the app starts with the user's session.
struct LaunchAtLoginRow: View {
    var body: some View {
        LaunchAtLogin.Toggle {
            Text("Launch at Login")
        }
    }
}

// MARK: - ShowIceIconRow

/// The icon to show for the app in the menu bar.
struct ShowIceIconRow: View {
    @Bindable var settings: GeneralSettings

    var body: some View {
        IceIconPicker(settings: settings)
    }
}

// MARK: - ShowHiddenItemsOnRow

/// Which gestures on an empty stretch of the menu bar reveal hidden items.
///
/// All three fit on one row as a button group, so Simple Mode takes the whole
/// control rather than a two-gesture variant of it. A user who never finds
/// this row thinks the app is broken, which is what earns it a place there.
struct ShowHiddenItemsOnRow: View {
    @Bindable var settings: GeneralSettings

    var body: some View {
        LabeledContent("Show hidden items on") {
            ControlGroup {
                Toggle("Click", isOn: $settings.showOnClick)
                    .help("Click an empty area of the menu bar to show hidden menu bar items.")
                Toggle("Hover", isOn: $settings.showOnHover)
                    .help("Hover over an empty area of the menu bar to show hidden menu bar items.")
                Toggle("Scroll", isOn: $settings.showOnScroll)
                    .help("Scroll or swipe in the menu bar to show hidden menu bar items.")
            }
            .toggleStyle(.button)
            .fixedSize()
        }
    }
}
