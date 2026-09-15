//
//  GeneralSettingsPane.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import LaunchAtLogin
import SwiftUI

struct GeneralSettingsPane: View {
    @Environment(AppState.self) var appState: AppState
    @Bindable var settings: GeneralSettings
    @Bindable var advancedSettings: AdvancedSettings
    @State private var maxSliderLabelWidth: CGFloat = 0

    var body: some View {
        IceForm {
            IceSection {
                appOptions
            }
            IceSection("\(Constants.displayName) icon") {
                iceIconOptions
            }
            IceSection("Empty area") {
                emptyAreaOptions
            }
        }
        .animation(.easeInOut(duration: 0.2), value: settings.emptyAreaAction)
        .onAppear {
            maxSliderLabelWidth = 0
        }
    }

    // MARK: App Options

    @ViewBuilder
    private var appOptions: some View {
        LaunchAtLogin.Toggle {
            Text("Launch at Login")
        }
    }

    // MARK: Ice Icon Options

    @ViewBuilder
    private var iceIconOptions: some View {
        IceIconPicker(settings: settings)
    }

    // MARK: Empty Menu Bar Area

    @ViewBuilder
    private var emptyAreaOptions: some View {
        IceMenu("Action") {
            Picker("Action", selection: $settings.emptyAreaAction) {
                ForEach(GeneralSettings.EmptyAreaAction.allCases) { action in
                    Label(action.localized, systemImage: action.iconName)
                        .tag(action)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } title: {
            HStack(spacing: 6) {
                Image(systemName: settings.emptyAreaAction.iconName)
                Text(settings.emptyAreaAction.shortTitle)
            }
        }

        if settings.emptyAreaAction == .hover {
            showOnHoverDelay
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var showOnHoverDelay: some View {
        LabeledContent {
            IceSlider(
                value: $advancedSettings.showOnHoverDelay,
                in: 0 ... 1,
                step: 0.1
            ) {
                SecondsLabel(value: advancedSettings.showOnHoverDelay)
            }
        } label: {
            Text("Hover delay")
                .frame(minWidth: maxSliderLabelWidth, alignment: .leading)
                .onFrameChange { frame in
                    maxSliderLabelWidth = max(maxSliderLabelWidth, frame.width)
                }
        }
    }
}
