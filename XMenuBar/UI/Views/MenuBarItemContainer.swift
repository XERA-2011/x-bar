//
//  MenuBarItemContainer.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// A view that is drawn in the style of the menu bar.
struct MenuBarItemContainer<Content: View>: View {
    enum ColorInfoAccessor {
        case automatic
        case manual(MenuBarAverageColorInfo?)
    }

    private var appState: AppState
    private var menuBarManager: MenuBarManager

    private let accessor: ColorInfoAccessor
    private let screen: NSScreen?
    private let content: Content

    private var colorInfo: MenuBarAverageColorInfo? {
        switch accessor {
        case .automatic:
            menuBarManager.averageColorInfo
        case let .manual(colorInfo):
            colorInfo
        }
    }

    private var foreground: Color {
        colorInfo?.isBright(for: screen) == true ? .black : .white
    }

    init(
        appState: AppState,
        accessor: ColorInfoAccessor,
        screen: NSScreen? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.appState = appState
        self.menuBarManager = appState.menuBarManager
        self.accessor = accessor
        self.screen = screen
        self.content = content()
    }

    var body: some View {
        content
            .foregroundStyle(foreground)
            .background {
                contentBackground
            }
    }

    @ViewBuilder
    private var contentBackground: some View {
        if let colorInfo {
            Color(cgColor: colorInfo.color)
        } else if appState.activeSpace.isFullscreen {
            Color.black
        } else {
            Color.defaultLayoutBar
        }
    }
}

extension View {
    func menuBarItemContainer(appState: AppState) -> some View {
        MenuBarItemContainer(appState: appState, accessor: .automatic) { self }
    }

    func menuBarItemContainer(
        appState: AppState,
        colorInfo: MenuBarAverageColorInfo?,
        screen: NSScreen? = nil
    ) -> some View {
        MenuBarItemContainer(
            appState: appState,
            accessor: .manual(colorInfo),
            screen: screen
        ) { self }
    }
}
