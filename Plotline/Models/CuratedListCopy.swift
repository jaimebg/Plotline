import Foundation

/// English copy for the dataset's curated list ids.
///
/// The dataset carries ids and members, never words: UI copy belongs to the
/// app, and keeping it here leaves the door open to real localisation later.
enum CuratedListCopy {
    private static let copy: [String: (title: String, subtitle: String)] = [
        "never-decline": (
            "Shows That Never Slip",
            "They hold their level from first season to last"
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

    static func title(for id: String) -> String? { copy[id]?.title }
    static func subtitle(for id: String) -> String? { copy[id]?.subtitle }
}
