//
//  MenuBarManager.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AsyncAlgorithms
import AXSwift6
import Combine
import Observation
import SwiftUI

/// Manager for the state of the menu bar.
@MainActor
@Observable
final class MenuBarManager {
    /// Information for the menu bar's average color on the active screen.
    private(set) var averageColorInfo: MenuBarAverageColorInfo?

    /// Per-screen average colors for multi-monitor adaptive backgrounds.
    private(set) var averageColors: [CGDirectDisplayID: MenuBarAverageColorInfo] = [:]


    /// A Boolean value that indicates whether the menu bar is either always hidden
    /// by the system, or automatically hidden and shown by the system based on the
    /// location of the mouse.
    private(set) var isMenuBarHiddenBySystem = false

    /// A Boolean value that indicates whether the menu bar is hidden by the system
    /// according to a value stored in UserDefaults.
    private(set) var isMenuBarHiddenBySystemUserDefaults = false

    /// A Boolean value that indicates whether the "ShowOnHover" feature is allowed.
    var showOnHoverAllowed = true

    /// Timestamp of the last time a section was shown.
    private(set) var lastShowTimestamp: ContinuousClock.Instant?

    /// Reference to the settings window.
    private var settingsWindow: NSWindow?

    /// Diagnostic logger for the menu bar manager.
    @ObservationIgnored
    private let diagLog = DiagLog(category: "MenuBarManager")

    /// The shared app state.
    @ObservationIgnored
    private weak var appState: AppState?

    /// Storage for internal observers.
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    /// Task observing `DisplaySettingsManager.configurations`, which is
    /// `@Observable` rather than a Combine `ObservableObject`.
    private var displayConfigurationsObservationTask: Task<Void, Never>?

    /// Task observing `settingsWindow`'s `isVisible` KVO stream (wave 3),
    /// replacing the old `$settingsWindow.removeNil().map { $0.publisher(for:
    /// \.isVisible) }.switchToLatest()` pipeline. `settingsWindow` is now a
    /// plain `@Observable` property rather than a Combine `@Published` one,
    /// so it no longer has a `$settingsWindow` publisher; the inner KVO
    /// publisher on the resolved `NSWindow` is unrelated to Observation and
    /// stays Combine, manually re-subscribed on each new non-nil window
    /// value (mirroring `switchToLatest`'s behavior).
    private var settingsWindowObservationTask: Task<Void, Never>?

    @MainActor
    deinit {
        displayConfigurationsObservationTask?.cancel()
        settingsWindowObservationTask?.cancel()
        settingsWindowVisibilityCancellable?.cancel()
    }

    /// Cancellable for the periodic average-color refresh, active only while settings is visible.
    private var averageColorRefreshCancellable: AnyCancellable?

    /// Cancellable for `settingsWindow`'s `isVisible` KVO stream, resubscribed
    /// on each new non-nil `settingsWindow` value by `settingsWindowObservationTask`.
    @ObservationIgnored
    private var settingsWindowVisibilityCancellable: AnyCancellable?

    /// Per-screen colors cached before sleep, restored on wake to avoid stale/white flash.
    private var sleepColorCache: [CGDirectDisplayID: MenuBarAverageColorInfo]?

    /// Identifies the most recently started capture pass, so results that land
    /// after a newer pass has published its own can be dropped.
    @ObservationIgnored
    private var captureGeneration = 0

    /// Polling state for adaptive wake stabilization.
    private var wakePollTimer: AnyCancellable?
    private var wakePollPrevColors: [CGDirectDisplayID: MenuBarAverageColorInfo]?
    private var wakePollStableCount = 0
    private var wakePollDidChange = false
    private var wakePollStartTime: Date?

    /// A Boolean value that indicates whether the application menus are hidden.
    private var isHidingApplicationMenus = false

    /// A Boolean value that indicates whether the application menus were hidden
    /// by a manual toggle (URL/hotkey), rather than automatically by section state.
    private var isManuallyHidingApplicationMenus = false

    /// The panel that contains the XMenuBar Bar interface.
    let iceBarPanel = IceBarPanel()

