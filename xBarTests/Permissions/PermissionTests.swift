//
//  PermissionTests.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation
import SwiftUI
import Testing
@testable import xBar

/// Covers ``Permission``'s request/poll cycle through its injected closures,
/// so nothing here touches the real TCC database.
@MainActor
@Suite("Permission request polling")
struct PermissionTests {
    @Test("A request restarts polling after checks have been stopped", .timeLimit(.minutes(1)))
    func performRequestRestartsPollingAfterChecksStop() async throws {
        var isGranted = false
        var requestCount = 0
        var openedSettingsURLs = [URL]()
        let settingsURL = try #require(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        )
        let permission = Permission(
            title: "Test Permission",
            iconName: "checkmark",
            iconColor: .blue,
            details: [],
            isRequired: false,
            settingsURL: settingsURL,
            check: { isGranted },
            request: { requestCount += 1 },
            openSettings: { url in
                openedSettingsURLs.append(url)
                return true
            }
        )

        permission.stopCheck()
        permission.performRequest()
        permission.stopCheck()
        permission.performRequest()
        isGranted = true

        // `onChange` fires on every poll tick, not once on transition.
        // `confirmation` expects exactly one call and `resume` traps on a
        // second, so latch the first grant and ignore every later tick.
        await confirmation("Permission grant is observed after polling restarts") { granted in
            await withCheckedContinuation { continuation in
                var hasResumed = false
                permission.onChange = {
                    guard permission.hasPermission, !hasResumed else {
                        return
                    }
                    hasResumed = true
                    granted()
                    continuation.resume()
                }
            }
        }

        #expect(requestCount == 2)
        #expect(openedSettingsURLs == [settingsURL])
        #expect(permission.hasPermission)
    }

    @Test("First request prompts OS without opening settings; subsequent requests open settings")
    func performRequestDefersSettingsToSubsequentAttempts() throws {
        var requestCount = 0
        var openedSettingsURLs = [URL]()
        let settingsURL = try #require(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        )
        let permission = Permission(
            title: "Test Permission",
            iconName: "checkmark",
            iconColor: .blue,
            details: [],
            isRequired: false,
            settingsURL: settingsURL,
            check: { false },
            request: { requestCount += 1 },
            openSettings: { url in
                openedSettingsURLs.append(url)
                return true
            }
        )
        defer { permission.stopCheck() }

        #expect(!permission.hasAttemptedRequest)

        // First attempt: triggers system request only, does not open System Settings.
        permission.performRequest()
        #expect(requestCount == 1)
        #expect(openedSettingsURLs.isEmpty)
        #expect(permission.hasAttemptedRequest)

        // Second attempt: opens System Settings directly.
        permission.performRequest()
        #expect(requestCount == 2)
        #expect(openedSettingsURLs == [settingsURL])

        // Resetting attempt state allows another prompt attempt without opening settings.
        permission.resetAttemptState()
        #expect(!permission.hasAttemptedRequest)

        permission.performRequest()
        #expect(requestCount == 3)
        #expect(openedSettingsURLs == [settingsURL]) // Still just the one from earlier
        #expect(permission.hasAttemptedRequest)
    }
}
