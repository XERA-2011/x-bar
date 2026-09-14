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
        case .inline: "Native Menu Bar"
        case .floatingLive: "Live Preview Bar"
        }
    }

    /// The SF Symbol representing the mode.
    var iconName: String {
        switch self {
        case .inline: "menubar.dock.rectangle"
        case .floatingLive: "sparkles"
        }
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
            "Natively expands and collapses items directly on the top menu bar. Items to the left of the xBar divider are hidden; items to the right remain visible. Zero screen recording and ultra-low battery impact."
        case .floatingLive:
            "Pops up a floating dropdown bar with 1:1 live-captured menu bar icons (e.g. dynamic battery, network speeds). Requires Screen Recording permission."
        }
    }
}
