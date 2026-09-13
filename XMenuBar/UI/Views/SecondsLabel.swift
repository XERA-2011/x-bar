//
//  SecondsLabel.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

struct SecondsLabel: View {
    let value: Double

    var body: Text {
        Text("\(value, format: .number.precision(.fractionLength(0 ... 1))) seconds")
    }
}
