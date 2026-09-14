//
//  SettingsNavigationIdentifier.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// The navigation identifier type for the "Settings" interface.
nonisolated enum SettingsNavigationIdentifier: String, NavigationIdentifier {
    case menuBarLayout = "Menu Bar Layout"
    case general = "General"
    case about = "About"

    var localized: LocalizedStringKey {
        switch self {
        case .menuBarLayout: "Layout"
        case .general: "General"
        case .about: "About"
        }
    }

    var iconResource: IconResource {
        switch self {
        case .menuBarLayout: .systemSymbol("rectangle.topthird.inset.filled")
        case .general: .systemSymbol("gearshape")
        case .about: .systemSymbol("cube")
        }
    }
}
