//
//  IceForm.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

struct IceForm: View {
    @State private var formWidth: CGFloat

    private let content: AnyView

    init<Content: View>(@ViewBuilder content: () -> Content) {
        self._formWidth = State(initialValue: 0)
        self.content = AnyView(content())
    }

    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onFrameChange { frame in
            formWidth = frame.width
        }
        .contentMargins(.horizontal, readingGutter, for: .scrollContent)
        .focusSection()
        .accessibilityElement(children: .contain)
    }

    private var readingGutter: CGFloat {
        let available = formWidth - (SettingsDetailLayout.titleHorizontalInset * 2)
        let overflow = available - SettingsDetailLayout.columnMaxWidth
        guard overflow > 0 else {
            return 0
        }
        return overflow / 2
    }
}
