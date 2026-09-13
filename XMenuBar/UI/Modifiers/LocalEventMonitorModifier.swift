//
//  LocalEventMonitorModifier.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

private struct LocalEventMonitorModifier: ViewModifier {
    let mask: NSEvent.EventTypeMask
    @Binding var isEnabled: Bool
    let action: (NSEvent) -> NSEvent?

    func body(content: Content) -> some View {
        content.task(id: isEnabled) {
            guard isEnabled else { return }
            let monitor = EventMonitor.local(for: mask, handler: action)
            monitor.start()
            let _ = await withTaskCancellationHandler {
                try? await Task.sleep(nanoseconds: 1_000_000_000_000_000)
            } onCancel: {
                Task { @MainActor in
                    monitor.stop()
                }
            }
            monitor.stop()
        }
    }
}

extension View {
    /// Returns a view that performs the given action when events corresponding
    /// to the given event type mask are received.
    ///
    /// - Parameters:
    ///   - mask: An event type mask specifying which events to monitor.
    ///   - isEnabled: A Boolean value that determines whether the event monitor
    ///     is enabled.
    ///   - action: An action to perform when the event monitor receives events
    ///     corresponding to `mask`.
    func localEventMonitor(mask: NSEvent.EventTypeMask, isEnabled: Bool = true, action: @escaping (NSEvent) -> NSEvent?) -> some View {
        modifier(LocalEventMonitorModifier(mask: mask, isEnabled: .constant(isEnabled), action: action))
    }
}
