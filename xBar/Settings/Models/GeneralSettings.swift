//
//  GeneralSettings.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Combine
import SwiftUI

// MARK: - GeneralSettings

/// Model for the app's General settings.
@MainActor
@Observable
final class GeneralSettings {
    private let diagLog = DiagLog(category: "GeneralSettings")

    /// Whether the settings window shows a single curated page instead of
    /// the full sidebar navigation. Nothing is lost either way: every other
    /// pane keeps its configuration and stays reachable through the settings
    /// URI, and turning Simple Mode off brings the full sidebar back.
    var simpleMode = Defaults.DefaultValue.simpleMode {
        didSet {
            guard oldValue != simpleMode else { return }
            Defaults.set(simpleMode, forKey: .simpleMode)
        }
    }

    /// The operation mode determining how menu bar items are displayed and managed.
    var operationMode = Defaults.DefaultValue.operationMode {
        didSet {
            guard oldValue != operationMode else { return }
            Defaults.set(operationMode.rawValue, forKey: .operationMode)
        }
    }

    /// An icon to show in the menu bar, with a different image
    /// for when items are visible or hidden.
    var iceIcon = Defaults.DefaultValue.iceIcon {
        didSet {
            guard oldValue != iceIcon else { return }
            if case .custom = iceIcon.name {
                lastCustomIceIcon = iceIcon
            }
            do {
                let data = try encoder.encode(iceIcon)
                Defaults.set(data, forKey: .iceIcon)
            } catch {
                diagLog.error("Error encoding \(Constants.displayName) icon: \(error)")
            }
        }
    }

    /// The last user-selected custom Ice icon.
    var lastCustomIceIcon: ControlItemImageSet?

    /// A Boolean value that indicates whether custom Ice icons
    /// should be rendered as template images.
    var customIceIconIsTemplate = Defaults.DefaultValue.customIceIconIsTemplate {
        didSet {
            guard oldValue != customIceIconIsTemplate else { return }
            Defaults.set(customIceIconIsTemplate, forKey: .customIceIconIsTemplate)
        }
    }

    // MARK: - Deprecated (Per-Display Migration)

    // These properties are kept for one release cycle for downgrade safety.
    // New code should use `AppSettings.displaySettings` instead.

    /// A Boolean value that indicates whether to show hidden items
    /// in a separate bar below the menu bar.
    var useIceBar = Defaults.DefaultValue.useIceBar {
        didSet {
            guard oldValue != useIceBar else { return }
            Defaults.set(useIceBar, forKey: .useIceBar)
        }
    }

    /// A Boolean value that indicates whether to use the XMenuBar Bar
    /// only on displays with a notch.
    var useIceBarOnlyOnNotchedDisplay = Defaults.DefaultValue.useIceBarOnlyOnNotchedDisplay {
        didSet {
            guard oldValue != useIceBarOnlyOnNotchedDisplay else { return }
            Defaults.set(useIceBarOnlyOnNotchedDisplay, forKey: .useIceBarOnlyOnNotchedDisplay)
        }
    }

    /// The location where the XMenuBar Bar appears.
    var iceBarLocation = Defaults.DefaultValue.iceBarLocation {
        didSet {
            guard oldValue != iceBarLocation else { return }
            Defaults.set(iceBarLocation.rawValue, forKey: .iceBarLocation)
        }
    }

    /// A Boolean value that indicates whether the XMenuBar Bar should
    /// appear at the mouse pointer's location when shown by a hotkey.
    var iceBarLocationOnHotkey = Defaults.DefaultValue.iceBarLocationOnHotkey {
        didSet {
            guard oldValue != iceBarLocationOnHotkey else { return }
            Defaults.set(iceBarLocationOnHotkey, forKey: .iceBarLocationOnHotkey)
        }
    }

    /// A Boolean value that indicates whether the hidden section
    /// should be shown when the mouse pointer clicks in an empty
    /// area of the menu bar.
    var showOnClick = Defaults.DefaultValue.showOnClick {
        didSet {
            guard oldValue != showOnClick else { return }
            Defaults.set(showOnClick, forKey: .showOnClick)
        }
    }

    /// A Boolean value that indicates whether the always-hidden section
    /// should be shown when the mouse pointer double-clicks in an
    /// empty area of the menu bar.
    var showOnDoubleClick = Defaults.DefaultValue.showOnDoubleClick {
        didSet {
            guard oldValue != showOnDoubleClick else { return }
            Defaults.set(showOnDoubleClick, forKey: .showOnDoubleClick)
        }
    }

