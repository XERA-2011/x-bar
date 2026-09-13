//
//  HotkeyAction.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

nonisolated enum HotkeyAction: String, Codable, CaseIterable {
    // Menu Bar Sections
    case toggleHiddenSection = "ToggleHiddenSection"
    case toggleAlwaysHiddenSection = "ToggleAlwaysHiddenSection"

    /// Menu Bar Items
    case searchMenuBarItems = "SearchMenuBarItems"

    // Other
    case enableIceBar = "EnableIceBar"
    case toggleApplicationMenus = "ToggleApplicationMenus"
    case toggleAutoRehide = "ToggleAutoRehide"
    case toggleZenMode = "ToggleZenMode"

    /// Used by per-item hotkeys, action is handled externally.
    case openMenuBarItem = "OpenMenuBarItem"

    /// Actions that should appear in the Hotkeys settings pane as fixed,
    /// singleton recorders. Dynamic per-item hotkeys are created separately
    /// and are excluded here.
    static var settingsActions: [HotkeyAction] {
        allCases.filter { $0 != .openMenuBarItem }
    }
}
