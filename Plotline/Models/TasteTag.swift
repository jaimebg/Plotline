import Foundation

struct TasteTag: Identifiable, Hashable {
    let id: String
    let label: String
    let score: Double

    static func generate(
        genrePercentages: [(genre: String, percentage: Double)],
        preferredEra: String?,
        directorAppearances: Int,
        seriesRatio: Double,
        avgPopularity: Double,
        medianPopularity: Double,
        avgRating: Double
    ) -> [TasteTag] {
        var tags: [TasteTag] = []
        for (genre, pct) in genrePercentages where pct > 0.30 {
            tags.append(TasteTag(id: "genre_\(genre)", label: "\(genre) Lover", score: pct))
        }
        if let era = preferredEra {
            tags.append(TasteTag(id: "era", label: "\(era) Cinephile", score: 0.5))
        }
        if directorAppearances >= 3 {
            tags.append(TasteTag(id: "auteur", label: "Auteur Fan", score: Double(directorAppearances) / 10.0))
        }
        if seriesRatio > 0.50 {
            tags.append(TasteTag(id: "binge", label: "Binge Watcher", score: seriesRatio))
        }
        if avgPopularity < medianPopularity * 0.5 {
            tags.append(TasteTag(id: "hidden_gem", label: "Hidden Gem Hunter", score: 0.7))
        } else if avgPopularity > medianPopularity * 1.5 {
            tags.append(TasteTag(id: "blockbuster", label: "Blockbuster Fan", score: 0.6))
        }
        if avgRating > 8.0 {
            tags.append(TasteTag(id: "snob", label: "Rating Snob", score: avgRating / 10.0))
        }
        if genrePercentages.allSatisfy({ $0.percentage <= 0.25 }) && genrePercentages.count >= 4 {
            tags.append(TasteTag(id: "hopper", label: "Genre Hopper", score: 0.6))
        }
        return Array(tags.sorted { $0.score > $1.score }.prefix(4))
    }
}
