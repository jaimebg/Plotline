import Foundation

/// What Discover features on a given day. Pure: the date and calendar come in
/// as arguments, so the engine stays clock-free and every rule is testable.
nonisolated enum DiscoverRotation {
    static let genreShelfCount = 3

    /// Whole days from 1 January 2026 to `date`, in `calendar`'s time zone.
    /// Negative before then.
    static func dayIndex(of date: Date, calendar: Calendar) -> Int {
        let reference = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? date
        return calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: reference), to: calendar.startOfDay(for: date)
        ).day ?? 0
    }

    /// A curve needs three points to say anything, and the card leads with
    /// the backdrop.
    static func isFeaturable(_ entry: DatasetEntry) -> Bool {
        entry.analysis.seasons.count >= 3 && !(entry.backdropPath ?? "").isEmpty
    }

    static func featured(from entries: [DatasetEntry], on date: Date, calendar: Calendar) -> DatasetEntry? {
        let eligible = entries.filter(isFeaturable).sorted { $0.tmdbId < $1.tmdbId }
        guard !eligible.isEmpty else { return nil }
        return eligible[wrapped(dayIndex(of: date, calendar: calendar), eligible.count)]
    }

    /// Up to `count` genre shelves, each from a different genre: genres in
    /// ascending id, starting at the day's index and wrapping. Within a genre,
    /// its shelves in the order given (the generator's shelf order), rotated
    /// by how many times that genre has been on screen, so each genre
    /// advances one shelf per appearance and every shelf comes round.
    ///
    /// From each rotation the slot takes the first shelf whose base no other
    /// slot uses, so a day's genre shelves come from different base shelves
    /// whenever the genres on screen have enough between them. The first slot
    /// also passes over `avoidingBase` — the base of the main shelf drawn
    /// directly above it — whenever its genre has another shelf; that rule
    /// wins over distinctness. The avoided base steers only the first slot:
    /// lower down it is not a neighbour.
    ///
    /// When no arrangement keeps every base distinct, each slot takes its
    /// first unused base or, failing that, its rotated first shelf. A genre is
    /// never dropped.
    static func genreShelves(
        from lists: [CuratedList], on date: Date, calendar: Calendar, count: Int = genreShelfCount,
        avoidingBase: String? = nil
    ) -> [CuratedList] {
        var byGenre: [Int: [CuratedList]] = [:]
        for list in lists {
            guard let genre = CuratedListID(list.id)?.genreId else { continue }
            byGenre[genre, default: []].append(list)
        }
        let genres = byGenre.keys.sorted()
        guard !genres.isEmpty else { return [] }

        let day = dayIndex(of: date, calendar: calendar)
        let start = wrapped(day, genres.count)
        let slotCount = min(count, genres.count)
        // Each slot's candidates: its genre's shelves, rotated.
        let slots: [[CuratedList]] = (0..<slotCount).compactMap { offset in
            let position = (start + offset) % genres.count
            guard let shelves = byGenre[genres[position]], !shelves.isEmpty else { return nil }
            let first = wrapped(
                appearance(ofGenreAt: position, onDay: day, genreCount: genres.count, slotCount: slotCount),
                shelves.count
            )
            return Array(shelves[first...] + shelves[..<first])
        }

        var avoided: Set<String> = []
        if let avoidingBase, slots.first?.contains(where: { base(of: $0) != avoidingBase }) == true {
            avoided.insert(avoidingBase)
        }
        return distinctBases(slots, firstSlotAvoids: avoided)
            ?? closestToDistinct(slots, firstSlotAvoids: avoided)
    }

    /// The first arrangement, in slot order and then rotation order, under
    /// which no two slots share a base. A depth-first search over at most
    /// three slots of five shelves.
    private static func distinctBases(_ slots: [[CuratedList]], firstSlotAvoids avoided: Set<String>) -> [CuratedList]? {
        func search(_ index: Int, _ used: Set<String>) -> [CuratedList]? {
            guard index < slots.count else { return [] }
            let excluded = index == 0 ? used.union(avoided) : used
            for shelf in slots[index] where !excluded.contains(base(of: shelf)) {
                if let rest = search(index + 1, used.union([base(of: shelf)])) {
                    return [shelf] + rest
                }
            }
            return nil
        }
        return search(0, [])
    }

    /// The fallback when the genres on screen have too few bases between
    /// them: each slot takes its first unused base, else its rotated first.
    private static func closestToDistinct(_ slots: [[CuratedList]], firstSlotAvoids avoided: Set<String>) -> [CuratedList] {
        var used: Set<String> = []
        return slots.enumerated().map { index, shelves in
            let excluded = index == 0 ? avoided : used
            let pick = shelves.first { !excluded.contains(base(of: $0)) } ?? shelves[0]
            used.insert(base(of: pick))
            return pick
        }
    }

    /// How many times the genre at `position` has been on screen before
    /// `day`: it shows on `slotCount` consecutive days out of every
    /// `genreCount`, so this counts up by one per appearance and never skips.
    ///
    /// Rotating by the calendar day instead ties the shelf to the day's
    /// residue modulo the genre count. With eight genres, a genre is only ever
    /// seen on three residues, so a genre with four shelves never showed one
    /// of them — two shipped genre lists could not reach Discover at all.
    private static func appearance(ofGenreAt position: Int, onDay day: Int, genreCount: Int, slotCount: Int) -> Int {
        // Shift so the genre's run of visible days starts each cycle at 0.
        let shifted = day - position + (slotCount - 1)
        let withinCycle = wrapped(shifted, genreCount)
        let cycle = (shifted - withinCycle) / genreCount
        return cycle * slotCount + withinCycle
    }

    private static func base(of list: CuratedList) -> String {
        CuratedListID(list.id)?.base ?? list.id
    }

    private static func wrapped(_ index: Int, _ count: Int) -> Int {
        ((index % count) + count) % count
    }
}
