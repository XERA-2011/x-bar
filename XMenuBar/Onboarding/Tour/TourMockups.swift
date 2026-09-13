//
//  TourMockups.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import Observation
import SwiftUI

/// The demo menu bar's background treatment — mirrors XMenuBar's real
/// `MenuBarShapeKind` options. Real XMenuBar calls these "Full" and "Split" (a
/// single bar-wide shape vs. two independent leading/trailing shapes); this
/// demo labels the split option "Pills" since that's what it looks like —
/// two separate floating capsules with a gap between them.
private enum DemoBarStyle {
    case regular
    case gradient
    case pills

    var labelTint: Color {
        switch self {
        case .regular: .primary
        case .gradient, .pills: .white
        }
    }
}

/// A stand-in macOS menu bar: app label on the left, a cluster of "hidden"
/// items that can fade in/out, a tappable divider (XMenuBar's control item), and
/// a trailing cluster of always-visible items plus a clock. Shared by the
/// management, appearance, hotkeys, and profiles slides so they all read as
/// the same bar changing behavior, rather than four unrelated mockups.
///
/// `.pills` renders as two independent capsules (leading label, trailing
/// controls) with a real gap between them — matching XMenuBar's actual "Split"
/// shape kind, where the leading and trailing sides are separate shapes
/// rather than one bar-wide one.
private struct DemoMenuBar: View {
    var hiddenSymbols: [String]
    var hiddenShown: Bool
    var trailingSymbols: [String]
    var style: DemoBarStyle = .regular
    var onDividerTap: (() -> Void)?

    private var hiddenItemsCluster: some View {
        HStack(spacing: 8) {
            ForEach(hiddenSymbols, id: \.self) { symbol in
                GlassIconBubble(symbol: symbol, size: 24, tint: style.labelTint, showBackground: false)
            }
        }
        .opacity(hiddenShown ? 1 : 0)
        .offset(x: hiddenShown ? 0 : 16)
        .animation(.spring(duration: 0.45, bounce: 0.15), value: hiddenShown)
    }

    private var dividerButton: some View {
        Button {
            onDividerTap?()
        } label: {
            Circle()
                .fill(style.labelTint.opacity(0.85))
                .frame(width: 6, height: 6)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    private var trailingCluster: some View {
        HStack(spacing: 8) {
            ForEach(trailingSymbols, id: \.self) { symbol in
                GlassIconBubble(symbol: symbol, size: 24, tint: style.labelTint, showBackground: false)
            }
            Text(Date.now.formatted(.dateTime.hour().minute()))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(style.labelTint.opacity(0.85))
        }
    }

    var body: some View {
        if style == .pills {
            HStack(spacing: 14) {
                HStack(spacing: 7) {
                    Image(systemName: "apple.logo").font(.system(size: 12, weight: .medium))
                    Text(verbatim: "Finder").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(LinearGradient(colors: [.indigo, .blue], startPoint: .leading, endPoint: .trailing), in: Capsule())
                .shadow(color: .black.opacity(0.25), radius: 10, y: 3)

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    hiddenItemsCluster
                    dividerButton
                    trailingCluster
                }
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing), in: Capsule())
                .shadow(color: .black.opacity(0.25), radius: 10, y: 3)
            }
            .padding(.horizontal, 30)
            .animation(.spring(duration: 0.4), value: hiddenSymbols)
        } else {
            HStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "apple.logo").font(.system(size: 12, weight: .medium))
                    Text(verbatim: "Finder").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(style.labelTint.opacity(0.85))
                .padding(.leading, 16)

                Spacer(minLength: 12)

                hiddenItemsCluster
                dividerButton
                trailingCluster
                    .padding(.trailing, 16)
            }
            .frame(height: 38)
            .frame(maxWidth: .infinity)
            .background {
                switch style {
                case .regular:
                    Capsule().fill(.regularMaterial)
                case .gradient:
                    Capsule().fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                case .pills:
                    EmptyView()
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 10, y: 3)
            .padding(.horizontal, 30)
            .animation(.spring(duration: 0.4), value: hiddenSymbols)
        }
    }
}

/// The floating glass capsule HUD used below each demo bar to label or drive
/// its interaction — mirrors the "ControlHUD" floating labels in XMenuBar's real
/// onboarding tour.
private struct SlideHUD<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: Capsule())
    }
}

// MARK: - Restart Helper

/// Cancels the in-flight animation task of a tour mockup and replaces it with
/// a new one running `work`.
///
/// Every mockup model restarts the same way — cancel, reset its state, then
/// drive a sleep-and-animate sequence — and each of those sequences checks
/// `Task.isCancelled` between steps, so the previous task must be cancelled
/// before the new one is stored.
@MainActor
func replaceRestartTask(
    _ task: inout Task<Void, Never>?,
    running work: @escaping @MainActor () async -> Void
) {
    task?.cancel()
    task = Task { await work() }
}

// MARK: - Menu Bar Management

@MainActor
@Observable
final class XMenuBarManagementMockupModel {
    var itemsHidden = true
    @ObservationIgnored private var restartTask: Task<Void, Never>?

    func restart() {
        itemsHidden = true
        replaceRestartTask(&restartTask) {
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.45)) { self.itemsHidden = false }
        }
    }

    func toggle() {
        withAnimation(.spring(duration: 0.45, bounce: 0.1)) { itemsHidden.toggle() }
    }
}

struct ManagementSlideMockup: View {
    let model: XMenuBarManagementMockupModel
    var onInteraction: () -> Void = {
        // Intentionally empty: default no-op for previews/callers that don't need it.
    }

    var body: some View {
        VStack(spacing: 18) {
            DemoMenuBar(
                hiddenSymbols: ["wifi", "battery.100", "speaker.wave.2"],
                hiddenShown: !model.itemsHidden,
                trailingSymbols: ["magnifyingglass"],
                onDividerTap: {
                    onInteraction()
                    model.toggle()
                }
            )
            SlideHUD {
                Label(
                    model.itemsHidden ?
                        String(localized: "onboarding.mockup.management.show") :
                        String(localized: "onboarding.mockup.management.hide"),
                    systemImage: "hand.tap"
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
        }
    }
}

