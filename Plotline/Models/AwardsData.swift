import Foundation

/// Parsed awards data for a title (Oscar wins/nominations and totals)
struct AwardsData: Codable, Hashable {
    let oscarWins: Int
    let oscarNominations: Int
    let totalWins: Int
    let totalNominations: Int
    let rawString: String

    // MARK: - Computed Properties

    /// Whether there are any awards
    var hasAwards: Bool {
        totalWins > 0 || totalNominations > 0
    }

    /// Whether the movie won any Oscars
    var hasOscarWins: Bool {
        oscarWins > 0
    }

    /// Whether the movie was nominated for Oscars
    var hasOscarNominations: Bool {
        oscarNominations > 0
    }

    /// Non-Oscar wins
    var otherWins: Int {
        max(0, totalWins - oscarWins)
    }

    /// Non-Oscar nominations
    var otherNominations: Int {
        max(0, totalNominations - oscarNominations)
    }

    /// Summary string for display (e.g., "2 Oscars, 85 wins total")
    var summaryString: String {
        var parts: [String] = []

        if oscarWins > 0 {
            parts.append("\(oscarWins) Oscar\(oscarWins == 1 ? "" : "s")")
        } else if oscarNominations > 0 {
            parts.append("\(oscarNominations) Oscar nom\(oscarNominations == 1 ? "" : "s")")
        }

        if totalWins > oscarWins {
            parts.append("\(totalWins) total wins")
        }

        if parts.isEmpty && totalNominations > 0 {
            parts.append("\(totalNominations) nominations")
        }

        return parts.isEmpty ? "No awards data" : parts.joined(separator: " · ")
    }
}

// MARK: - Preview Data

extension AwardsData {
    /// Oscar winner (e.g., Oppenheimer)
    static let oscarWinnerPreview = AwardsData(
        oscarWins: 7,
        oscarNominations: 13,
        totalWins: 96,
        totalNominations: 352,
        rawString: "Won 7 Oscars. 96 wins & 352 nominations total"
    )

    /// Oscar nominee (e.g., The Holdovers)
    static let oscarNomineePreview = AwardsData(
        oscarWins: 0,
        oscarNominations: 5,
        totalWins: 42,
        totalNominations: 148,
        rawString: "Nominated for 5 Oscars. 42 wins & 148 nominations total"
    )

    /// Regular awards
    static let regularPreview = AwardsData(
        oscarWins: 0,
        oscarNominations: 0,
        totalWins: 12,
        totalNominations: 35,
        rawString: "12 wins & 35 nominations total"
    )
}
