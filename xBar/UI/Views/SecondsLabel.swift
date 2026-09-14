//
//  SecondsLabel.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

struct SecondsLabel: View {
    let value: Double

    var body: Text {
        Text("\(value, format: .number.precision(.fractionLength(0 ... 1))) seconds")
    }
}
