import Foundation

/// Parsed awards data from OMDb awards string
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

    // MARK: - Parsing

    /// Parse OMDb awards string (e.g., "Won 2 Oscars. 85 wins & 95 nominations")
    static func parse(from awardsString: String?) -> AwardsData? {
        guard let awardsString = awardsString,
              !awardsString.isEmpty,
              awardsString.lowercased() != "n/a" else {
            return nil
        }

        let lowercased = awardsString.lowercased()

        // Parse Oscar wins: "Won X Oscar(s)" or "Won X Academy Award(s)"
        let oscarWins = extractFirstMatch(
            from: lowercased,
            patterns: [#"won\s+(\d+)\s+oscar"#, #"won\s+(\d+)\s+academy"#]
        )

        // Parse Oscar nominations: "Nominated for X Oscar(s)" or "X Oscar nominations"
        let oscarNominations = extractFirstMatch(
            from: lowercased,
            patterns: [
                #"nominated\s+for\s+(\d+)\s+oscar"#,
                #"(\d+)\s+oscar\s+nomination"#,
                #"nominated\s+for\s+(\d+)\s+academy"#
            ]
        )

        // Parse total wins and nominations (ensure Oscar counts are included)
        let parsedWins = extractFirstMatch(from: lowercased, patterns: [#"(\d+)\s+wins?"#])
        let totalWins = parsedWins > 0 ? parsedWins : oscarWins

        let parsedNominations = extractFirstMatch(from: lowercased, patterns: [#"(\d+)\s+nominations?"#])
        let totalNominations = parsedNominations > 0 ? parsedNominations : oscarNominations

        // Only return if we parsed something meaningful
        guard oscarWins > 0 || oscarNominations > 0 || totalWins > 0 || totalNominations > 0 else {
            return nil
        }

        return AwardsData(
            oscarWins: oscarWins,
            oscarNominations: oscarNominations,
            totalWins: totalWins,
            totalNominations: totalNominations,
            rawString: awardsString
        )
    }

    /// Extract first number matching any of the given patterns
    private static func extractFirstMatch(from string: String, patterns: [String]) -> Int {
        for pattern in patterns {
            if let match = string.range(of: pattern, options: .regularExpression) {
                let substring = string[match]
                if let number = extractNumber(from: String(substring)) {
                    return number
                }
            }
        }
        return 0
    }

    /// Extract first number from a string
    private static func extractNumber(from string: String) -> Int? {
        string.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .first
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
