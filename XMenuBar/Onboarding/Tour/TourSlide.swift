//
//  TourSlide.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation

/// A single page of the onboarding tour, in the order it's presented.
nonisolated enum XMenuBarTourSlide: Int, CaseIterable, Identifiable {
    case welcome
    case menuBarManagement

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .welcome: String(localized: "Welcome to XMenuBar")
        case .menuBarManagement: String(localized: "Menu Bar Management")
        }
    }

    var description: String {
        switch self {
        case .welcome:
            String(localized: "XMenuBar gives you complete control over your menu bar — hide clutter, customize layout, and keep your workspace clean.")
        case .menuBarManagement:
            String(localized: "Hide or show menu bar items on demand. Drag items between sections, keep your favorites always visible, and tuck the rest away in the always-hidden section.")
        }
    }

    /// The delay, in seconds, this slide's demo plays before auto-advancing
    /// to the next one.
    var autoAdvanceDelay: Double {
        switch self {
        case .welcome: 0
        case .menuBarManagement: 3.0
        }
    }
}
