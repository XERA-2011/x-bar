//
//  Migration.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation

/// A type that brings settings written by an earlier version of the app up to
/// the current format.
///
/// Migrations for older releases used to live here.
/// XMenuBar reads its own defaults domain, `com.xera.xmenubar`.
@MainActor
struct MigrationManager {
    private let diagLog = DiagLog(category: "Migration")

    let encoder = JSONEncoder()
}

// MARK: - Migrate All

extension MigrationManager {
    /// Performs all migrations.
    func migrateAll() {
        let results = [
            migratePerDisplayIceBar(),
        ]

        for result in results {
            switch result {
            case .success:
                continue
            case let .failureAndLogError(error):
                diagLog.error("Migration failed with error \(error)")
            }
        }
    }
}

// MARK: - Migrate Per-Display XMenuBar Bar

extension MigrationManager {
    /// Migrates legacy global XMenuBar Bar settings to per-display configurations.
    private func migratePerDisplayIceBar() -> MigrationResult {
        guard !Defaults.bool(forKey: .hasMigratedPerDisplayIceBar) else {
            return .success
        }

        let useIceBar = Defaults.bool(forKey: .useIceBar)
        let useOnlyOnNotched = Defaults.bool(forKey: .useIceBarOnlyOnNotchedDisplay)
        let iceBarLocationRaw = Defaults.integer(forKey: .iceBarLocation)
        let iceBarLocation = IceBarLocation(rawValue: iceBarLocationRaw) ?? .dynamic

        // Only create per-display configs if the user had XMenuBar Bar enabled.
        guard useIceBar else {
            Defaults.set(true, forKey: .hasMigratedPerDisplayIceBar)
            diagLog.info("Per-display XMenuBar Bar migration: XMenuBar Bar was disabled, nothing to migrate")
            return .success
        }

        let configs = DisplayIceBarConfiguration.buildConfigurations(
            onlyOnNotched: useOnlyOnNotched,
            location: iceBarLocation
        )

        do {
            let data = try encoder.encode(configs)
            Defaults.set(data, forKey: .displayIceBarConfigurations)
            Defaults.set(true, forKey: .hasMigratedPerDisplayIceBar)
            diagLog.info("Per-display XMenuBar Bar migration: migrated \(configs.count) display(s)")
        } catch {
            return .failureAndLogError(.perDisplayIceBarMigrationError(error))
        }

        return .success
    }
}

// MARK: - MigrationResult

extension MigrationManager {
    enum MigrationResult {
        case success
        case failureAndLogError(MigrationError)
    }
}

// MARK: - MigrationError

extension MigrationManager {
    enum MigrationError: Error, CustomStringConvertible {
        case perDisplayIceBarMigrationError(any Error)

        var description: String {
            switch self {
            case let .perDisplayIceBarMigrationError(error):
                "Error migrating per-display XMenuBar Bar configuration: \(error)"
            }
        }
    }
}
