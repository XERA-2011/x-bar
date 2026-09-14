//
//  DisplaySettingsManager+Live.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AsyncAlgorithms
import Cocoa
import Combine

/// The live half of ``DisplaySettingsManager``: everything whose substance
/// needs a running `AppState`, real `NSScreen`/WindowServer display state,
/// the on-disk NSStatusItemSpacing global domain, or an app-modal alert.
/// None of that can run in a unit test, so this file is excluded from
/// coverage in sonar-project.properties.
///
/// The measured half (DisplaySettingsManager.swift) keeps persistence,
/// lookup, mutation, URI handling, and every decision rule — including
/// `shouldSkipSpacingApply`, which this file's observer consults. New
/// decision logic belongs there, not here.
extension DisplaySettingsManager {
    /// Performs the initial setup of the manager.
    func performSetup(with appState: AppState) {
        self.appState = appState
        configureObservers()
        captureCurrentlyConnectedDisplays()
    }

    /// Merges info for currently-connected displays into the knownDisplays
    /// cache. Idempotent and cheap; called on launch and on every
    /// screen-parameters-changed notification so the cache always reflects
    /// the latest known names.
    ///
    /// Skips screens whose localizedName is empty: that can happen for
    /// mirrored slave displays or briefly during GPU/sleep transitions, and
    /// caching such entries pollutes the Displays pane with anonymous rows.
    private func captureCurrentlyConnectedDisplays() {
        var updated = knownDisplays
        var changed = false
        var seededConfigurations = configurations
        var configurationsChanged = false
        for screen in NSScreen.screens {
            guard let uuid = Bridging.getDisplayUUIDString(for: screen.displayID) else {
                continue
            }
            let trimmed = screen.localizedName.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let entry = KnownDisplay(name: trimmed, hasNotch: screen.hasNotch)
            if updated[uuid] != entry {
                updated[uuid] = entry
                changed = true
            }
            // Seed an entry for newly-detected displays from the current
            // global template so first-time connections inherit the
            // user's chosen defaults instead of falling through to
            // DisplayIceBarConfiguration.defaultConfiguration at read time.
            // Existing entries are left alone so per-display overrides
            // are preserved across reconnects.
            if seededConfigurations[uuid] == nil {
                seededConfigurations[uuid] = globalConfiguration
                configurationsChanged = true
            }
        }
        if changed {
            knownDisplays = updated
        }
        if configurationsChanged {
            configurations = seededConfigurations
        }
    }

    // MARK: - System Spacing Seed

    /// Default baseline for NSStatusItemSpacing and NSStatusItemSelectionPadding,
    /// kept in sync with MenuBarItemSpacingManager.Key.defaultValue. Used to
    /// translate on-disk system spacing into XMenuBar's relative offset model.
    private static let systemSpacingDefault = 16

    /// Reads the current system value for NSStatusItemSpacing from the byHost
    /// global domain. Returns nil when the key is unset, letting callers
    /// distinguish "user has explicitly configured spacing" from "macOS
    /// default applies".
    private static func currentSystemSpacing() -> Int? {
        CFPreferencesCopyValue(
            "NSStatusItemSpacing" as CFString,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        ) as? Int
    }

    /// When the user has manually set NSStatusItemSpacing outside of XMenuBar
    /// (e.g. via a defaults write in Terminal), seed an entry for each
    /// connected display whose itemSpacingOffset corresponds to that on-disk
    /// value. Without this, applyActiveDisplaySpacing on first launch reads
    /// the default offset of 0, computes target = 16, sees on-disk = N, and
    /// fires a relaunch wave that rewrites the user's manual setting back to
    /// 16. The seeded entries are written to Defaults inline because the
    /// persistence sink is not yet wired at loadInitialState time; without
    /// the explicit save, subsequent launches would re-seed on every start
    /// instead of remembering the adopted value. The padding key is not
    /// consulted because XMenuBar drives both keys from a single offset; users
    /// whose padding diverges from spacing will see one normalising relaunch
    /// on first launch but no recurring waves thereafter.
    ///
    /// Internal rather than private because `loadInitialState()` — which
    /// stays in the measured file — calls it on first launch.
    func seedConfigurationsFromSystemSpacing() {
        guard let onDisk = Self.currentSystemSpacing(),
              onDisk != Self.systemSpacingDefault
        else {
            return
        }
        let offset = Double(onDisk - Self.systemSpacingDefault)
        var seeded = configurations
        for screen in NSScreen.screens {
            guard let uuid = Bridging.getDisplayUUIDString(for: screen.displayID) else {
                continue
            }
            if seeded[uuid] != nil {
                continue
            }
            seeded[uuid] = globalConfiguration.withItemSpacingOffset(offset)
        }
        guard seeded != configurations else { return }
        configurations = seeded
        do {
            let data = try encoder.encode(seeded)
            Defaults.set(data, forKey: .displayIceBarConfigurations)
            diagLog.info(
                "Seeded itemSpacingOffset=\(offset) from external NSStatusItemSpacing=\(onDisk) for \(seeded.count) display(s)"
            )
        } catch {
            diagLog.error("Failed to persist seeded per-display configurations: \(error)")
        }
    }

    // MARK: - Observers

    /// Configures the manager's non-persistence internal observers: the
    /// debounced screen-parameters watcher and the Settings-URI notification
    /// subscription. Property persistence is now driven by `didSet` on each
    /// property (see the property declarations in the measured file),
    /// replacing the previous `$property.persistToDefaults`/manual
    /// `.dropFirst()` sinks.
    private func configureObservers() {
        var c = Set<AnyCancellable>()

        // Listen for display connect/disconnect to log changes, refresh the
        // known-display cache, and re-derive the active display's spacing.
        //
        // Debounced because didChangeScreenParametersNotification fires
        // repeatedly during a single user action: docking, lid close,
        // monitor sleep/wake, KVM switch, Sidecar handshake, and external
        // display flicker can each post several notifications within a
        // few hundred milliseconds. Without the debounce, every flap
        // could trigger a relaunch wave (the no-op guard catches the
        // common case but does not cover oscillating values during the
        // flap window). One second coalesces a single docking event into
        // one apply.
        //
        // `debouncedNotificationTask` registers the observer before it
        // returns, so a notification posted during task startup cannot slip
        // past, and the task's defer removes it — the non-Sendable observer
        // token stays off the class and the nonisolated deinit only needs
        // to cancel the task.
        //
        // A repeated setup must not leave the previous task — and the
        // NotificationCenter observer its defer owns — running.
        screenParametersTask?.cancel()
        screenParametersTask = debouncedNotificationTask(
            center: .default,
            name: NSApplication.didChangeScreenParametersNotification,
            interval: .seconds(1)
        ) { [weak self] in
            guard let self else { return }
            diagLog.info("Screen parameters changed — \(NSScreen.screens.count) screen(s) connected")
            captureCurrentlyConnectedDisplays()
        }

        // Listen for external per-display settings changes via Settings URI
        NotificationCenter.default
            .publisher(for: .perDisplaySettingsDidChangeViaURI)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleExternalPerDisplaySettingsChange(notification)
            }
            .store(in: &c)

        cancellables = c
    }
}
