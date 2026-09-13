//
//  OnboardingView.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// Shared window dimensions for the onboarding and permissions flows.
enum XMenuBarOnboardingWindowMetrics {
    static let width: CGFloat = 608
    static let height: CGFloat = 480
}

/// The full first-launch experience: the feature tour, then the permissions
/// decision.
struct XMenuBarOnboardingView: View {
    private enum Step {
        case tour
        case permissions
    }

    @State private var step = Step.tour

    private let onComplete: () -> Void

    /// Creates the reusable onboarding flow.
    /// - Parameter onComplete: Called once the user finishes the permissions step.
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    var body: some View {
        Group {
            switch step {
            case .tour:
                XMenuBarOnboardingTour(onFinish: { step = .permissions })
                    .transition(.opacity)
            case .permissions:
                XMenuBarPermissionsView(onContinue: onComplete)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.35), value: step)
    }
}
