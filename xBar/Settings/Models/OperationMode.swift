//
//  OperationMode.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// The operation mode determining how menu bar items are displayed and managed.
nonisolated enum OperationMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Mode 1: Native menu bar collapse directly on physical menu bar, divider separates hidden (left) and visible (right).
    case inline = "inline"
    /// Mode 3: Floating IceBar panel displaying 1:1 live-captured menu bar glyphs, requires Screen Recording.
    case floatingLive = "floatingLive"

    init?(rawValue: String) {
        switch rawValue {
        case "inline", "floatingApp", "icon": self = .inline
        case "floatingLive", "livePreview": self = .floatingLive
        default: return nil
        }
    }

    var id: String {
        rawValue
    }

    /// The localized title of the mode.
    var localized: LocalizedStringKey {
        switch self {
        case .inline: "Native Bar"
        case .floatingLive: "Floating Bar"
        }
    }

    /// The SF Symbol representing the mode, optionally adjusted for selection state.
    func iconName(isSelected: Bool = true) -> String {
        switch self {
        case .inline:
            return "rectangle.topthird.inset.filled"
        case .floatingLive:
            return isSelected ? "rectangle.stack.fill" : "rectangle.stack"
        }
    }

    /// The SF Symbol representing the mode.
    var iconName: String {
        iconName(isSelected: true)
    }

    /// Whether this mode requires Screen Recording permission.
    var requiresScreenRecording: Bool {
        switch self {
        case .inline: false
        case .floatingLive: true
        }
    }

    /// Descriptive explanation of the mode.
    var detailDescription: LocalizedStringKey {
        switch self {
        case .inline:
            "Expands on the menu bar with zero extra windows."
        case .floatingLive:
            "Shows a floating dropdown bar with live-captured icons."
        }
    }
}
