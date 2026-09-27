import CoreData
import Foundation
import SwiftData

/// Builds the one `ModelContainer` the app, its views and its App Intents share.
///
/// Order of preference: CloudKit-synced, then local-only, then in memory. The
/// on-disk store is moved aside — never deleted — and only when the failure is
/// a genuine schema or migration incompatibility. Any other failure (the
/// device still locked on a background launch, a full disk, a transient
/// SQLite error) leaves the file exactly where it is and runs in memory for
/// this launch, so favorites and watchlist entries that never reached CloudKit
/// are still there next time.
enum SharedModelContainer {
    static let schema = Schema([FavoriteItem.self, WatchlistItem.self])

    static func make() -> ModelContainer {
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            #if DEBUG
            print("CloudKit unavailable, using local storage: \(error)")
            #endif
        }

        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            #if DEBUG
            print("Local store failed to open: \(error)")
            #endif

            if isIncompatibleStore(error: error, at: localConfig.url) {
                do {
                    let movedTo = try moveStoreAside(at: localConfig.url)
                    #if DEBUG
                    print("Moved incompatible store aside to \(movedTo.lastPathComponent)")
                    #endif
                    return try ModelContainer(for: schema, configurations: [localConfig])
                } catch {
                    #if DEBUG
                    print("Fresh local store failed too: \(error)")
                    #endif
                }
            }
        }

        return makeInMemory()
    }

    /// Last resort: the app runs, nothing persists this launch, and the file
    /// on disk is untouched for the next one.
    static func makeInMemory() -> ModelContainer {
        let memoryConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [memoryConfig])
        } catch {
            // An in-memory store with this schema cannot fail short of the
            // schema itself being invalid, which no fallback could fix.
            fatalError("Could not create an in-memory model container: \(error)")
        }
    }

    // MARK: - Diagnosing the failure

    /// Core Data error codes that mean "this file was written by a model this
    /// build cannot open", as opposed to "the file cannot be opened right now".
    static let incompatibilityCodes: Set<Int> = [
        NSPersistentStoreIncompatibleSchemaError,
        NSPersistentStoreIncompatibleVersionHashError,
        NSMigrationError,
        NSMigrationConstraintViolationError,
        NSMigrationCancelledError,
        NSMigrationMissingSourceModelError,
        NSMigrationMissingMappingModelError,
        NSMigrationManagerSourceStoreError,
        NSMigrationManagerDestinationStoreError,
        NSEntityMigrationPolicyError,
        NSInferredMappingModelError,
    ]

    /// Whether the store failed because its schema is incompatible.
    ///
    /// SwiftData does not reliably surface the underlying Core Data error, so
    /// this checks two ways: the error chain for a migration code, and — if
    /// that says nothing — the store's own metadata against the current model.
    /// Unreadable metadata is *not* taken as incompatibility: that is exactly
    /// what a locked device looks like.
    static func isIncompatibleStore(error: Error, at storeURL: URL) -> Bool {
        if containsIncompatibilityCode(error) {
            return true
        }

        guard FileManager.default.fileExists(atPath: storeURL.path),
              let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
                  type: .sqlite,
                  at: storeURL
              ),
              let model = NSManagedObjectModel.makeManagedObjectModel(
                  for: [FavoriteItem.self, WatchlistItem.self]
              ) else {
            return false
        }

        // Lightweight migration handles most model changes. A store that is
        // both out of date *and* just failed to open is one it could not migrate.
        return !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
    }

    static func containsIncompatibilityCode(_ error: Error) -> Bool {
        var pending: [NSError] = [error as NSError]
        var visited = 0

        while let current = pending.popLast(), visited < 32 {
            visited += 1
            if current.domain == NSCocoaErrorDomain, incompatibilityCodes.contains(current.code) {
                return true
            }
            pending.append(contentsOf: current.underlyingErrors.map { $0 as NSError })
            if let detailed = current.userInfo[NSDetailedErrorsKey] as? [Error] {
                pending.append(contentsOf: detailed.map { $0 as NSError })
            }
        }
        return false
    }

    // MARK: - Moving the store aside

    /// Renames the store and its SQLite sidecars to
    /// `<name>.incompatible-<timestamp>[-wal|-shm]`, so the data can still be
    /// recovered by hand. Sidecars matter: a `-wal` left behind would be
    /// replayed into the fresh store created at the old path.
    ///
    /// - Returns: the new location of the main store file.
    @discardableResult
    static func moveStoreAside(at storeURL: URL, now: Date = Date()) throws -> URL {
        let fileManager = FileManager.default
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        let stamp = formatter.string(from: now)

        let directory = storeURL.deletingLastPathComponent()
        let baseName = storeURL.lastPathComponent
        let movedBase = "\(baseName).incompatible-\(stamp)"

        for suffix in ["", "-wal", "-shm"] {
            let source = directory.appendingPathComponent(baseName + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let destination = directory.appendingPathComponent(movedBase + suffix)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: source, to: destination)
        }

        return directory.appendingPathComponent(movedBase)
    }
}
