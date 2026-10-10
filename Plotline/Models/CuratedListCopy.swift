import Foundation

/// English copy for the dataset's curated list ids.
///
/// The dataset carries ids and members, never words: UI copy belongs to the
/// app, and keeping it here leaves the door open to real localisation later.
enum CuratedListCopy {
    private static let copy: [String: (title: String, subtitle: String)] = [
        "never-decline": (
            "Shows That Never Slip",
            "They hold their level season after season"
        ),
        "perfect-ending": (
            "They Stick the Landing",
            "Series that finish at their very best"
        ),
        "slow-burn": (
            "Worth the Wait",
            "Slow to start, and measurably better once they get going"
        ),
        "falls-off": (
            "Knows When It Peaked",
            "The numbers show a real drop-off it never comes back from"
        ),
        "rollercoaster": (
            "Brilliant and Baffling",
            "Unforgettable episodes sitting next to forgettable ones"
        )
    ]

    /// A genre shelf is its base shelf's predicate over a narrower slice, so it
    /// takes the base shelf's copy unchanged. The genre goes in `eyebrow`,
    /// never into the title: composing "Dramas That Never Slip" would be new
    /// copy, and the plurals do not survive "Sci-Fi & Fantasy".
    static func title(for id: String) -> String? { resolved(id)?.title }
    static func subtitle(for id: String) -> String? { resolved(id)?.subtitle }

    /// The genre a genre shelf narrows to, as a label above its title.
    static func eyebrow(for id: String) -> String? {
        guard resolved(id) != nil, let genre = CuratedListID(id)?.genreId else { return nil }
        return GenreLookup.name(for: genre)?.uppercased()
    }

    /// Nil for an unknown base, a malformed id, or a genre `GenreLookup`
    /// cannot name — a genre shelf with no eyebrow would read as a duplicate
    /// of its main shelf.
    private static func resolved(_ id: String) -> (title: String, subtitle: String)? {
        guard let parsed = CuratedListID(id), let copy = copy[parsed.base] else { return nil }
        if let genre = parsed.genreId, GenreLookup.name(for: genre) == nil { return nil }
        return copy
    }
}
