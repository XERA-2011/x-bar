//
//  LayoutBarsSection.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// The drag-to-arrange layout bars, shared by ``MenuBarLayoutSettingsPane``
/// and ``SimpleModeSettingsPane``.
///
/// Extracted from the layout pane so both the full editor and Simple Mode
/// render the exact same arranging surface (structure mirrors xmenubar-next).
struct LayoutBarsSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppState.self) private var appState: AppState
    let itemManager: MenuBarItemManager

    @State private var loadDeadlineReached = false
    /// Bumped whenever the screen the editor reflects may have changed, so
    /// the display title above the bars re-evaluates.
    @State private var displayTitleRefreshToken = 0

    private let diagLog = DiagLog(category: "MenuBarLayoutPane")

    private var hasItems: Bool {
        itemManager.itemCache.managedItems.contains(where: { !$0.isControlItem })
    }

    private var areControlItemsDisabledBySystem: Bool {
        itemManager.areControlItemsMissing
    }

    var body: some View {
        IceSection {
            if let editingDisplayName {
                Text("Active display: \(editingDisplayName)")
                    // Redrawn on the same signals LayoutBarPaddingView uses to
                    // re-evaluate the notch indicator, so the title and the
                    // bars below it can never disagree about which screen
                    // they are describing.
                    .id(displayTitleRefreshToken)
            }
        } content: {
            layoutBars
        } footer: {
            // Native grouped Section footer beneath the bars. Interpolated so
            // the four localized strings flow as one wrapping paragraph
            // instead of four fixed lines (Text + is deprecated on macOS 26;
            // each inner Text keeps its own localization key).
            Text("\(Text("Drag to arrange your menu bar items into different sections.")) \(Text("Move the New Items badge to choose where newly detected items will appear.")) \(Text("Items can also be arranged by ⌘ Command + dragging them in the menu bar.")) \(Text("Click an item to open it. Hidden items are temporarily revealed."))")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in
            displayTitleRefreshToken &+= 1
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter
                .publisher(for: NSWorkspace.didActivateApplicationNotification)
        ) { _ in
            displayTitleRefreshToken &+= 1
        }
    }

    /// The name of the display whose layout the bars below are showing.
    ///
    /// The editor has no display picker: it always reflects the screen that
    /// currently owns the menu bar, which is what `LayoutBarContainer` and
    /// `LayoutBarPaddingView` both read. On a single Mac that is invisible,
    /// but with an external display as the primary the editor silently
    /// describes a different screen than the user is picturing — and the
    /// notch placeholder correctly disappearing is the symptom people
    /// actually notice (#886). Naming the display makes the existing
    /// behaviour legible instead of changing it.
    private var editingDisplayName: String? {
        guard NSScreen.screens.count > 1 else {
            return nil
        }
        let screen = NSScreen.screenWithActiveMenuBar ?? NSScreen.main
        let name = screen?.localizedName.trimmingCharacters(in: .whitespaces)
        return (name?.isEmpty ?? true) ? nil : name
    }

    private var hasScreenRecording: Bool {
        appState.permissions.screenRecording.hasPermission
    }

    private var layoutBars: some View {
        VStack(spacing: 20) {
            layoutBar(for: .visible)
            layoutBar(for: .hidden)
        }
        .opacity(!hasScreenRecording ? 0.35 : (hasItems ? 1 : 0.75))
        .blur(radius: !hasScreenRecording ? 4 : (hasItems ? 0 : 5))
        .allowsHitTesting(hasScreenRecording && hasItems)
        .overlay {
            if !hasScreenRecording {
                screenRecordingPermissionOverlay
            } else if !hasItems {
                VStack(spacing: 8) {
                    if loadDeadlineReached {
                        VStack(spacing: 4) {
                            if areControlItemsDisabledBySystem {
                                Text("One or more section dividers are hidden by macOS")
                                Text("Check System Settings > Menu Bar and enable \(Constants.displayName)")
                                    .font(.callout.bold())
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Unable to load menu bar items")
                            }
                        }
                    } else {
                        Text("Loading menu bar items…")
                        ProgressView()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hasScreenRecording)
        .onChange(of: appState.permissions.screenRecording.hasPermission) { _, hasPermission in
            if hasPermission {
                Task {
                    await preloadLayoutCaches(includingImages: true)
                }
            }
        }
        .task(id: hasItems) {
            loadDeadlineReached = false

            guard !hasItems, appState.permissions.accessibility.hasPermission else {
                return
            }

            // Only the image cache needs Screen Recording; the item cache, and
            // therefore the overlay's own resolution, does not. Bailing out on
            // the permission left the spinner up forever.
            let hasScreenRecording = ScreenCapture.cachedCheckPermissions()

            diagLog.debug("Preloading menu bar layout caches (hasItems=\(self.hasItems), screenRecording=\(hasScreenRecording))")

            async let preloadCaches: Void = preloadLayoutCaches(includingImages: hasScreenRecording)

            try? await Task.sleep(for: .seconds(3))

            if !Task.isCancelled, !hasItems {
                loadDeadlineReached = true
                diagLog.error("Menu bar layout failed to load items after 3s timeout. cacheItems: \(itemManager.itemCache.managedItems.count), images: \(appState.imageCache.images.count), displayID: \(itemManager.itemCache.displayID.map { "\($0)" } ?? "nil")")
            }

            await preloadCaches
        }
    }

    @ViewBuilder
    private func layoutBar(for name: MenuBarSection.Name) -> some View {
        if
            let section = appState.menuBarManager.section(withName: name),
            section.isEnabled
        {
            VStack(alignment: .leading) {
                Text(name.localized)
                    .font(.headline)
                    .padding(.leading, 8)

                LayoutBar(section: name)
            }
        }
    }

    private var screenRecordingPermissionOverlay: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Screen Recording Permission Required")
                        .font(.headline)
                    Text("macOS requires Screen Recording to preview and arrange menu bar icons.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Grant Permission") {
                    appState.permissions.screenRecording.performRequest()
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "command")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Alternative: Hold **⌘ Command** and drag items directly on your physical menu bar (no permission needed).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal, 8)
    }

    private func preloadLayoutCaches(includingImages: Bool) async {
        await itemManager.cacheItemsRegardless(skipRecentMoveCheck: true)
        guard !Task.isCancelled else {
            return
        }

        diagLog.debug("Preload: itemCache after cacheItemsRegardless: managedItems=\(self.itemManager.itemCache.managedItems.count), visible=\(itemManager.itemCache[.visible].count), hidden=\(itemManager.itemCache[.hidden].count), alwaysHidden=\(itemManager.itemCache[.alwaysHidden].count)")

        guard includingImages else {
            // Without Screen Recording the bars draw app icons instead, so
            // there is nothing to capture.
            return
        }

        await appState.imageCache.updateCacheWithoutChecks(sections: MenuBarSection.Name.allCases)
        guard !Task.isCancelled else {
            return
        }

        diagLog.debug("Preload: imageCache after update: \(appState.imageCache.images.count) images")
    }
}
