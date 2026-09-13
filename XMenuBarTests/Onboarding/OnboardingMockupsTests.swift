//
//  OnboardingMockupsTests.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation
import SwiftUI
import Testing
@testable import XMenuBar

@Suite("Onboarding mockups")
struct OnboardingMockupsTests {
    // MARK: - XMenuBarManagementMockupModel

    @MainActor
    @Suite("Management mockup model")
    struct XMenuBarManagementMockupModelTests {
        @Test("Restarting resets the items to hidden")
        func restartResetsToHidden() {
            let model = XMenuBarManagementMockupModel()
            model.itemsHidden = false

            model.restart()

            #expect(model.itemsHidden)
        }

        @Test("Toggling flips the hidden state")
        func toggleFlipsHiddenState() {
            let model = XMenuBarManagementMockupModel()
            let initial = model.itemsHidden

            model.toggle()
            #expect(model.itemsHidden == !initial)

            model.toggle()
            #expect(model.itemsHidden == initial)
        }
    }

    // MARK: - XMenuBarAppearanceMockupModel

    @MainActor
    @Suite("Appearance mockup model")
    struct XMenuBarAppearanceMockupModelTests {
        @Test("There is one style label per style")
        func styleLabelsHasOneEntryPerStyle() {
            #expect(XMenuBarAppearanceMockupModel.styleLabels.count == 3)
            for label in XMenuBarAppearanceMockupModel.styleLabels {
                #expect(!label.isEmpty)
            }
        }

        @Test("Restarting resets the style index to zero")
        func restartResetsStyleIndexToZero() {
            let model = XMenuBarAppearanceMockupModel()
            model.select(2)

            model.restart()

            #expect(model.styleIndex == 0)
        }

        @Test("Selecting updates the style index")
        func selectUpdatesIndex() {
            let model = XMenuBarAppearanceMockupModel()

            model.select(1)
            #expect(model.styleIndex == 1)

            model.select(2)
            #expect(model.styleIndex == 2)
        }

        @Test("Selecting the current style index is a no-op")
        func selectCurrentIndexIsNoOp() {
            let model = XMenuBarAppearanceMockupModel()
            model.select(1)
            #expect(model.styleIndex == 1)

            model.select(1)
            #expect(model.styleIndex == 1)
        }
    }

    // MARK: - XMenuBarHotkeysMockupModel

    @MainActor
    @Suite("Hotkeys mockup model")
    struct XMenuBarHotkeysMockupModelTests {
        @Test("Restarting resets the items to not visible")
        func restartResetsToNotVisible() {
            let model = XMenuBarHotkeysMockupModel()
            model.itemsVisible = true

            model.restart()

            #expect(!model.itemsVisible)
        }

        @Test("Triggering toggles visibility")
        func triggerTogglesVisibility() {
            let model = XMenuBarHotkeysMockupModel()
            let initial = model.itemsVisible

            model.trigger()
            #expect(model.itemsVisible == !initial)

            model.trigger()
            #expect(model.itemsVisible == initial)
        }
    }

    // MARK: - XMenuBarProfilesMockupModel

    @MainActor
    @Suite("Profiles mockup model")
    struct XMenuBarProfilesMockupModelTests {
        @Test("There is one focus mode per profile")
        func focusModesHasOneEntryPerProfile() {
            #expect(XMenuBarProfilesMockupModel.focusModes.count == 3)
            for mode in XMenuBarProfilesMockupModel.focusModes {
                #expect(!mode.name.isEmpty)
                #expect(!mode.symbol.isEmpty)
                #expect(!mode.items.isEmpty)
            }
        }

        @Test("The active focus mode reflects the focus index")
        func activeReflectsFocusIndex() {
            let model = XMenuBarProfilesMockupModel()
            #expect(model.active.symbol == XMenuBarProfilesMockupModel.focusModes[0].symbol)

            model.select(1)
            #expect(model.active.symbol == XMenuBarProfilesMockupModel.focusModes[1].symbol)
        }

        @Test("Selecting updates the focus index")
        func selectUpdatesIndex() {
            let model = XMenuBarProfilesMockupModel()

            model.select(2)
            #expect(model.focusIndex == 2)
        }

        @Test("Selecting the current focus index is a no-op")
        func selectCurrentIndexIsNoOp() {
            let model = XMenuBarProfilesMockupModel()
            model.select(1)
            #expect(model.focusIndex == 1)

            model.select(1)
            #expect(model.focusIndex == 1)
        }

        @Test("Restarting resets the focus index to zero")
        func restartResetsFocusIndexToZero() {
            let model = XMenuBarProfilesMockupModel()
            model.select(2)

            model.restart()

            #expect(model.focusIndex == 0)
        }
    }
}
