import Foundation

/// Where a title can be watched, by region.
///
/// TMDB returns one entry per region — 126 of them for a well-known series —
/// keyed by ISO 3166-1 code. The data behind it comes from JustWatch, which
/// TMDB requires be credited wherever it is shown; `WatchProvidersSection`
/// carries that credit.
struct WatchProvidersResponse: Codable {
    let id: Int
    let results: [String: RegionAvailability]
}

/// What is on offer in one region.
///
/// Every category is optional and they genuinely go missing: Spain carries a
/// subscription entry for Breaking Bad and no purchase or rental at all.
struct RegionAvailability: Codable, Hashable {
    /// TMDB's own watch page for this title and region.
    ///
    /// The only link the endpoint offers — there are no per-platform deep
    /// links, so this cannot open Netflix directly.
    let link: String?

    /// Included with a subscription.
    let flatrate: [WatchProvider]?
    let rent: [WatchProvider]?
    let buy: [WatchProvider]?
    /// Free, with no subscription required.
    let free: [WatchProvider]?
    /// Free with advertising.
    let ads: [WatchProvider]?

    /// True when the region carries no provider at all in any category.
    ///
    /// A region can come back with a link and nothing else, and a section with
    /// a heading and no rows reads as a broken screen rather than an answer.
    var isEmpty: Bool {
        [flatrate, rent, buy, free, ads].allSatisfy { $0?.isEmpty ?? true }
    }
}

/// One streaming service.
struct WatchProvider: Codable, Hashable, Identifiable {
    var id: Int { providerId }

    let providerId: Int
    let providerName: String
    let logoPath: String?
    /// TMDB's own ordering hint, lowest first.
    let displayPriority: Int?

    var logoURL: URL? {
        guard let logoPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w92\(logoPath)")
    }
}
