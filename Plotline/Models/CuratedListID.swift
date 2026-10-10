import Foundation

/// A curated list id, split into the shelf it belongs to and, for a genre
/// shelf, the genre it narrows to: `"falls-off"` or `"falls-off/18"`.
///
/// Anything else parses to nil and is never shown. Strict on purpose — a
/// list the app cannot place would otherwise render under a guessed title.
nonisolated struct CuratedListID: Hashable, Sendable {
    let base: String
    let genreId: Int?

    init?(_ raw: String) {
        let parts = raw.split(separator: "/", omittingEmptySubsequences: false)
        guard let first = parts.first, !first.isEmpty else { return nil }

        switch parts.count {
        case 1:
            genreId = nil
        case 2:
            let genre = parts[1]
            guard !genre.isEmpty,
                  genre.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let value = Int(genre), value > 0 else { return nil }
            genreId = value
        default:
            return nil
        }
        base = String(first)
    }
}
