//
//  MenuBarLayoutSettingsPane.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

struct MenuBarLayoutSettingsPane: View {
    @Environment(AppState.self) var appState: AppState
    let itemManager: MenuBarItemManager
    @Bindable var advancedSettings: AdvancedSettings

    var body: some View {
        // Arranging items needs Accessibility, not Screen Recording. Without
        // capture the layout bars render each item as its owning app's icon
        // rather than a live glyph, which is enough to drag the right one, so
        // the pane stays usable instead of refusing to open.
        if appState.menuBarManager.isMenuBarHiddenBySystemUserDefaults {
            cannotArrange
        } else {
            IceForm {
                permissionsSection

                operationModeSection

                if appState.permissions.accessibility.hasPermission {
                    LayoutBarsSection(itemManager: itemManager)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: appState.permissions.accessibility.hasPermission)
            .animation(.easeInOut(duration: 0.25), value: appState.permissions.screenRecording.hasPermission)
            .animation(.easeInOut(duration: 0.25), value: appState.settings.general.operationMode)
            .onAppear {
                if appState.permissions.accessibility.hasPermission,
                   appState.permissions.screenRecording.hasPermission {
                    appState.imageCache.markSettingsPaneOpened()
                }
            }
            .onChange(of: appState.permissions.accessibility.hasPermission) { _, hasPermission in
                if hasPermission, appState.permissions.screenRecording.hasPermission {
                    appState.imageCache.markSettingsPaneOpened()
                } else if !hasPermission {
                    appState.imageCache.markSettingsPaneClosed()
                }
            }
            .onChange(of: appState.permissions.screenRecording.hasPermission) { _, hasPermission in
                if hasPermission, appState.permissions.accessibility.hasPermission {
                    appState.imageCache.markSettingsPaneOpened()
                } else {
                    appState.imageCache.markSettingsPaneClosed()
                    if appState.settings.general.operationMode == .floatingLive {
                        withAnimation {
                            appState.settings.general.operationMode = .inline
                        }
                    }
                }
            }
            .onChange(of: appState.settings.general.operationMode) { _, _ in
                appState.menuBarManager.iceBarPanel.close()
                appState.menuBarManager.updateControlItemStates()
            }
            .onDisappear {
                appState.imageCache.markSettingsPaneClosed()
            }
        }
    }

    private var permissionsSection: some View {
        IceSection("Permissions") {
            VStack(spacing: 12) {
                permissionRow(for: appState.permissions.accessibility)
                Divider()
                permissionRow(for: appState.permissions.screenRecording)
            }
        }
    }

    private var operationModeSection: some View {
        let hasAccessibility = appState.permissions.accessibility.hasPermission
        let hasScreenRecording = appState.permissions.screenRecording.hasPermission

        let isInlineEnabled = hasAccessibility
        let isLiveEnabled = hasAccessibility && hasScreenRecording

        return IceSection("Operation Mode") {
            HStack(alignment: .top, spacing: 14) {
                operationModeCard(
                    mode: .inline,
                    isEnabled: isInlineEnabled,
                    disabledReason: "Needs Accessibility"
                )
                operationModeCard(
                    mode: .floatingLive,
                    isEnabled: isLiveEnabled,
                    disabledReason: "Needs Screen Recording"
                )
            }
        }
    }

    @ViewBuilder
    private func operationModeCard(
        mode: OperationMode,
        isEnabled: Bool,
        disabledReason: LocalizedStringKey
    ) -> some View {
        let isSelected = appState.settings.general.operationMode == mode

        Button {
            guard isEnabled else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                appState.settings.general.operationMode = mode
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Mini Mockup Graphic
                mockupView(for: mode, isSelected: isSelected)

                // Header: Radio Button, Title, Lock/Status
                HStack(spacing: 7) {
                    Image(systemName: isSelected ? "record.circle.fill" : "circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                    Text(mode.localized)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundStyle(Color.primary)

                    Spacer(minLength: 4)

                    if !isEnabled {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                            Text(disabledReason)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                    }
                }

                Divider()
                    .opacity(0.5)

                // Feature Highlights
                let bullets = featureBullets(for: mode)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(bullets.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                .padding(.top, 2)
                            Text(bullets[index])
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.06) : Color(nsColor: .controlBackgroundColor).opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(
                color: isSelected ? Color.accentColor.opacity(0.14) : Color.black.opacity(0.03),
                radius: isSelected ? 4 : 2,
                y: 1
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }

    @ViewBuilder
    private func mockupView(for mode: OperationMode, isSelected: Bool) -> some View {
        ZStack(alignment: .top) {
            // Desktop wallpaper preview background (soft macOS sky gradient)
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.5, blue: 0.9).opacity(isSelected ? 0.32 : 0.20),
                            Color(red: 0.4, green: 0.7, blue: 0.95).opacity(isSelected ? 0.22 : 0.14),
                            Color(nsColor: .controlBackgroundColor).opacity(0.65)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 0) {
                // Mini Menu Bar (top row)
                HStack(spacing: 5) {
                    // Left: Apple logo + Finder
                    HStack(spacing: 3.5) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.75))

                        Text("Finder")
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.6))
                    }

                    Spacer(minLength: 4)

                    // Right: Status Items & xBar Components
                    switch mode {
                    case .inline:
                        // Inline mode: hidden items are expanded directly to the left of the divider
                        HStack(spacing: 3) {
                            HStack(spacing: 3) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 6.5))
                                Image(systemName: "headphones")
                                    .font(.system(size: 6.5))
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 6))
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 6))
                            }
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.18))
                                    .overlay(Capsule().stroke(Color.accentColor.opacity(0.35), lineWidth: 0.8))
                            )

                            // Door icon toggle in accent color
                            Image(systemName: "door.left.hand.open")
                                .font(.system(size: 7.5, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 1)

                            // Permanent visible items
                            HStack(spacing: 3) {
                                Image(systemName: "wifi")
                                    .font(.system(size: 6.5))
                                    .foregroundStyle(.primary.opacity(0.65))
                                Image(systemName: "battery.100")
                                    .font(.system(size: 6.5))
                                    .foregroundStyle(.primary.opacity(0.65))
                                Text("9:41")
                                    .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.primary.opacity(0.65))
                            }
                        }

                    case .floatingLive:
                        // Floating Live mode: Menu bar has active toggle button + status items
                        HStack(spacing: 3) {
                            // Door icon toggle in accent color (unified with inline style)
                            Image(systemName: "door.left.hand.open")
                                .font(.system(size: 7.5, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 1)

                            // Permanent visible items
                            HStack(spacing: 3) {
                                Image(systemName: "wifi")
                                    .font(.system(size: 6.5))
                                    .foregroundStyle(.primary.opacity(0.65))
                                Image(systemName: "battery.100")
                                    .font(.system(size: 6.5))
                                    .foregroundStyle(.primary.opacity(0.65))
                                Text("9:41")
                                    .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.primary.opacity(0.65))
                            }
                        }
                    }
                }
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.88))
                .overlay(alignment: .top) {
                    // Center: Prominent MacBook Notch
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 3.5,
                        bottomTrailingRadius: 3.5,
                        topTrailingRadius: 0
                    )
                    .fill(Color.black.opacity(0.92))
                    .frame(width: 40, height: 11)
                    .overlay(alignment: .top) {
                        Circle()
                            .fill(Color(white: 0.22))
                            .frame(width: 2.5, height: 2.5)
                            .padding(.top, 2.5)
                    }
                }
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(Color.primary.opacity(0.1)),
                    alignment: .bottom
                )

                // Desktop area below the menu bar
                ZStack {
                    switch mode {
                    case .inline:
                        // Native mode: Clean single-layer menu bar
                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                HStack(spacing: 3) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "arrow.left")
                                            .font(.system(size: 6, weight: .bold))
                                        Text("Hidden")
                                            .font(.system(size: 7.5, weight: .medium))
                                    }
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 52, alignment: .center)

                                    // Spacing alignment matching door icon above
                                    Image(systemName: "door.left.hand.open")
                                        .font(.system(size: 7.5, weight: .medium))
                                        .padding(.horizontal, 1)
                                        .opacity(0)

                                    Text("Visible")
                                        .font(.system(size: 7.5))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 44, alignment: .center)
                                }
                                .padding(.trailing, 7)
                                .padding(.top, 4)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal")
                                    .font(.system(size: 7.5))
                                Text("In-bar · No extra windows")
                                    .font(.system(size: 8, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 6)
                        }

                    case .floatingLive:
                        // Live Preview mode: Floating bar capsule with its middle icon (bell) aligned directly under door icon
                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                // Floating IceBar Capsule (symmetrically centered on bell.fill, matching the door icon above)
                                HStack(spacing: 4) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.system(size: 6.5))
                                    Image(systemName: "headphones")
                                        .font(.system(size: 6.5))
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 6.5))
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 6.5))
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 6.5, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                                .foregroundStyle(Color.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
                                        .shadow(color: Color.black.opacity(0.26), radius: 4, y: 2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .stroke(Color.accentColor.opacity(0.85), lineWidth: 1.2)
                                        )
                                )
                                .padding(.trailing, 24)
                                .padding(.top, 4)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "macwindow.on.rectangle")
                                    .font(.system(size: 7.5))
                                Text("Floating bar · Notch-friendly")
                                    .font(.system(size: 8, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 6)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(height: 82)
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func featureBullets(for mode: OperationMode) -> [LocalizedStringKey] {
        switch mode {
        case .inline:
            return [
                "Expands on menu bar",
                "No screen recording · Low power",
                "No extra floating windows"
            ]
        case .floatingLive:
            return [
                "Floating dropdown bar",
                "Bypasses notch hiding",
                "1:1 live icons"
            ]
        }
    }

    private func permissionRow(for permission: Permission) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: permission.iconName)
                .font(.title2)
                .foregroundStyle(permission.iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(permission.title)
                        .font(.headline)
                    if permission.isRequired {
                        Text("Required")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.15), in: Capsule())
                            .foregroundStyle(.red)
                    } else {
                        Text("Live Preview")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                if let detail = permission.details.first {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if permission.hasPermission {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Button("Grant") {
                    permission.performRequest()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }


    private var cannotArrange: some View {
        Text("\(Constants.displayName) cannot arrange menu bar items in automatically hidden menu bars.")
            .font(.title3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