    /// A Boolean value that indicates whether the hidden section
    /// should be shown when the mouse pointer hovers over an
    /// empty area of the menu bar.
    var showOnHover = Defaults.DefaultValue.showOnHover {
        didSet {
            guard oldValue != showOnHover else { return }
            Defaults.set(showOnHover, forKey: .showOnHover)
        }
    }

    /// A Boolean value that indicates whether the hidden section
    /// should be shown or hidden when the user scrolls in the
    /// menu bar.
    var showOnScroll = Defaults.DefaultValue.showOnScroll {
        didSet {
            guard oldValue != showOnScroll else { return }
            Defaults.set(showOnScroll, forKey: .showOnScroll)
        }
    }

    /// An action that reveals hidden items when interacting with an empty area of the menu bar.
    enum EmptyAreaAction: String, CaseIterable, Identifiable, Codable, Sendable {
        case none = "none"
        case click = "click"
        case hover = "hover"
        case scroll = "scroll"

        var id: String { rawValue }

        var localized: LocalizedStringKey {
            switch self {
            case .none: "None"
            case .click: "Show on click"
            case .hover: "Show on hover"
            case .scroll: "Show on scroll"
            }
        }

        var shortTitle: LocalizedStringKey {
            switch self {
            case .none: "None"
            case .click: "Click"
            case .hover: "Hover"
            case .scroll: "Scroll"
            }
        }

        var iconName: String {
            switch self {
            case .none: "slash.circle"
            case .click: "cursorarrow.click.2"
            case .hover: "cursorarrow.motionlines"
            case .scroll: "arrow.up.and.down.circle"
            }
        }
    }

    /// The single-choice action to perform when interacting with an empty area of the menu bar.
    var emptyAreaAction: EmptyAreaAction {
        get {
            if showOnHover {
                return .hover
            } else if showOnClick {
                return .click
            } else if showOnScroll {
                return .scroll
            } else {
                return .none
            }
        }
        set {
            switch newValue {
            case .none:
                showOnClick = false
                showOnHover = false
                showOnScroll = false
            case .click:
                showOnClick = true
                showOnHover = false
                showOnScroll = false
            case .hover:
                showOnClick = false
                showOnHover = true
                showOnScroll = false
            case .scroll:
                showOnClick = false
                showOnHover = false
                showOnScroll = true
            }
        }
    }

    // The offset to apply to the menu bar item spacing and padding.

    /// A Boolean value that indicates whether the hidden section
    /// should automatically rehide.
    var autoRehide = Defaults.DefaultValue.autoRehide {
        didSet {
            guard oldValue != autoRehide else { return }
            Defaults.set(autoRehide, forKey: .autoRehide)
        }
    }

    /// A strategy that determines how the auto-rehide feature works.
    var rehideStrategy = Defaults.DefaultValue.rehideStrategy {
        didSet {
            guard oldValue != rehideStrategy else { return }
            Defaults.set(rehideStrategy.rawValue, forKey: .rehideStrategy)
        }
    }

    /// A time interval for the auto-rehide feature when its rule
    /// is ``RehideStrategy/timed``.
    var rehideInterval = Defaults.DefaultValue.rehideInterval {
        didSet {
            guard oldValue != rehideInterval else { return }
            Defaults.set(rehideInterval, forKey: .rehideInterval)
        }
    }

    /// Encoder for properties.
    @ObservationIgnored
    private let encoder = JSONEncoder()

    /// Decoder for properties.
    @ObservationIgnored
    private let decoder = JSONDecoder()

    /// Storage for internal observers.
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    /// The shared app state.
    @ObservationIgnored
    private(set) weak var appState: AppState?

    /// Performs the initial setup of the model.
    ///
    /// The app state is only stored, never read, by this model: the setup it
    /// performs is reading `Defaults` and subscribing to the Settings-URI
    /// notification. The parameter is optional so that setup can be driven
    /// without standing up an ``AppState``; the app always passes one.
    func performSetup(with appState: AppState? = nil) {
        self.appState = appState
        loadInitialState()
        configureObservers()
    }

