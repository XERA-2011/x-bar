//
//  Once.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

private final class OnceBox: @unchecked Sendable {
    private var action: (() -> Void)?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func run() {
        if let action = action {
            self.action = nil
            action()
        }
    }
}

private struct OnceModifier: ViewModifier {
    private let box: OnceBox

    init(action: @escaping () -> Void) {
        self.box = OnceBox(action: action)
    }

    func body(content: Content) -> some View {
        content.onAppear {
            box.run()
        }
    }
}

extension View {
    /// Adds an action to perform exactly once, before the first
    /// time the view appears.
    ///
    /// - Parameter action: The action to perform.
    func once(perform action: @escaping () -> Void) -> some View {
        modifier(OnceModifier(action: action))
    }
}

private struct OnceScene<Content: Scene>: Scene {
    private let box: OnceBox
    let content: Content

    init(content: Content, action: @escaping () -> Void) {
        self.box = OnceBox(action: action)
        self.content = content
    }

    var body: some Scene {
        content.onChange(of: 0, initial: true) {
            box.run()
        }
    }
}

extension Scene {
    /// Adds an action to perform exactly once, when the scene appears.
    ///
    /// - Parameter action: The action to perform.
    func once(perform action: @escaping () -> Void) -> some Scene {
        OnceScene(content: self, action: action)
    }
}
