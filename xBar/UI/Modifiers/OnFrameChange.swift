//
//  OnFrameChange.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

extension View {
    /// Performs the given action when the view's frame changes in local coordinates.
    ///
    /// - Parameter action: An action to perform when the view's frame changes.
    ///   The closure takes the new frame as a parameter.
    func onFrameChange(
        perform action: @escaping (CGRect) -> Void
    ) -> some View {
        onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .local)
        } action: { _, newFrame in
            action(newFrame)
        }
    }

    /// Updates the given binding when the view's frame changes in local coordinates.
    ///
    /// - Parameter binding: A binding to update when the view's frame changes.
    func onFrameChange(
        update binding: Binding<CGRect>
    ) -> some View {
        onFrameChange { frame in
            binding.wrappedValue = frame
        }
    }
}