    /// Loads the model's initial state.
    private func loadInitialState() {
        Defaults.ifPresent(key: .customIceIconIsTemplate, assign: &customIceIconIsTemplate)
        Defaults.ifPresent(key: .useIceBar, assign: &useIceBar)
        Defaults.ifPresent(key: .useIceBarOnlyOnNotchedDisplay, assign: &useIceBarOnlyOnNotchedDisplay)
        Defaults.ifPresent(key: .iceBarLocationOnHotkey, assign: &iceBarLocationOnHotkey)
        Defaults.ifPresent(key: .showOnClick, assign: &showOnClick)
        Defaults.ifPresent(key: .showOnDoubleClick, assign: &showOnDoubleClick)
        Defaults.ifPresent(key: .showOnHover, assign: &showOnHover)
        Defaults.ifPresent(key: .showOnScroll, assign: &showOnScroll)
        autoRehide = true
        Defaults.set(true, forKey: .autoRehide)
        Defaults.ifPresent(key: .simpleMode, assign: &simpleMode)
        Defaults.ifPresent(key: .rehideInterval, assign: &rehideInterval)

        Defaults.ifPresent(key: .iceBarLocation) { rawValue in
            if let location = IceBarLocation(rawValue: rawValue) {
                iceBarLocation = location
            }
        }
        Defaults.ifPresent(key: .rehideStrategy) { rawValue in
            if let strategy = RehideStrategy(rawValue: rawValue) {
                rehideStrategy = strategy
            }
        }
        Defaults.ifPresent(key: .operationMode) { rawValue in
            if let mode = OperationMode(rawValue: rawValue) {
                operationMode = mode
            }
        }
        if operationMode == .floatingLive && !ScreenCapture.cachedCheckPermissions() {
            operationMode = .inline
        }

        if let data = Defaults.data(forKey: .iceIcon) {
            do {
                iceIcon = try decoder.decode(ControlItemImageSet.self, from: data)
            } catch {
                diagLog.error("Error decoding \(Constants.displayName) icon: \(error)")
            }
            if case .custom = iceIcon.name {
                lastCustomIceIcon = iceIcon
            }
        }
    }

    /// Configures the internal observers for the model.
    ///
    /// Persistence for most properties is now driven by `didSet` on each
    /// property (see above), replacing the previous `$property.persistToDefaults`
    /// Combine pipelines. Only the Settings-URI notification subscription
    /// remains Combine-based here.
    private func configureObservers() {
        cancellables = [
            NotificationCenter.observeSettingsChangesViaURI { [weak self] change in
                self?.handleExternalSettingsChange(change)
            },
        ]
    }

    /// Handles settings changed externally via Settings URI scheme.
    private func handleExternalSettingsChange(_ change: ExternalSettingsChange) {
        let key = change.key

        // Handle boolean values
        if let boolValue = change.boolValue {
            diagLog.debug("GeneralSettings: Received external change for \(key) = \(boolValue)")

            switch key {
            case "customIceIconIsTemplate" where customIceIconIsTemplate != boolValue:
                customIceIconIsTemplate = boolValue
            case "useIceBar" where useIceBar != boolValue:
                useIceBar = boolValue
            case "useIceBarOnlyOnNotchedDisplay" where useIceBarOnlyOnNotchedDisplay != boolValue:
                useIceBarOnlyOnNotchedDisplay = boolValue
            case "iceBarLocationOnHotkey" where iceBarLocationOnHotkey != boolValue:
                iceBarLocationOnHotkey = boolValue
            case "showOnClick" where showOnClick != boolValue:
                showOnClick = boolValue
            case "showOnDoubleClick" where showOnDoubleClick != boolValue:
                showOnDoubleClick = boolValue
            case "showOnHover" where showOnHover != boolValue:
                showOnHover = boolValue
            case "showOnScroll" where showOnScroll != boolValue:
                showOnScroll = boolValue
            case "autoRehide" where autoRehide != boolValue:
                autoRehide = boolValue
            default:
                // Key not handled by GeneralSettings or value unchanged
                break
            }
        }

        // Handle double values
        if let doubleValue = change.doubleValue {
            diagLog.debug("GeneralSettings: Received external change for \(key) = \(doubleValue)")

            if key == "rehideInterval", rehideInterval != doubleValue {
                rehideInterval = doubleValue
            }
        }

        // Handle enum values (raw integers)
        if let rawEnumValue = change.rawEnumValue {
            diagLog.debug("GeneralSettings: Received external change for \(key) = \(rawEnumValue)")

            if key == "rehideStrategy",
               let strategy = RehideStrategy(rawValue: rawEnumValue),
               rehideStrategy != strategy
            {
                rehideStrategy = strategy
            }
        }
    }
}
