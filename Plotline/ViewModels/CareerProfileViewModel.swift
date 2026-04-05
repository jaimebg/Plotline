import Foundation

/// ViewModel for exploring a person's career analytics (actors and directors)
@Observable
final class CareerProfileViewModel {
    // MARK: - Person Info

    var person: TMDBPersonResponse?

    // MARK: - Computed Analytics

    var careerScore: Double = 0
    var timelinePoints: [CareerTimelinePoint] = []
    var topTen: [MediaItem] = []
    var genreDistribution: [CareerGenreStat] = []
    var totalTitles: Int = 0
    var mostActiveDecade: String?
    var mostFrequentGenre: String?
    var bestTitle: (name: String, rating: Double)?
    var worstTitle: (name: String, rating: Double)?

    // MARK: - Filmography by Decade

    var filmographyByDecade: [(decade: String, items: [MediaItem])] = []
    var filmographyFilter: FilmographyFilter = .all

    enum FilmographyFilter: String, CaseIterable {
        case all = "All"
        case movies = "Movies"
        case series = "Series"
    }

    // MARK: - State

    var isLoading = false

    var isDirector: Bool {
        person?.knownForDepartment?.lowercased() == "directing"
    }

    // MARK: - Load Profile

    func loadProfile(personId: Int) async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let personTask = TMDBService.shared.fetchPersonDetails(id: personId)
            async let creditsTask = TMDBService.shared.fetchPersonCombinedCredits(personId: personId)

            let (personResult, creditsResult) = try await (personTask, creditsTask)
            person = personResult

            let isDirectorRole = personResult.knownForDepartment?.lowercased() == "directing"

            if isDirectorRole {
                processDirectorCredits(creditsResult)
            } else {
                processActorCredits(creditsResult)
            }

