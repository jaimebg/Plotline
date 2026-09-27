import CoreData
import Foundation
import SwiftData
import Testing
@testable import Plotline

/// The local store holds favorites and watchlist entries that may never have
/// reached CloudKit. It used to be deleted on *any* failure to open.
@Suite("Model container fallback")
@MainActor
struct SharedModelContainerTests {
    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("store-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func contents(of directory: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).sorted()
    }

    @Test("the store and its sidecars are moved aside together, not deleted")
    func movesStoreAndSidecars() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = directory.appendingPathComponent("default.store")
        for suffix in ["", "-wal", "-shm"] {
            try Data("payload\(suffix)".utf8).write(to: directory.appendingPathComponent("default.store\(suffix)"))
        }

        let now = Date(timeIntervalSince1970: 1_781_524_800) // 2026-06-15 12:00:00 UTC
        let moved = try SharedModelContainer.moveStoreAside(at: store, now: now)

        let base = "default.store.incompatible-20260615T120000"
        #expect(moved.lastPathComponent == base)
        #expect(contents(of: directory) == [base, "\(base)-shm", "\(base)-wal"])
        #expect(try Data(contentsOf: directory.appendingPathComponent("\(base)-wal")) == Data("payload-wal".utf8))
    }

    @Test("a store without sidecars moves on its own")
    func movesStoreAlone() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = directory.appendingPathComponent("default.store")
        try Data("payload".utf8).write(to: store)

        let moved = try SharedModelContainer.moveStoreAside(at: store)

        #expect(!FileManager.default.fileExists(atPath: store.path))
        #expect(FileManager.default.fileExists(atPath: moved.path))
    }

    @Test("a migration error anywhere in the chain counts as incompatible")
    func detectsNestedMigrationError() {
        let migration = NSError(domain: NSCocoaErrorDomain, code: NSMigrationMissingSourceModelError)
        let wrapped = NSError(domain: "SwiftData", code: 1, userInfo: [NSUnderlyingErrorKey: migration])
        let detailed = NSError(domain: "Outer", code: 2, userInfo: [NSDetailedErrorsKey: [wrapped]])

        #expect(SharedModelContainer.containsIncompatibilityCode(migration))
        #expect(SharedModelContainer.containsIncompatibilityCode(wrapped))
        #expect(SharedModelContainer.containsIncompatibilityCode(detailed))
    }

    /// A locked device, a full disk, a busy SQLite file: none of these is a
    /// reason to touch the user's data.
    @Test("other failures are not taken as incompatibility")
    func ignoresTransientErrors() throws {
        let permission = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
        let sqlite = NSError(domain: NSSQLiteErrorDomain, code: 5)
        #expect(!SharedModelContainer.containsIncompatibilityCode(permission))
        #expect(!SharedModelContainer.containsIncompatibilityCode(sqlite))

        // With no readable metadata to compare, the answer is still "no".
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appendingPathComponent("default.store")
        try Data("not sqlite".utf8).write(to: store)

        #expect(!SharedModelContainer.isIncompatibleStore(error: permission, at: store))
        #expect(!SharedModelContainer.isIncompatibleStore(
            error: permission,
            at: directory.appendingPathComponent("missing.store")
        ))
    }

    @Test("the last-resort container opens and holds nothing")
    func inMemoryFallback() throws {
        let container = SharedModelContainer.makeInMemory()
        let favorites = try container.mainContext.fetch(FetchDescriptor<FavoriteItem>())
        #expect(favorites.isEmpty)
    }
}
