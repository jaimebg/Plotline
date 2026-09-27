import Foundation

/// Decides which copy of a favorite or watchlist entry survives when CloudKit
/// sync hands back more than one for the same title.
///
/// SwiftData with CloudKit cannot enforce a unique constraint, so two devices
/// that each add the same title produce two records. Every device must pick
/// the same survivor, or they delete each other's copy and both lose it: the
/// earliest-added record is that shared, deterministic choice. Whatever the
/// later copies know that the survivor does not — a title marked watched on
/// the other device — is folded into it before they are deleted.
///
/// Pure and generic so it can be tested without a model container.
nonisolated enum DuplicateResolver {
    struct Group<Item> {
        /// The earliest-added item for this id.
        let keeper: Item
        /// Every later copy, to be merged into `keeper` and then deleted.
        let duplicates: [Item]
    }

    /// Groups `items` by id.
    ///
    /// Within a group the earliest `addedAt` is the keeper; equal dates keep
    /// input order. Groups come back newest keeper first, the order the lists
    /// display in.
    static func group<Item>(
        _ items: [Item],
        id: (Item) -> Int,
        addedAt: (Item) -> Date
    ) -> [Group<Item>] {
        var order: [Int] = []
        var members: [Int: [(offset: Int, item: Item)]] = [:]

        for (offset, item) in items.enumerated() {
            let key = id(item)
            if members[key] == nil { order.append(key) }
            members[key, default: []].append((offset, item))
        }

        let groups = order.compactMap { key -> (date: Date, offset: Int, group: Group<Item>)? in
            guard let copies = members[key] else { return nil }
            let sorted = copies.sorted { lhs, rhs in
                let lhsDate = addedAt(lhs.item), rhsDate = addedAt(rhs.item)
                return lhsDate == rhsDate ? lhs.offset < rhs.offset : lhsDate < rhsDate
            }
            guard let first = sorted.first else { return nil }
            let group = Group(keeper: first.item, duplicates: sorted.dropFirst().map(\.item))
            return (addedAt(first.item), first.offset, group)
        }

        return groups
            .sorted { lhs, rhs in
                lhs.date == rhs.date ? lhs.offset < rhs.offset : lhs.date > rhs.date
            }
            .map(\.group)
    }

    /// Watch statuses from least to most advanced. A title watched on any
    /// device stays watched after the duplicates collapse.
    static let watchStatusRank: [String: Int] = [
        "want_to_watch": 1,
        "watched": 2,
    ]

    /// The most advanced of `statuses`; ties go to the earliest in the list, so
    /// pass the keeper's status first. Unknown values rank below every known
    /// one but still win over an empty list's fallback.
    static func mostAdvancedWatchStatus(_ statuses: [String], fallback: String = "want_to_watch") -> String {
        var best: (status: String, rank: Int)?
        for status in statuses {
            let rank = watchStatusRank[status] ?? 0
            if best == nil || rank > best!.rank {
                best = (status, rank)
            }
        }
        return best?.status ?? fallback
    }

    /// The first non-empty value, keeper first — for display metadata a later
    /// copy may carry when the keeper does not.
    static func firstPresent(_ values: [String?]) -> String? {
        values.first { !($0?.isEmpty ?? true) } ?? nil
    }
}