    /// The popover that contains a portable version of the menu bar
    /// layout editor interface
    let layoutEditorPanel = MenuBarLayoutEditorPanel()

    /// The managed sections in the menu bar.
    let sections = [
        MenuBarSection(name: .visible),
        MenuBarSection(name: .hidden),
        MenuBarSection(name: .alwaysHidden),
    ]

    /// A Boolean value that indicates whether at least one of the manager's
    /// sections is visible.
    var hasVisibleSection: Bool {
        sections.contains { !$0.isHidden }
    }

    /// Performs the initial setup of the menu bar manager.
    func performSetup(with appState: AppState) {
        self.appState = appState
        configureCancellables()
        iceBarPanel.performSetup(with: appState)
        layoutEditorPanel.performSetup(with: appState)
        for section in sections {
            section.performSetup(with: appState)
        }
    }

    /// Configures the internal observers for the manager.
    private func configureCancellables() {
        averageColorRefreshCancellable?.cancel()
        averageColorRefreshCancellable = nil
        var c = Set<AnyCancellable>()

        NSApp.publisher(for: \.currentSystemPresentationOptions)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] options in
                guard let self else {
                    return
                }
                let hidden = options.contains(.hideMenuBar) || options.contains(.autoHideMenuBar)
                isMenuBarHiddenBySystem = hidden
            }
            .store(in: &c)

        if
            let hiddenSection = section(withName: .alwaysHidden),
            let window = hiddenSection.controlItem.window
        {
            window.publisher(for: \.frame)
                .map(\.origin.y)
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard
                        let self,
                        let isMenuBarHidden = Defaults.globalDomain["_HIHideMenuBar"] as? Bool
                    else {
                        return
                    }
                    isMenuBarHiddenBySystemUserDefaults = isMenuBarHidden
                }
                .store(in: &c)
        }

        // Handle the `focusedApp` and `smart` rehide strategies.
        NSWorkspace.shared.notificationCenter.publisher(
            for: NSWorkspace.didActivateApplicationNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            let activatedApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
            guard
                let self,
                let appState,
                appState.settings.general.autoRehide,
                Self.shouldHandleAutoRehideActivation(
                    activatedProcessIdentifier: activatedApplication?.processIdentifier,
                    currentProcessIdentifier: ProcessInfo.processInfo.processIdentifier
                )
            else {
                if self?.appState?.settings.general.autoRehide == false {
                    // Auto-rehide is off; no strategy fires. Not an error,
                    // but the user may expect focus/timed to work without
                    // the master toggle.
                }
                return
            }

            let strategy = appState.settings.general.rehideStrategy
            switch strategy {
            case .focusedApp, .smart:
                guard
                    let screen = appState.hidEventManager.bestScreen(appState: appState),
                    !appState.hidEventManager.isMouseInsideMenuBar(appState: appState, screen: screen),
                    !appState.hidEventManager.isMouseInsideIceBar(appState: appState)
                else {
                    return
                }
                Task { [weak self] in
                    // Wait for focus to settle and carry an activation
                    // inside the reveal grace period to its end instead
                    // of dropping that activation permanently.
                    let delay = Self.rehideDelay(for: strategy, since: self?.lastShowTimestamp)
                    guard await (try? Task.sleep(for: delay)) != nil else { return }

                    guard let self else { return }
                    guard appState.settings.general.rehideStrategy == strategy else { return }
                    if strategy == .smart, await appState.itemManager.isAnyMenuBarItemMenuOpen() {
                        return
                    }

                    self.hideVisibleSections()
                }
            default:
                break
            }
        }
        .store(in: &c)

        appState?.publisherForWindow(.settings)
            .sink { [weak self] window in
                self?.settingsWindow = window
            }
            .store(in: &c)

        if let appState {
            let displaySettings = appState.settings.displaySettings
            displayConfigurationsObservationTask = Task { [weak self] in
                let changes = Observations { displaySettings.configurations }
                for await _ in changes {
                    guard let self else { return }
                    updateControlItemStates()
                }
            }
        }

        settingsWindowObservationTask = Task { [weak self] in
            let changes = Observations { self?.settingsWindow }
            for await window in changes {
                guard let self else { return }
                guard let window else { continue }
                settingsWindowVisibilityCancellable = window.publisher(for: \.isVisible)
                    .removeDuplicates()
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] isVisible in
                        guard let self else { return }
                        if isVisible {
                            updateAverageColorInfo()
                            // Start a visibility-gated 60s refresh to catch wallpaper changes
                            // (macOS no longer posts a wallpaper change notification).
                            averageColorRefreshCancellable = Timer.publish(every: 60, tolerance: 10, on: .main, in: .default)
                                .autoconnect()
                                .sink { [weak self] _ in
                                    self?.updateAverageColorInfo()
                                }
                        } else {
                            averageColorRefreshCancellable?.cancel()
                            averageColorRefreshCancellable = nil
                        }
                    }
            }
        }

        // Refresh average color when space or screen changes while settings or adaptive is active.
        Publishers.Merge(
            NSWorkspace.shared.notificationCenter
                .publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
                .replace(with: ()),
            NotificationCenter.default
                .publisher(for: NSApplication.didChangeScreenParametersNotification)
                .replace(with: ())
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in
            guard let self else { return }
            guard settingsWindow?.isVisible == true else { return }
            updateAverageColorInfo()
        }
        .store(in: &c)

        // Cache per-screen colors before display sleep so they can be restored
        // on wake, preventing a white flash before the display settles and
        // wallpaper renders. Uses screensDidSleep/Wake which fire on display
        // sleep/wake (screen lock, idle timeout) AND system sleep (lid close).
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.screensDidSleepNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                sleepColorCache = averageColors
            }
            .store(in: &c)

        // On display wake, restore pre-sleep colors immediately (no white flash),
        // then poll every 1s until the captured color changes from the cached
        // value and stabilizes (2 consecutive identical captures), or 10s max.
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.screensDidWakeNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                guard settingsWindow?.isVisible == true else { return }

                guard let cache = sleepColorCache else {
                    updateAverageColorInfo()
                    return
                }

                // Restore pre-sleep colors so the bar never flashes white.
                // Stamping a new pass drops any capture still in flight from
                // before the sleep, so it cannot land afterwards and overwrite
                // the restore with whatever the screen looked like on its way
                // out.
                captureGeneration += 1
                averageColors = cache
                if let id = NSScreen.screenWithActiveMenuBar?.displayID,
                   let cached = cache[id]
                {
                    averageColorInfo = cached
                }

                // Poll every 1s until color changes from cache then stabilizes.
                wakePollPrevColors = nil
                wakePollStableCount = 0
                wakePollDidChange = false
                wakePollStartTime = Date()
                wakePollTimer = Timer.publish(every: 1, on: .main, in: .default)
                    .autoconnect()
                    .sink { [weak self] _ in
                        guard let self else { return }
                        // Wraps the stabilization logic in a Task that awaits
                        // updateAverageColorInfoAsync so the post-capture read
                        // of averageColors sees the fresh values; the original
                        // sync call returned before the fire-and-forget Tasks
                        // populated state, defeating stabilization detection.
                        Task { [weak self] in
                            guard let self else { return }
                            let elapsed = wakePollStartTime.map { Date().timeIntervalSince($0) } ?? 0

                            if elapsed >= 10 {
                                sleepColorCache = nil
                                wakePollTimer = nil
                                return
                            }

                            await updateAverageColorInfoAsync()
                            let after = averageColors

                            if !wakePollDidChange, let cache = sleepColorCache, after != cache {
                                wakePollDidChange = true
                            }

                            if wakePollDidChange {
                                if let prev = wakePollPrevColors, prev == after {
                                    wakePollStableCount += 1
                                    if wakePollStableCount >= 1 {
                                        sleepColorCache = nil
                                        wakePollTimer = nil
                                        return
                                    }
                                } else {
                                    wakePollStableCount = 0
                                }
                            }

                            wakePollPrevColors = after
                        }
                    }
            }
            .store(in: &c)

        // Hide application menus when a section is shown (if applicable).
        Publishers.MergeMany(sections.map(\.controlItem.$state))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, let appState else {
                    return
                }

                // Don't continue if:
                //   * The "HideApplicationMenus" setting isn't enabled.
                //   * Using the XMenuBar Bar.
                //   * The menu bar is hidden by the system.
                //   * The active space is fullscreen.
                //   * The settings window is visible.
                guard
                    appState.settings.advanced.hideApplicationMenus,
                    !appState.settings.displaySettings.configurationForActiveDisplay().useIceBar,
                    !isMenuBarHiddenBySystem,
                    !appState.activeSpace.isFullscreen,
                    !appState.navigationState.isSettingsPresented
                else {
                    return
                }

                // Check if hidden or alwaysHidden section is being shown
                let hiddenSection = self.section(withName: .hidden)
                let alwaysHiddenSection = self.section(withName: .alwaysHidden)

                // Use isHidden property - when section is shown, isHidden is false.
                // A section presenting in the XMenuBar Bar expands nothing inline,
                // so the application menus have no items to make room for. The
                // guard above already covers the display-wide setting; this
                // covers useXMenuBarBarForAlwaysHidden, where the always-hidden
                // section is in the panel while the hidden section is inline.
                let panelSection = iceBarPanel.currentSection
                let isShowingHiddenSection = (hiddenSection.map { !$0.isHidden } ?? false)
                    && panelSection != .hidden
                let isShowingAlwaysHiddenSection = (alwaysHiddenSection.map { !$0.isHidden } ?? false)
                    && panelSection != .alwaysHidden

                if isShowingHiddenSection || isShowingAlwaysHiddenSection {
                    // Use the screen with the active menu bar
                    guard let screen = NSScreen.screenWithActiveMenuBar ?? NSScreen.main else {
                        return
                    }

                    Task {
                        // The window server needs time to update window positions after expansion.
                        try? await Task.sleep(for: .milliseconds(50))

                        // Get the app menu frame for this screen
                        guard let appMenuFrame = screen.getApplicationMenuFrame() else {
                            return
                        }

                        // Get ALL menu bar items
                        let allItems = await MenuBarItem.getMenuBarItems(option: .activeSpace)

                        // Filter to items on THIS screen by comparing Y coordinate with app menu's Y
                        let menuBarY = appMenuFrame.origin.y
                        let screenItems = allItems.filter { item in
                            abs(item.bounds.origin.y - menuBarY) < 50
                        }

                        // Get the control items for this screen
                        let hiddenControlItem = screenItems.first { $0.tag == .hiddenControlItem }
                        let alwaysHiddenControlItem = screenItems.first { $0.tag == .alwaysHiddenControlItem }

                        // Approximate hidden items width from control item positions.

                        // Get control item bounds and hidden items width
                        var controlBounds: CGRect = .zero
                        var hiddenItemsWidth: CGFloat = 0

                        if isShowingAlwaysHiddenSection, let ahControl = alwaysHiddenControlItem {
                            controlBounds = ahControl.bounds
                            if let appState = self.appState {
                                hiddenItemsWidth = appState.itemManager.itemCache[.alwaysHidden].reduce(0) { $0 + $1.bounds.width }
                            }
                        } else if isShowingHiddenSection, let hControl = hiddenControlItem {
                            controlBounds = hControl.bounds
                            if let appState = self.appState {
                                hiddenItemsWidth = appState.itemManager.itemCache[.hidden].reduce(0) { $0 + $1.bounds.width }
                            }
                        }

                        // The hidden section expands by replacing control item with hidden items
                        // New rightmost = where hidden items end = control.minX + hiddenItemsWidth
                        let newRightmostPos = controlBounds.minX + hiddenItemsWidth

                        // Use the actual app menu frame for needed space
                        let appMenuRightStart = appMenuFrame.maxX

                        // Available space: if app menu extends into notch, add notch width; otherwise use visible frame
                        let spaceAvailableFromAppMenuEnd: CGFloat = if let notch = screen.frameOfNotch {
                            if appMenuRightStart > notch.minX {
                                // App menu extends into notch, items get moved past notch
                                (notch.minX - appMenuRightStart) + (screen.visibleFrame.maxX - notch.maxX)
                            } else {
                                // App menu doesn't extend into notch
                                screen.visibleFrame.maxX - appMenuRightStart
                            }
                        } else {
                            screen.visibleFrame.maxX - appMenuRightStart
                        }

                        let spaceNeededFromAppMenuEnd = newRightmostPos - appMenuRightStart

                        // If items would extend past screen edge, hide the app menu
                        if spaceNeededFromAppMenuEnd > spaceAvailableFromAppMenuEnd {
                            self.hideApplicationMenus()
                        }
                    }
                } else if isHidingApplicationMenus, !isManuallyHidingApplicationMenus {
                    showApplicationMenus()
                }
            }
            .store(in: &c)

        cancellables = c
    }

    // MARK: - Color Info Capture

    /// Updates the ``averageColorInfo`` and ``averageColors`` properties with
    /// the current average color of the menu bar background per screen.
    func updateAverageColorInfo() {
        Task { [weak self] in
            await self?.updateAverageColorInfoAsync()
        }
    }

    /// Awaitable variant of updateAverageColorInfo.
    func updateAverageColorInfoAsync() async {
        guard ScreenCapture.cachedCheckPermissions() else { return }
        guard let appState else { return }

        // Only update if we really need the color info
        let isSettingsVisible = settingsWindow?.isVisible == true
        let isIceBarVisible = appState.navigationState.isIceBarPresented
        let anyIceBarEnabled = appState.settings.displaySettings.isIceBarEnabledOnAnyDisplay

        guard isSettingsVisible || isIceBarVisible || anyIceBarEnabled else {
            return
        }

        let targetScreens: [NSScreen]
        if isSettingsVisible {
            targetScreens = [settingsWindow?.screen].compactMap(\.self)
        } else {
            guard let screen = NSScreen.screenWithActiveMenuBar else { return }
            targetScreens = [screen]
        }

        guard !targetScreens.isEmpty else { return }

        let windows = WindowInfo.createWindows(option: .onScreen)
        let activeDisplayID = NSScreen.screenWithActiveMenuBar?.displayID

        var inputs = [(displayID: CGDirectDisplayID, windowIDs: [CGWindowID], bounds: CGRect)]()
        for screen in targetScreens {
            let displayID = screen.displayID
            guard
                let menuBarWindow = WindowInfo.menuBarWindow(from: windows, for: displayID),
                let wallpaperWindow = WindowInfo.wallpaperWindow(from: windows, for: displayID)
            else {
                continue
            }
            let windowIDs = [menuBarWindow.windowID, wallpaperWindow.windowID]
            let bounds = withMutableCopy(of: wallpaperWindow.bounds) { $0.size.height = 1 }
            inputs.append((displayID, windowIDs, bounds))
        }

        captureGeneration += 1
        let generation = captureGeneration

        await withTaskGroup(of: (CGDirectDisplayID, MenuBarAverageColorInfo)?.self) { group in
            for input in inputs {
                group.addTask {
                    guard
                        let image = await ScreenCapture.captureWindowsAsync(
                            with: input.windowIDs,
                            screenBounds: input.bounds,
                            option: .nominalResolution
                        ),
                        let color = image.averageColor(option: .ignoreAlpha)
                    else {
                        return nil
                    }

                    return (
                        input.displayID,
                        MenuBarAverageColorInfo(color: color, source: .menuBarWindow)
                    )
                }
            }

            for await result in group {
                guard captureGeneration == generation else { continue }
                guard let (displayID, info) = result else { continue }
                if averageColors[displayID] != info {
                    averageColors[displayID] = info
                }
                if displayID == activeDisplayID, averageColorInfo != info {
                    averageColorInfo = info
                }
            }
        }
    }

    /// Returns a Boolean value that indicates whether the given display
    /// has a valid menu bar.
    func hasValidMenuBar(in windows: [WindowInfo], for display: CGDirectDisplayID) -> Bool {
        guard
            let window = WindowInfo.menuBarWindow(from: windows, for: display),
            let element = AXHelpers.element(at: window.bounds.origin)
        else {
            return false
        }
        return AXHelpers.role(for: element) == .menuBar
    }

    /// Shows the secondary context menu.
    func showSecondaryContextMenu(at point: CGPoint) {
        let menu = NSMenu(title: "\(Constants.displayName)")

        let editLayoutItem = NSMenuItem(
            title: String(localized: "Edit Menu Bar Layout…"),
            action: #selector(showLayoutEditorPanel),
            keyEquivalent: ""
        )
        editLayoutItem.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Edit Layout")
        editLayoutItem.target = self
        menu.addItem(editLayoutItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: String(localized: "\(Constants.displayName) Settings…"),
            action: #selector(AppDelegate.openSettingsWindow),
            keyEquivalent: ","
        )
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)

        if appState?.settings.advanced.enableSecondaryContextMenuQuit == true {
            menu.addItem(.separator())

            let quitItem = NSMenuItem(
                title: String(localized: "Quit \(Constants.displayName)"),
                action: #selector(quitFromSecondaryContextMenu),
                keyEquivalent: "q"
            )
            quitItem.keyEquivalentModifierMask = .command
            quitItem.target = self
            quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit")
            menu.addItem(quitItem)

            let restartItem = NSMenuItem(
                title: String(localized: "Restart \(Constants.displayName)"),
                action: #selector(restartFromSecondaryContextMenu),
                keyEquivalent: "q"
            )
            restartItem.keyEquivalentModifierMask = [.command, .option]
            restartItem.isAlternate = true
            restartItem.target = self
            restartItem.image = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: "Restart")
            menu.addItem(restartItem)
        }

        menu.popUp(positioning: nil, at: point, in: nil)
    }

    @objc private func quitFromSecondaryContextMenu() {
        // Defer NSApp.terminate until the main run loop is back in default mode.
        // The action fires inside popUp's eventTracking-mode nested run loop, and
        // popUp itself was invoked from a Task that is occupying the main actor.
        // Scheduling in .default only ensures the block runs after popUp tracking
        // unwinds and the enclosing Task completes, so terminate's wait loop can
        // drain the restore and timeout Tasks scheduled by applicationShouldTerminate.
        RunLoop.main.perform(inModes: [.default]) {
            MainActor.assumeIsolated {
                NSApp.terminate(nil)
            }
        }
    }

    @objc private func restartFromSecondaryContextMenu() {
        RunLoop.main.perform(inModes: [.default]) { [weak self] in
            MainActor.assumeIsolated {
                self?.appState?.restartSelf()
            }
        }
    }

    /// Hides the application menus.
    ///
    /// - Important: Uses `.regular` activation policy to hide menus, which briefly shows the app in the Dock.
    func hideApplicationMenus(manual: Bool = false) {
        guard let appState else {
            diagLog.error("Error hiding application menus: Missing app state")
            return
        }

        if isHidingApplicationMenus {
            return
        }

        diagLog.info("Hiding application menus")
        isHidingApplicationMenus = true
        if manual {
            isManuallyHidingApplicationMenus = true
        }

        // Ensure this happens on the main thread
        Task { @MainActor in
            guard isHidingApplicationMenus else { return }

            appState.activate(withPolicy: .regular)

            // Force activation again after a micro-delay.
            // The first activation after policy change can sometimes be ignored by the system.
            try? await Task.sleep(for: .milliseconds(25))
            guard isHidingApplicationMenus else { return }
            appState.activate()
        }
    }

    /// Shows the application menus.
    func showApplicationMenus() {
        guard let appState else {
            diagLog.error("Error showing application menus: Missing app state")
            return
        }
        diagLog.info("Showing application menus")
        appState.deactivate(withPolicy: .accessory)
        isHidingApplicationMenus = false
        isManuallyHidingApplicationMenus = false
    }

    /// Toggles the visibility of the application menus.
    func toggleApplicationMenus() {
        if isHidingApplicationMenus {
            showApplicationMenus()
        } else {
            hideApplicationMenus(manual: true)
        }
    }

    // MARK: - Zen Mode

    /// Whether zen mode is currently active. While active, every concealable
    /// section stays hidden and hover reveal is locked off.
    private(set) var isZenModeActive = false

    /// The sections that were revealed when zen mode was engaged, restored on
    /// exit. Session-only: zen mode never survives an app relaunch.
    private var sectionsRevealedBeforeZenMode: Set<MenuBarSection.Name> = []

    /// The value of ``showOnHoverAllowed`` when zen mode was engaged, restored
    /// on exit. A hotkey reveal locks hover off until the section rehides, and
    /// leaving zen mode must not hand that lock back early.
    private var showOnHoverAllowedBeforeZenMode = true

    /// Toggles zen mode: conceals the hidden and always-hidden sections and
    /// locks reveal gestures until toggled again, then restores what was
    /// showing before. Items are never moved between sections, so engaging or
    /// leaving zen mode performs no layout writes and cannot disturb ordering.
    func toggleZenMode() {
        // An explicit toggle takes ownership away from the monitor: whatever
        // the user just asked for outlives the end of a presentation.
        isZenModeEngagedAutomatically = false
        if isZenModeActive {
            deactivateZenMode()
        } else {
            activateZenMode()
        }
    }

    /// Whether the active zen mode was engaged by ``PresentationMonitor``
    /// rather than by the user. Only an automatic engagement is automatically
    /// withdrawn, so a manual zen mode is never cancelled by unplugging a
    /// projector.
    private var isZenModeEngagedAutomatically = false

    /// Engages or withdraws zen mode on the monitor's behalf.
    ///
    /// Idempotent in both directions, because the monitor re-evaluates its
    /// signals on every display change and every poll rather than tracking
    /// edges itself.
    func setAutomaticZenMode(_ isActive: Bool) {
        if isActive {
            guard !isZenModeActive else { return }
            activateZenMode()
            isZenModeEngagedAutomatically = true
        } else {
            guard isZenModeActive, isZenModeEngagedAutomatically else { return }
            deactivateZenMode()
            isZenModeEngagedAutomatically = false
        }
    }

    private func activateZenMode() {
        // Captured before the hides below, since each hide() re-enables hover
        // reveal and would overwrite the value zen mode has to restore.
        showOnHoverAllowedBeforeZenMode = showOnHoverAllowed
        var revealedNames = Set<MenuBarSection.Name>()
        for name in [MenuBarSection.Name.hidden, .alwaysHidden] {
            guard let section = section(withName: name), section.isEnabled else {
                continue
            }
            if !section.isHidden {
                revealedNames.insert(name)
                section.hide()
            }
        }
        sectionsRevealedBeforeZenMode = revealedNames
        // Each hide() runs resetClosedPresentationState, which re-enables
        // hover reveal; set the lock after all hides so it sticks.
        showOnHoverAllowed = false
        isZenModeActive = true
    }

    private func deactivateZenMode() {
        isZenModeActive = false
        showOnHoverAllowed = showOnHoverAllowedBeforeZenMode
        showOnHoverAllowedBeforeZenMode = true
        for name in sectionsRevealedBeforeZenMode {
            section(withName: name)?.show()
        }
        sectionsRevealedBeforeZenMode = []
    }

    /// Shows the layout editor panel.
    @objc private func showLayoutEditorPanel() {
        guard let screen = MenuBarLayoutEditorPanel.defaultScreen else {
            return
        }
        layoutEditorPanel.show(on: screen) {
            self.dismissLayoutEditorPanel()
        }
    }

    /// Dismisses the layout editor panel.
    func dismissLayoutEditorPanel() {
        layoutEditorPanel.close()
    }


    /// Updates the ``lastShowTimestamp`` property.
    func updateLastShowTimestamp() {
        lastShowTimestamp = .now
    }

    /// Delay for a focus-change rehide. A focus change during the reveal
    /// grace period is deferred to the end of that period rather than lost.
    /// Smart waits longer for focus to settle than focusedApp because it
    /// re-checks state (open menus) that a fresh activation can still churn.
    static nonisolated func rehideDelay(
        for strategy: RehideStrategy,
        since lastShow: ContinuousClock.Instant?,
        now: ContinuousClock.Instant = .now
    ) -> Duration {
        let focusSettleDelay: Duration = strategy == .smart
            ? .milliseconds(250)
            : .milliseconds(100)
        guard let lastShow else { return focusSettleDelay }
        let remainingGrace = Duration.milliseconds(500) - lastShow.duration(to: now)
        return max(focusSettleDelay, remainingGrace)
    }

    /// XMenuBar temporarily activates itself when it must hide application menus.
    /// That internal activation is not a user focus change and must not rehide
    /// the section that caused it.
    static nonisolated func shouldHandleAutoRehideActivation(
        activatedProcessIdentifier: pid_t?,
        currentProcessIdentifier: pid_t
    ) -> Bool {
        activatedProcessIdentifier != currentProcessIdentifier
    }

    private func hideVisibleSections() {
        for section in sections where !section.isHidden {
            section.hide()
        }
    }

    /// Updates the control item states for all sections.
    ///
    /// - Parameter screen: The screen to use for the update. If `nil`, the
    ///   best screen is determined automatically.
    func updateControlItemStates(for screen: NSScreen? = nil) {
        for section in sections {
            section.updateControlItemState(for: screen)
        }
    }

    /// Returns the menu bar section with the given name.
    /// Returns the hidden section that currently contains the given item,
    /// or `nil` when the item is already visible or is not on the bar.
    ///
    /// Only the concealing sections are considered: an item blinking in the
    /// visible section has already been seen, so there is nothing to
    /// surface.
    /// The concealable section whose cache currently holds `tag`, regardless
    /// of whether the section is shown. An item outside hidden/always-hidden
    /// has no concealing section and returns `nil`.
    private func concealingSection(
        containing tag: MenuBarItemTag,
        in appState: AppState
    ) -> MenuBarSection? {
        for name in [MenuBarSection.Name.hidden, .alwaysHidden] {
            guard appState.itemManager.itemCache[name].contains(where: { $0.tag == tag }) else {
                continue
            }
            return section(withName: name)
        }
        return nil
    }

    func section(withName name: MenuBarSection.Name) -> MenuBarSection? {
        sections.first { $0.name == name }
    }

    /// Returns the control item for the menu bar section with the given name.
    func controlItem(withName name: MenuBarSection.Name) -> ControlItem? {
        section(withName: name)?.controlItem
    }
}

