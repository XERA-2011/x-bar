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
                    switch appState.settings.general.operationMode {
                    case .inline:
                        nativeInlineInstructionsSection
                    case .floatingLive:
                        if appState.permissions.screenRecording.hasPermission {
                            LayoutBarsSection(itemManager: itemManager)
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: appState.permissions.accessibility.hasPermission)
            .animation(.easeInOut(duration: 0.25), value: appState.permissions.screenRecording.hasPermission)
            .animation(.easeInOut(duration: 0.25), value: appState.settings.general.operationMode)
            .onAppear {
                if appState.permissions.accessibility.hasPermission,
                   appState.settings.general.operationMode == .floatingLive {
                    appState.imageCache.markSettingsPaneOpened()
                }
            }
            .onChange(of: appState.permissions.accessibility.hasPermission) { _, hasPermission in
                if hasPermission, appState.settings.general.operationMode == .floatingLive {
                    appState.imageCache.markSettingsPaneOpened()
                }
            }
            .onChange(of: appState.permissions.screenRecording.hasPermission) { _, hasPermission in
                if !hasPermission, appState.settings.general.operationMode == .floatingLive {
                    withAnimation {
                        appState.settings.general.operationMode = .inline
                    }
                }
            }
            .onChange(of: appState.settings.general.operationMode) { _, mode in
                appState.menuBarManager.iceBarPanel.close()
                appState.menuBarManager.updateControlItemStates()
                if mode == .floatingLive,
                   appState.permissions.accessibility.hasPermission,
                   ScreenCapture.cachedCheckPermissions() {
                    appState.imageCache.markSettingsPaneOpened()
                } else {
                    appState.imageCache.markSettingsPaneClosed()
                }
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    modeSegmentButton(
                        mode: .inline,
                        isEnabled: isInlineEnabled,
                        disabledReason: "Requires Accessibility permission"
                    )
                    modeSegmentButton(
                        mode: .floatingLive,
                        isEnabled: isLiveEnabled,
                        disabledReason: "Requires Screen Recording permission"
                    )
                }
                .padding(3)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

                Text(appState.settings.general.operationMode.detailDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func modeSegmentButton(
        mode: OperationMode,
        isEnabled: Bool,
        disabledReason: String
    ) -> some View {
        let isSelected = appState.settings.general.operationMode == mode

        Button {
            guard isEnabled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.settings.general.operationMode = mode
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: mode.iconName)
                    .font(.body)

                Text(mode.localized)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if !isEnabled {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.accentColor)
                        .shadow(color: Color.accentColor.opacity(0.25), radius: 2, y: 1)
                } else {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.clear)
                }
            }
            .foregroundStyle(
                isSelected
                    ? Color.white
                    : (isEnabled ? Color.primary : Color.secondary.opacity(0.5))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(isEnabled ? "" : disabledReason)
        .opacity(isEnabled ? 1.0 : 0.45)
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
                        Text("Required for Live Preview")
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
                Label("Permission Granted", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Button("Grant Permission") {
                    permission.performRequest()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var nativeInlineInstructionsSection: some View {
        IceSection {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "menubar.dock.rectangle")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Native Menu Bar Management")
                            .font(.headline)

                        Text("Items are managed and collapsed directly on your physical menu bar at the top of the screen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text("Hold **⌘ Command** and drag any item on your menu bar to rearrange it.")
                    } icon: {
                        Image(systemName: "command")
                            .foregroundStyle(Color.accentColor)
                    }

                    Label {
                        Text("Drag items to the **left** of the \(Constants.displayName) divider to hide them, or to the **right** to keep them visible.")
                    } icon: {
                        Image(systemName: "arrow.left.and.right")
                            .foregroundStyle(Color.accentColor)
                    }

                    Label {
                        Text("Click the **\(Constants.displayName) icon** in your menu bar anytime to expand or collapse hidden items directly on the menu bar.")
                    } icon: {
                        Image(systemName: "eye")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .font(.callout)
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Tip: In this mode, no floating bar will pop up. Hidden items smoothly slide into view directly on the top menu bar.")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cannotArrange: some View {
        Text("\(Constants.displayName) cannot arrange menu bar items in automatically hidden menu bars.")
            .font(.title3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
