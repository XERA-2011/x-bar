//
//  NotchOverflowRevealTests.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Testing
@testable import XMenuBar

/// Tests for the rule that decides whether notch overflow forces the XMenuBar Bar
/// as the reveal mechanism for hidden items.
///
/// Expanding the hidden section inline cannot show items that overflow ejected
/// — they were ejected precisely because nothing more fits beside the notch —
/// so a display with ejected items reveals through the XMenuBar Bar instead, unless
/// the user turns that off.
@Suite("Notch overflow reveal")
struct NotchOverflowRevealTests {
    @Test("Ejected items with the preference on force the XMenuBar Bar")
    func forcesBarWhenOverflowEnabledPreferenceOnAndItemsEjected() {
        #expect(
            MenuBarSection.forcesIceBarForNotchOverflow(
                overflowEnabled: true,
                useXMenuBarBarOnOverflow: true,
                hasEjectedItems: true
            )
        )
    }

    @Test("Nothing ejected does not force the XMenuBar Bar")
    func doesNotForceBarWhenNothingIsEjected() {
        #expect(
            !MenuBarSection.forcesIceBarForNotchOverflow(
                overflowEnabled: true,
                useXMenuBarBarOnOverflow: true,
                hasEjectedItems: false
            )
        )
    }

    @Test("The preference turned off does not force the XMenuBar Bar")
    func doesNotForceBarWhenPreferenceIsOff() {
        #expect(
            !MenuBarSection.forcesIceBarForNotchOverflow(
                overflowEnabled: true,
                useXMenuBarBarOnOverflow: false,
                hasEjectedItems: true
            )
        )
    }

    /// Stale ejection bookkeeping must not keep forcing the bar after the user
    /// turns overflow off; the items are on their way back to visible.
    @Test("Overflow disabled does not force the XMenuBar Bar")
    func doesNotForceBarWhenOverflowIsDisabled() {
        #expect(
            !MenuBarSection.forcesIceBarForNotchOverflow(
                overflowEnabled: false,
                useXMenuBarBarOnOverflow: true,
                hasEjectedItems: true
            )
        )
    }
}
