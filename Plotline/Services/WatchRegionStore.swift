import Foundation

/// Which region's streaming availability to show.
///
/// App Review runs from wherever App Review happens to be, which is not where
/// this app was built. A title available in Spain and not in the United States
/// would show a reviewer an empty section — the impression that got version
/// 1.3.0 rejected — so the region is both detected and selectable.
@MainActor
final class WatchRegionStore {
    static let shared = WatchRegionStore()

    /// Used when the system region is unknown or absent. The United States has
    /// the widest coverage in TMDB's data.
    static let fallbackRegion = "US"

    private static let storageKey = "watch_region_override"

    private(set) var selectedOverride: String?

    /// The region in force: the user's choice, else the system's, else the
    /// fallback.
    var selected: String {
        get { selectedOverride ?? Self.systemRegion(from: .current) ?? Self.fallbackRegion }
        set {
            selectedOverride = newValue
            UserDefaults.standard.set(newValue, forKey: Self.storageKey)
        }
    }

    /// The region of a locale, when it names one.
    ///
    /// Returns nil rather than an empty string for a locale with no region:
    /// an empty code would build a lookup key that matches no region at all,
    /// and the section would go blank with nothing to explain it.
    static func systemRegion(from locale: Locale) -> String? {
        guard let region = locale.region?.identifier, !region.isEmpty else { return nil }
        return region
    }

    /// Drops the user's choice and returns to the system region.
    func reset() {
        selectedOverride = nil
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    private init() {
        selectedOverride = UserDefaults.standard.string(forKey: Self.storageKey)
    }
}
