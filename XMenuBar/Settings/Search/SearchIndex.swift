//
//  SearchIndex.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

// MARK: - SettingsProperty

/// Links a search entry to the `@Published` property it represents on a
/// settings model, so the drift-guard test can assert every user-facing
/// property has a matching entry.
nonisolated enum SettingsProperty: Hashable {
    case general(String)
    case advanced(String)
}

// MARK: - SearchEntry

/// One searchable row in the settings search index.
///
/// `titleKey`/`sectionKey` reuse the exact `LocalizedStringKey` literals from
/// the settings panes so no new translation keys are introduced for titles or
/// section headers — they resolve to the same catalog entries the panes use.
/// `titleText`/`sectionText`/`descriptionText` are the English source strings,
/// which are also the catalog keys, so ``localizedTitle(bundle:)`` and its
/// siblings resolve them to the running localization for fuzzy matching. `keywords`
/// stays English: it is a search-only alias list with no catalog entries, and
/// the English title is indexed alongside the translated one so terms users
/// saw in docs or release notes keep matching in a localized build.
///
/// Conforms to `@unchecked Sendable` (not `Hashable`) so the static index
/// arrays are concurrency-safe under Swift 6 strict concurrency.
/// `LocalizedStringKey` is not `Sendable`-annotated in this SDK and not
/// `Hashable`; the entry is immutable (all `let`), so unchecked Sendable
/// conformance is safe — matching the precedent set by `SectionedListItem`.
/// `Identifiable.id` is `String`, which is `Hashable`, so `Identifiable` is
/// satisfied without the whole struct being `Hashable`.
nonisolated struct SearchEntry: Identifiable, @unchecked Sendable {
    let id: String
    let titleKey: LocalizedStringKey
    let titleText: String
    let descriptionText: String?
    let pane: SettingsNavigationIdentifier
    let sectionKey: LocalizedStringKey?
    let sectionText: String?
    let keywords: [String]
    let property: SettingsProperty?

    /// The title as the settings pane renders it.
    ///
    /// The English source doubles as the catalog key, so this resolves the
    /// same entry the pane's `titleKey` does.
    ///
    /// - Parameter bundle: The bundle to resolve against. Defaults to
    ///   `.main`, which picks the running localization; tests pass a
    ///   specific `.lproj` bundle, since the `locale:` argument of
    ///   `String(localized:)` only selects formatting, not which
    ///   localization is looked up.
    func localizedTitle(bundle: Bundle = .main) -> String {
        String(localized: String.LocalizationValue(titleText), bundle: bundle)
    }

    /// The section header as rendered, when the entry has one.
    func localizedSection(bundle: Bundle = .main) -> String? {
        sectionText.map { String(localized: String.LocalizationValue($0), bundle: bundle) }
    }

    /// The annotation text as rendered, when the entry has one.
    func localizedDescription(bundle: Bundle = .main) -> String? {
        descriptionText.map { String(localized: String.LocalizationValue($0), bundle: bundle) }
    }

    var disclosure: AppNavigationState.SettingsDisclosure? {
        switch id {
        case "advanced.alwaysUseAppIconForMenuBarItems",
             "advanced.automaticArrangementEnabled",
             "advanced.enableMenuBarItemOverflow",
             "advanced.useXMenuBarBarOnNotchOverflow",
             "advanced.menuBarOrderFulfillmentTimeout":
            .advancedLayoutControls
        default:
            nil
        }
    }
}

// MARK: - SearchIndex

