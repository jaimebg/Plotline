import Foundation
import Testing
@testable import Plotline

/// A guard on the prerequisites for iCloud sync, which fail silently.
///
/// `PlotlineApp.sharedModelContainer` builds its `ModelContainer` with
/// `cloudKitDatabase: .automatic`, and falls back to `.none` — local storage,
/// no sync, for good — if that throws. The fallback prints only under
/// `#if DEBUG`, so on a release build a broken schema is indistinguishable
/// from a working one: favorites still save, they simply never leave the
/// device. That is how this shipped undetected until the store description
/// claimed sync worked.
///
/// CloudKit reaches SwiftData through `NSPersistentCloudKitContainer`, which
/// refuses a schema containing a non-optional attribute with no default
/// value: a record arriving from the server without that field would have
/// nothing to become. **A default in the initialiser does not satisfy this.**
/// The default must be on the property declaration, because the requirement
/// is about the generated schema, not about how Swift code constructs an
/// instance — which is exactly the distinction that made the original defect
/// invisible on inspection. Every `init` in these two models supplied
/// defaults for the properties that lacked them.
///
/// Asserting this against the live framework would mean building a real
/// CloudKit-backed container, which needs entitlements, a signed build and a
/// device signed into iCloud — none of which a unit test has. So this suite
/// reads the models' own source, in the same spirit as
/// `WatchAttributionSourceTests`.
@Suite("CloudKit sync prerequisites")
struct CloudKitSchemaSourceTests {
    /// The models compiled into the CloudKit-backed `Schema`. Keep this in
    /// step with `PlotlineApp.sharedModelContainer`: a model added there and
    /// not here is unguarded.
    private static let cloudKitBackedModels = [
        "Plotline/Models/FavoriteItem.swift",
        "Plotline/Models/WatchlistItem.swift"
    ]

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PlotlineTests/
            .deletingLastPathComponent()   // repo root
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// A stored `var` declaration, as written in the source.
    private struct StoredProperty {
        let name: String
        let type: String
        let hasDefault: Bool

        var isOptional: Bool { type.hasSuffix("?") }
        /// What CloudKit will accept.
        var isCloudKitSafe: Bool { isOptional || hasDefault }
    }

    /// Stored properties only. A computed property carries no schema, so its
    /// declaration opens a brace on the same line and is skipped here.
    private func storedProperties(in source: String) -> [StoredProperty] {
        source.split(separator: "\n", omittingEmptySubsequences: false).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("var "), !line.hasSuffix("{") else { return nil }

            let withoutKeyword = line.dropFirst("var ".count)
            guard let colon = withoutKeyword.firstIndex(of: ":") else { return nil }

            let name = String(withoutKeyword[..<colon]).trimmingCharacters(in: .whitespaces)
            var remainder = String(withoutKeyword[withoutKeyword.index(after: colon)...])

            let hasDefault = remainder.contains("=")
            if let equals = remainder.firstIndex(of: "=") {
                remainder = String(remainder[..<equals])
            }

            return StoredProperty(
                name: name,
                type: remainder.trimmingCharacters(in: .whitespaces),
                hasDefault: hasDefault
            )
        }
    }

    @Test("every stored property is optional or has a default on its declaration",
          arguments: CloudKitSchemaSourceTests.cloudKitBackedModels)
    func storedPropertiesAreCloudKitSafe(path: String) throws {
        let properties = storedProperties(in: try source(path))

        // If the parse finds nothing, the assertion below is vacuous and this
        // suite would pass while checking nothing at all.
        #expect(
            !properties.isEmpty,
            "\(path): parsed no stored properties — the extraction no longer matches this file's format, so the check below proves nothing"
        )

        for property in properties {
            #expect(
                property.isCloudKitSafe,
                "\(path): '\(property.name): \(property.type)' is neither optional nor defaulted on its declaration. NSPersistentCloudKitContainer rejects this schema, ModelContainer(for:configurations:) throws, and PlotlineApp silently falls back to local-only storage — sync dies with no user-visible signal. A default in init() does not count."
            )
        }
    }

    /// Apple: "SwiftData requires two separate capabilities to perform
    /// automatic iCloud sync: the iCloud capability … and the Background
    /// Modes capability, which lets your app receive remote notifications
    /// from CloudKit that contain information about new changes on the
    /// server." The iCloud half is in `Plotline.entitlements`; without this
    /// half a device never learns that another device wrote something.
    @Test("the app declares the remote-notification background mode")
    func remoteNotificationBackgroundModeIsDeclared() throws {
        let plist = Self.repoRoot.appendingPathComponent("Plotline/Info.plist")
        let data = try Data(contentsOf: plist)
        let parsed = try PropertyListSerialization.propertyList(from: data, format: nil)

        let modes = (parsed as? [String: Any])?["UIBackgroundModes"] as? [String]

        #expect(
            modes?.contains("remote-notification") == true,
            "Plotline/Info.plist must declare UIBackgroundModes containing 'remote-notification', or CloudKit cannot push change notifications and devices only converge when the app is next launched. Found: \(modes.map(String.init(describing:)) ?? "no UIBackgroundModes key")"
        )
    }
}