            saveToRecentProfiles(personResult)
        } catch {
            #if DEBUG
            print("CareerProfile error: \(error)")
            #endif
        }
    }

    // MARK: - Filtered Filmography

    var filteredFilmography: [(decade: String, items: [MediaItem])] {
        switch filmographyFilter {
        case .all:
            return filmographyByDecade
        case .movies:
            let filtered = filmographyByDecade.compactMap { entry -> (decade: String, items: [MediaItem])? in
                let items = entry.items.filter { !$0.isTVSeries }
                return items.isEmpty ? nil : (decade: entry.decade, items: items)
            }
            return filtered
        case .series:
            let filtered = filmographyByDecade.compactMap { entry -> (decade: String, items: [MediaItem])? in
                let items = entry.items.filter { $0.isTVSeries }
                return items.isEmpty ? nil : (decade: entry.decade, items: items)
            }
            return filtered
        }
    }

    // MARK: - Private: Process Actor Credits

    private func processActorCredits(_ credits: TMDBPersonCombinedCreditsResponse) {
        // Filter to meaningful credits (voteCount > 10 to exclude obscure titles)
        let meaningful = credits.cast.filter { $0.voteCount > 10 }
        let mediaItems = meaningful.map { $0.toMediaItem() }

        processCredits(
            items: mediaItems,
            genreIds: meaningful.flatMap { $0.genreIds ?? [] }
        )
    }

    // MARK: - Private: Process Director Credits

    private func processDirectorCredits(_ credits: TMDBPersonCombinedCreditsResponse) {
        let directorCredits = credits.crew.filter { $0.isDirector && $0.voteCount > 10 }
        let mediaItems = directorCredits.map { $0.toMediaItem() }

        processCredits(
            items: mediaItems,
            genreIds: directorCredits.flatMap { $0.genreIds ?? [] }
        )
    }

    // MARK: - Private: Shared Processing

    private func processCredits(items: [MediaItem], genreIds: [Int]) {
        // Deduplicate by ID
        var seen = Set<Int>()
        let unique = items.filter { seen.insert($0.id).inserted }

        totalTitles = unique.count

        // Career score: weighted average (higher vote count = more weight)
        let rated = unique.filter { $0.voteAverage > 0 }
        if !rated.isEmpty {
            let totalWeight = rated.reduce(0.0) { $0 + log(Double($1.voteCount) + 1) }
            let weightedSum = rated.reduce(0.0) { $0 + $1.voteAverage * log(Double($1.voteCount) + 1) }
            careerScore = totalWeight > 0 ? weightedSum / totalWeight : 0
        }

        // Timeline: average rating per year
        computeTimeline(from: unique)

        // Top 10 by rating (minimum vote threshold)
        topTen = unique
            .filter { $0.voteAverage > 0 && $0.voteCount > 50 }
            .sorted { $0.voteAverage > $1.voteAverage }
            .prefix(10)
            .map { $0 }

        // Genre distribution
        computeGenreDistribution(from: genreIds)

        // Most active decade
        computeMostActiveDecade(from: unique)

        // Best and worst titles
        if let best = unique.filter({ $0.voteAverage > 0 && $0.voteCount > 50 }).max(by: { $0.voteAverage < $1.voteAverage }) {
            bestTitle = (name: best.displayTitle, rating: best.voteAverage)
        }
        if let worst = unique.filter({ $0.voteAverage > 0 && $0.voteCount > 50 }).min(by: { $0.voteAverage < $1.voteAverage }) {
            worstTitle = (name: worst.displayTitle, rating: worst.voteAverage)
        }

        // Filmography grouped by decade
        computeFilmographyByDecade(from: unique)
    }

    private func computeTimeline(from items: [MediaItem]) {
        var yearGroups: [Int: [MediaItem]] = [:]
        for item in items {
            guard let yearStr = item.year, let year = Int(yearStr), item.voteAverage > 0 else { continue }
            yearGroups[year, default: []].append(item)
        }

        timelinePoints = yearGroups
            .sorted { $0.key < $1.key }
            .map { year, items in
                let avg = items.reduce(0.0) { $0 + $1.voteAverage } / Double(items.count)
                let titles = items.map(\.displayTitle)
                return CareerTimelinePoint(year: year, avgRating: avg, titles: titles)
            }
    }

    private func computeGenreDistribution(from genreIds: [Int]) {
        var counts: [Int: Int] = [:]
        for id in genreIds {
            counts[id, default: 0] += 1
        }

        genreDistribution = counts
            .compactMap { id, count in
                guard let name = GenreLookup.name(for: id) else { return nil }
                return CareerGenreStat(genre: name, count: count)
            }
            .sorted { $0.count > $1.count }

        mostFrequentGenre = genreDistribution.first?.genre
    }

    private func computeMostActiveDecade(from items: [MediaItem]) {
        var decadeCounts: [String: Int] = [:]
        for item in items {
            guard let yearStr = item.year, let year = Int(yearStr) else { continue }
            let decade = "\(year / 10 * 10)s"
            decadeCounts[decade, default: 0] += 1
        }
        mostActiveDecade = decadeCounts.max(by: { $0.value < $1.value })?.key
    }

    private func computeFilmographyByDecade(from items: [MediaItem]) {
        var decadeGroups: [String: [MediaItem]] = [:]
        for item in items {
            guard let yearStr = item.year, let year = Int(yearStr) else { continue }
            let decade = "\(year / 10 * 10)s"
            decadeGroups[decade, default: []].append(item)
        }

        filmographyByDecade = decadeGroups
            .sorted { $0.key > $1.key } // Most recent first
            .map { decade, items in
                let sorted = items.sorted { ($0.year ?? "") > ($1.year ?? "") }
                return (decade: decade, items: sorted)
            }
    }

    // MARK: - Recent Profiles Persistence

    private func saveToRecentProfiles(_ person: TMDBPersonResponse) {
        let entry = RecentCareerProfile(
            id: person.id,
            name: person.name,
            profilePath: person.profilePath
        )

        var recents = Self.loadRecentProfiles()
        recents.removeAll { $0.id == entry.id }
        recents.insert(entry, at: 0)
        if recents.count > 10 {
            recents = Array(recents.prefix(10))
        }

        if let data = try? JSONEncoder().encode(recents) {
            UserDefaults.standard.set(data, forKey: "recentCareerProfiles")
        }
    }

    static func loadRecentProfiles() -> [RecentCareerProfile] {
        guard let data = UserDefaults.standard.data(forKey: "recentCareerProfiles"),
              let recents = try? JSONDecoder().decode([RecentCareerProfile].self, from: data) else {
            return []
        }
        return recents
    }
}

// MARK: - Supporting Types

struct CareerTimelinePoint: Identifiable {
    var id: Int { year }
    let year: Int
    let avgRating: Double
    let titles: [String]
}

struct CareerGenreStat: Identifiable {
    var id: String { genre }
    let genre: String
    let count: Int
}

struct RecentCareerProfile: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let profilePath: String?

    var profileURL: URL? {
        TMDBService.profileURL(path: profilePath, size: .medium)
    }
}