nonisolated enum SearchIndex {
    /// Entries indexed on every supported macOS release.
    private static let sharedEntries: [SearchEntry] = paneEntries + generalEntries + revealEntries + layoutEntries

    /// macOS 27-only settings rows, appended when the sidebar search UI is
    /// available. Currently empty: rows are only added here once a matching
    /// control is actually exposed in a settings pane.
    private static let macOS27Entries: [SearchEntry] = []

    /// All searchable settings entries, in pane order.
    ///
    /// The set is static for a given OS, so it is resolved once and cached
    /// rather than re-concatenated on every access (the search path reads it
    /// per keystroke).
    static let entries: [SearchEntry] = {
        if #available(macOS 27, *) {
            return sharedEntries + macOS27Entries
        }
        return sharedEntries
    }()

    /// `@Published` property names that are intentionally absent from the
    /// index because they are deprecated, internal, or currently commented out
    /// of the UI. The drift-guard test allows these.
    private static let baseNonSearchableProperties: Set<SettingsProperty> = [
        .general("lastCustomIceIcon"),
        .general("useIceBar"),
        .general("useIceBarOnlyOnNotchedDisplay"),
        .general("iceBarLocation"),
        // URI/Defaults-only experimental toggle with no Settings UI; excluded
        // on every OS version rather than only on macOS <27.
        .advanced("enableExperimentalOverflowPrevention"),
    ]

    /// Advanced settings that only participate in search on macOS 27.
    private static let macOS27AdvancedNonSearchableProperties: Set<SettingsProperty> = [
        .advanced("enableExperimentalWindowHiding"),
        .advanced("enableExperimentalSystemItemHiding"),
        .advanced("menuBarOrderFulfillmentTimeout"),
    ]

    static var nonSearchableProperties: Set<SettingsProperty> {
        if #available(macOS 27, *) {
            return baseNonSearchableProperties.union([.advanced("enableExperimentalWindowHiding")])
        }
        return baseNonSearchableProperties.union(macOS27AdvancedNonSearchableProperties)
    }

    /// ``entries`` bucketed by pane, resolved once for the same reason
    /// ``entries`` itself is: the search path reads it per keystroke, and a
    /// filter per lookup rescans the whole index for each pane.
    private static let entriesByPane: [SettingsNavigationIdentifier: [SearchEntry]] =
        Dictionary(grouping: entries, by: \.pane)

    /// Returns the entries that belong to the given pane.
    static func entries(for pane: SettingsNavigationIdentifier) -> [SearchEntry] {
        entriesByPane[pane] ?? []
    }

    /// Pure relevance sort: Fuse's `diffScore` is `0` for a perfect match and
    /// increases with worse matches, so the best result has the lowest score.
    /// Delegates to ``SearchRanker/sortedByRelevance(_:)``, the pipe shared
    /// with menu bar item search, so the two surfaces can't drift apart.
    static func sortedByRelevance<T>(_ items: [(item: T, diffScore: Double)]) -> [T] {
        SearchRanker.sortedByRelevance(items)
    }

    // MARK: Pane Rows

    private static let paneEntries: [SearchEntry] = [
        SearchEntry(
            id: "pane.general",
            titleKey: "General",
            titleText: "General",
            descriptionText: nil,
            pane: .general,
            sectionKey: nil,
            sectionText: nil,
            keywords: ["general", "launch", "startup", "login", "icon", "reveal", "show", "hide", "hover", "click", "scroll", "rehide", "gesture"],
            property: nil
        ),
        SearchEntry(
            id: "pane.menuBarLayout",
            titleKey: "Layout",
            titleText: "Layout",
            descriptionText: nil,
            pane: .menuBarLayout,
            sectionKey: nil,
            sectionText: nil,
            keywords: ["layout", "arrange", "drag", "reorder", "sections", "reset", "overflow", "system items", "always hidden", "divider"],
            property: nil
        ),
        SearchEntry(
            id: "pane.about",
            titleKey: "About",
            titleText: "About",
            descriptionText: nil,
            pane: .about,
            sectionKey: nil,
            sectionText: nil,
            keywords: ["about", "version", "update", "credits", "license"],
            property: nil
        ),
    ]

    // MARK: General Settings

    private static let generalEntries: [SearchEntry] = [
        SearchEntry(
            id: "general.launchAtLogin",
            titleKey: "Launch at Login",
            titleText: "Launch at Login",
            descriptionText: nil,
            pane: .general,
            sectionKey: nil,
            sectionText: nil,
            keywords: ["launch", "login", "startup", "auto", "start"],
            property: nil
        ),
        SearchEntry(
            id: "general.showSettingDescriptions",
            titleKey: "Show setting descriptions",
            titleText: "Show setting descriptions",
            descriptionText: "Explains what a setting does directly beneath it.",
            pane: .general,
            sectionKey: nil,
            sectionText: nil,
            keywords: ["descriptions", "explanations", "captions", "help text", "show"],
            property: .general("showSettingDescriptions")
        ),
        SearchEntry(
            id: "general.simpleMode",
            titleKey: "Simple Mode",
            titleText: "Simple Mode",
            descriptionText: "Show a single curated settings page instead of the full sidebar.",
            pane: .general,
            sectionKey: nil,
            sectionText: nil,
            keywords: ["simple mode", "simple", "basic", "minimal", "settings layout"],
            property: .general("simpleMode")
        ),
        SearchEntry(
            id: "general.showIceIcon",
            titleKey: "Show \(Constants.displayName) icon",
            titleText: "Show \(Constants.displayName) icon",
            descriptionText: "Show the \(Constants.displayName) icon in the menu bar. Click to show hidden items, double-click for always-hidden, and right-click for settings.",
            pane: .general,
            sectionKey: nil,
            sectionText: nil,
            keywords: ["icon", "show", "menu bar", "status item"],
            property: .general("showIceIcon")
        ),
        SearchEntry(
            id: "general.iceIcon",
            titleKey: "\(Constants.displayName) icon",
            titleText: "\(Constants.displayName) icon",
            descriptionText: "Choose a custom icon to show in the menu bar.",
            pane: .general,
            sectionKey: nil,
            sectionText: nil,
            keywords: ["icon", "picker", "custom", "image"],
            property: .general("iceIcon")
        ),
        SearchEntry(
            id: "general.customIceIconIsTemplate",
            titleKey: "Custom icon uses dynamic appearance",
            titleText: "Custom icon uses dynamic appearance",
            descriptionText: "Display the icon as a monochrome image that dynamically adjusts to match the menu bar's appearance.",
            pane: .general,
            sectionKey: nil,
            sectionText: nil,
            keywords: ["template", "monochrome", "dark mode", "custom icon"],
            property: .general("customIceIconIsTemplate")
        ),
    ]

    // MARK: Reveal Settings

    private static let revealEntries: [SearchEntry] = [
        SearchEntry(
            id: "general.showOnClick",
            titleKey: "Show on click",
            titleText: "Show on click",
            descriptionText: "Click an empty area of the menu bar to show hidden menu bar items.",
            pane: .general,
            sectionKey: "Empty menu bar area",
            sectionText: "Empty menu bar area",
            keywords: ["click", "show", "hidden"],
            property: .general("showOnClick")
        ),
        SearchEntry(
            id: "general.showOnDoubleClick",
            titleKey: "Double-click for always-hidden",
            titleText: "Double-click for always-hidden",
            descriptionText: "Double-click an empty area of the menu bar to show always-hidden menu bar items.",
            pane: .general,
            sectionKey: "Empty menu bar area",
            sectionText: "Empty menu bar area",
            keywords: ["double click", "always hidden", "show"],
            property: .general("showOnDoubleClick")
        ),
        SearchEntry(
            id: "general.showOnHover",
            titleKey: "Show on hover",
            titleText: "Show on hover",
            descriptionText: "Hover over an empty area of the menu bar to show hidden menu bar items.",
            pane: .general,
            sectionKey: "Empty menu bar area",
            sectionText: "Empty menu bar area",
            keywords: ["hover", "show", "hidden", "mouse"],
            property: .general("showOnHover")
        ),
        SearchEntry(
            id: "general.showOnScroll",
            titleKey: "Show on scroll",
            titleText: "Show on scroll",
            descriptionText: "Scroll or swipe in the menu bar to show hidden menu bar items.",
            pane: .general,
            sectionKey: "Empty menu bar area",
            sectionText: "Empty menu bar area",
            keywords: ["scroll", "swipe", "show", "hidden", "gesture"],
            property: .general("showOnScroll")
        ),
        SearchEntry(
            id: "general.autoRehide",
            titleKey: "Automatically rehide",
            titleText: "Automatically rehide",
            descriptionText: nil,
            pane: .general,
            sectionKey: "After revealing",
            sectionText: "After revealing",
            keywords: ["rehide", "auto", "automatic", "hide"],
            property: .general("autoRehide")
        ),
        SearchEntry(
            id: "general.rehideStrategy",
            titleKey: "Strategy",
            titleText: "Rehide strategy",
            descriptionText: nil,
            pane: .general,
            sectionKey: "After revealing",
            sectionText: "After revealing",
            keywords: ["rehide", "strategy", "smart", "timed", "focused app"],
            property: .general("rehideStrategy")
        ),
        SearchEntry(
            id: "general.rehideInterval",
            titleKey: "Rehide interval",
            titleText: "Rehide interval",
            descriptionText: "Menu bar items are rehidden after a fixed amount of time.",
            pane: .general,
            sectionKey: "After revealing",
            sectionText: "After revealing",
            keywords: ["rehide", "interval", "timed", "seconds", "delay"],
            property: .general("rehideInterval")
        ),
        SearchEntry(
            id: "advanced.useOptionClickToShowAlwaysHiddenSection",
            titleKey: "Use Option-click to open always-hidden section",
            titleText: "Use Option-click to open always-hidden section",
            descriptionText: nil,
            pane: .general,
            sectionKey: "\(Constants.displayName) icon",
            sectionText: "\(Constants.displayName) icon",
            keywords: ["option", "click", "always hidden", "alt"],
            property: .advanced("useOptionClickToShowAlwaysHiddenSection")
        ),
        SearchEntry(
            id: "advanced.useDoubleClickToShowAlwaysHiddenSection",
            titleKey: "Double-click \(Constants.displayName) icon to open always-hidden section",
            titleText: "Double-click \(Constants.displayName) icon to open always-hidden section",
            descriptionText: nil,
            pane: .general,
            sectionKey: "\(Constants.displayName) icon",
            sectionText: "\(Constants.displayName) icon",
            keywords: ["double click", "always hidden", "icon"],
            property: .advanced("useDoubleClickToShowAlwaysHiddenSection")
        ),
        SearchEntry(
            id: "advanced.showAllSectionsOnUserDrag",
            titleKey: "Show all sections when ⌘ Command + dragging menu bar items",
            titleText: "Show all sections when Command + dragging menu bar items",
            descriptionText: nil,
            pane: .general,
            sectionKey: "While rearranging",
            sectionText: "While rearranging",
            keywords: ["drag", "command", "sections", "show all"],
            property: .advanced("showAllSectionsOnUserDrag")
        ),
        SearchEntry(
            id: "advanced.showOnHoverDelay",
            titleKey: "Show on hover delay",
            titleText: "Show on hover delay",
            descriptionText: "The amount of time to wait before showing on hover.",
            pane: .general,
            sectionKey: "Empty menu bar area",
            sectionText: "Empty menu bar area",
            keywords: ["hover", "delay", "show", "seconds"],
            property: .advanced("showOnHoverDelay")
        ),
    ]

    // MARK: Layout Settings

    private static let layoutEntries: [SearchEntry] = [
        SearchEntry(
            id: "advanced.enableAlwaysHiddenSection",
            titleKey: "Enable the always-hidden section",
            titleText: "Enable the always-hidden section",
            descriptionText: nil,
            pane: .menuBarLayout,
            sectionKey: "Sections",
            sectionText: "Sections",
            keywords: ["always hidden", "section", "enable"],
            property: .advanced("enableAlwaysHiddenSection")
        ),
        SearchEntry(
            id: "advanced.sectionDividerStyle",
            titleKey: "Section divider style",
            titleText: "Section divider style",
            descriptionText: nil,
            pane: .menuBarLayout,
            sectionKey: "Sections",
            sectionText: "Sections",
            keywords: ["divider", "style", "chevron", "separator", "section"],
            property: .advanced("sectionDividerStyle")
        ),
        SearchEntry(
            id: "layout.spacers",
            titleKey: "Spacers",
            titleText: "Spacers",
            descriptionText: "Insert empty gap items into the menu bar and adjust their width.",
            pane: .menuBarLayout,
            sectionKey: "Spacers",
            sectionText: "Spacers",
            keywords: ["spacer", "gap", "space", "separator", "width"],
            property: nil
        ),
        SearchEntry(
            id: "layout.groups",
            titleKey: "Item groups",
            titleText: "Item groups",
            descriptionText: "Group menu bar items so they always move together.",
            pane: .menuBarLayout,
            sectionKey: "Item groups",
            sectionText: "Item groups",
            keywords: ["group", "cluster", "together", "move", "bundle"],
            property: nil
        ),
        SearchEntry(
            id: "layout.resetMenuBarLayout",
            titleKey: "Reset menu bar layout",
            titleText: "Reset menu bar layout",
            descriptionText: "Moves every movable item except the \(Constants.displayName) icon to the selected section — just like a fresh install.",
            pane: .menuBarLayout,
            sectionKey: nil,
            sectionText: nil,
            keywords: ["reset", "layout", "fresh", "visible", "hidden", "arrange"],
            property: nil
        ),
    ]


}
