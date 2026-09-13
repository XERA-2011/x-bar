//
//  MenuBarAppearanceSettingsPane.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

struct MenuBarAppearanceSettingsPane: View {
    let appearanceManager: MenuBarAppearanceManager

    var body: some View {
        MenuBarAppearanceEditor(
            appearanceManager: appearanceManager,
            location: .settings,
            onDone: nil
        )
    }
}
