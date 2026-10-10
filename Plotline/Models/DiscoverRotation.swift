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
    /// ascending id, starting at the day's index and wrapping; within a genre,
    /// its shelves in the order given (the generator's shelf order), at the
    /// day's index plus the genre's position in the sorted ids. The offset
    /// keeps neighbouring genres on different base shelves, and each genre
    /// still advances one shelf a day.
    static func genreShelves(
        from lists: [CuratedList], on date: Date, calendar: Calendar, count: Int = genreShelfCount
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
        return (0..<min(count, genres.count)).compactMap { offset in
            let position = (start + offset) % genres.count
            guard let shelves = byGenre[genres[position]] else { return nil }
            return shelves[wrapped(day + position, shelves.count)]
        }
    }

    private static func wrapped(_ index: Int, _ count: Int) -> Int {
        ((index % count) + count) % count
    }
}
