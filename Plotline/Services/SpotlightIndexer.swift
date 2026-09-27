import AppIntents
import CoreSpotlight
import Foundation

/// Puts every series in the bundled dataset into Spotlight, once per dataset.
///
/// Launch calls this off the main thread. It re-indexes only when the dataset
/// differs from the one last indexed — by content, not by app version — so an
/// ordinary launch costs one `UserDefaults` read and one hash of ~120 short
/// strings. Tapping a result runs `OpenSeriesIntent`.
nonisolated enum SpotlightIndexer {
    static let indexedSignatureKey = "spotlight.indexedDatasetSignature"

    /// Bump when the shape of an indexed entity changes in a way its text does
    /// not show, to force every install to re-index.
    static let indexFormatVersion = 1

    /// The entities indexed for a dataset, in dataset order.
    static func entities(for dataset: PlotlineDataset) -> [SeriesEntity] {
        dataset.entries.map(SeriesEntity.init(entry:))
    }

    /// Identifies what would be indexed. Covers each entity's id, name and
    /// Spotlight text, so a regenerated dataset that changes a score or a
    /// title re-indexes even if its `generatedAt` somehow did not change.
    ///
    /// FNV-1a rather than `Hasher`: `Hasher` is seeded per process, and this
    /// value has to compare equal across launches.
    static func signature(for dataset: PlotlineDataset) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for entity in entities(for: dataset).sorted(by: { $0.id < $1.id }) {
            let line = "\(entity.id)|\(entity.name)|\(entity.spotlightSummary ?? "")\n"
            for byte in line.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01b3
            }
        }
        return [
            "f\(indexFormatVersion)",
            "v\(dataset.version)",
            dataset.generatedAt ?? "undated",
            "\(dataset.entries.count)",
            String(hash, radix: 16),
        ].joined(separator: "-")
    }

    static func needsIndexing(signature: String, defaults: UserDefaults) -> Bool {
        defaults.string(forKey: indexedSignatureKey) != signature
    }

    static func markIndexed(signature: String, defaults: UserDefaults) {
        defaults.set(signature, forKey: indexedSignatureKey)
    }

    /// Indexes the bundled dataset if it has changed since the last time.
    ///
    /// The signature is only recorded after Spotlight accepts the batch, so a
    /// launch interrupted mid-index tries again next time.
    static func indexBundledDatasetIfNeeded(defaults: UserDefaults = .standard) async {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        guard let dataset = await DatasetStore.shared.load() else { return }

        let signature = signature(for: dataset)
        guard needsIndexing(signature: signature, defaults: defaults) else { return }

        let index = CSSearchableIndex.default()
        do {
            // Drop what an earlier dataset indexed first, so a series removed
            // from the dataset does not linger in Spotlight.
            try await index.deleteAppEntities(ofType: SeriesEntity.self)
            try await index.indexAppEntities(entities(for: dataset))
            markIndexed(signature: signature, defaults: defaults)
        } catch {
            #if DEBUG
            print("⚠️ SpotlightIndexer: indexing failed: \(error.localizedDescription)")
            #endif
        }
    }
}
