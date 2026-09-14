//
//  OnboardingView.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// Shared window dimensions for the onboarding and permissions flows.
enum XBarOnboardingWindowMetrics {
    static let width: CGFloat = 608
    static let height: CGFloat = 480
}

/// The full first-launch experience: the feature tour, then the permissions
/// decision.
struct XBarOnboardingView: View {
    private let onComplete: () -> Void

    /// Creates the reusable onboarding flow.
    /// - Parameter onComplete: Called once the user finishes the permissions step.
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    var body: some View {
        XBarPermissionsView(onContinue: onComplete)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
