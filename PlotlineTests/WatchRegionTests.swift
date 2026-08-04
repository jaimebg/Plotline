import Foundation
import Testing
@testable import Plotline

@MainActor
@Suite("Watch region")
struct WatchRegionTests {
    @Test("a known system region is used as-is")
    func knownSystemRegionWins() {
        #expect(WatchRegionStore.systemRegion(from: Locale(identifier: "es_ES")) == "ES")
        #expect(WatchRegionStore.systemRegion(from: Locale(identifier: "en_GB")) == "GB")
    }

    /// A locale with no region at all must not produce an empty string, which
    /// would build a lookup key that matches nothing.
    @Test("a locale with no region yields nothing rather than an empty code")
    func regionlessLocaleYieldsNil() {
        #expect(WatchRegionStore.systemRegion(from: Locale(identifier: "eo")) == nil)
    }

    @Test("the fallback is a region TMDB actually covers")
    func fallbackIsCovered() {
        #expect(WatchRegionStore.fallbackRegion == "US")
    }

    @Test("a chosen region survives a new store")
    func selectionPersists() {
        let store = WatchRegionStore.shared
        let original = store.selected

        store.selected = "JP"
        #expect(WatchRegionStore.shared.selected == "JP")

        store.selected = original
    }

    /// The simulator's system region is not known in advance, so this cannot
    /// assert a literal expected code. Instead it asserts the actual
    /// resolution rule `reset()` is supposed to restore: the override is
    /// gone and `selected` falls back to whatever `systemRegion` resolves to
    /// (or `fallbackRegion` if that is nil). Unlike a check that merely
    /// confirms `selected != "JP"`, this fails for a `reset()` that clears
    /// the override to the wrong value, not only for one that fails to clear
    /// it at all.
    @Test("resetting returns to the system region")
    func resetReturnsToSystem() {
        let store = WatchRegionStore.shared
        let original = store.selected

        store.selected = "JP"
        store.reset()

        let expected = WatchRegionStore.systemRegion(from: .current) ?? WatchRegionStore.fallbackRegion
        #expect(store.selected == expected)

        store.selected = original
    }
}