// MARK: - MenuBarAverageColorInfo

/// Information for the average color of the menu bar.
struct MenuBarAverageColorInfo: Hashable {
    /// Sources used to compute the average color of the menu bar.
    enum Source: Hashable {
        case menuBarWindow
        case desktopWallpaper
    }

    /// The average color of the menu bar
    var color: CGColor

    /// The source used to compute the color.
    var source: Source

    /// The brightness of the menu bar's color.
    var brightness: CGFloat {
        color.brightness ?? 0
    }

    /// A Boolean value that indicates whether the menu bar has a
    /// bright color.
    ///
    /// This value is `true` if ``brightness`` is above ``Constants.menuBarBrightnessThreshold``.
    /// At the time of writing, if this value is `true`, the menu bar
    /// draws its items with a darker appearance.
    var isBright: Bool {
        brightness > Constants.menuBarBrightnessThreshold
    }

    /// Returns whether the menu bar has a bright color for the given screen.
    /// Uses a lower threshold for notched displays to bias toward black text.
    /// - Parameter screen: The screen to check for notch presence
    /// - Returns: `true` if the background is bright enough to require dark text
    func isBright(for screen: NSScreen?) -> Bool {
        let activeOrPassed = screen ?? NSScreen.screenWithActiveMenuBar
        let hasNotch = activeOrPassed?.hasNotch == true
        let threshold = hasNotch
            ? Constants.notchedDisplayBrightnessThreshold
            : Constants.menuBarBrightnessThreshold
        return brightness > threshold
    }
}
