//
//  IceColor.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import CoreGraphics
import Foundation
import SwiftUI

extension NSColor {
    static let defaultLayoutBar: NSColor = {
        if let named = NSColor(named: "DefaultLayoutBarColor") {
            return named
        }
        return NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(displayP3Red: 1.0, green: 1.0, blue: 1.0, alpha: 0.07)
            } else {
                return NSColor(displayP3Red: 0.0, green: 0.0, blue: 0.0, alpha: 0.17)
            }
        }
    }()
}

extension Color {
    static let defaultLayoutBar = Color(nsColor: .defaultLayoutBar)
}

/// A custom color.
nonisolated struct IceColor: Hashable {
    /// The color, represented as a `CGColor`.
    var cgColor: CGColor
}

// MARK: IceColor: Codable

nonisolated extension IceColor: Codable {
    private enum CodingKeys: CodingKey {
        case components
        case colorSpace
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var components = try container.decode([CGFloat].self, forKey: .components)
        let iccData = try container.decode(Data.self, forKey: .colorSpace) as CFData
        guard let colorSpace = CGColorSpace(iccData: iccData) else {
            throw DecodingError.dataCorruptedError(
                forKey: .colorSpace,
                in: container,
                debugDescription: "Invalid ICC profile data"
            )
        }
        guard let cgColor = CGColor(colorSpace: colorSpace, components: &components) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid color space or components"
                )
            )
        }
        self.cgColor = cgColor
    }

    func encode(to encoder: Encoder) throws {
        guard let components = cgColor.components else {
            throw EncodingError.invalidValue(
                cgColor,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Missing color components"
                )
            )
        }
        guard let colorSpace = cgColor.colorSpace else {
            throw EncodingError.invalidValue(
                cgColor,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Missing color space"
                )
            )
        }
        guard let iccData = colorSpace.copyICCData() else {
            throw EncodingError.invalidValue(
                colorSpace,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Missing ICC profile data"
                )
            )
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(components, forKey: .components)
        try container.encode(iccData as Data, forKey: .colorSpace)
    }
}
