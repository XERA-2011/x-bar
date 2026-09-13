//
//  MenuBarItemServiceConnection.swift
//  Project: XMenuBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (XMenuBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation

// MARK: - MenuBarItemService.Connection

extension MenuBarItemService {
    /// In-process resolution for source process identifiers of menu bar items.
    final class Connection: Sendable {
        static let shared = Connection()

        private let diagLog = DiagLog(category: "MenuBarItemService.Connection")

        private init() {}

        func start() async {
            diagLog.debug("Starting SourcePIDCache in-process")
            await SourcePIDCache.shared.start()
        }

        func syncLogging() async {
            // In-process: already logs to same process.
        }

        func sourcePIDs(for windows: [WindowInfo]) async -> [pid_t?] {
            SourcePIDCache.shared.pids(for: windows)
        }
    }
}
