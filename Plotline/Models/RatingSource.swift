import Foundation
import SwiftUI

/// Represents a rating from an external source (IMDb, Rotten Tomatoes, Metacritic)
struct RatingSource: Codable, Hashable, Identifiable {
    let source: String
    let value: String

    var id: String { source }

    // MARK: - Computed Properties

    /// Identifies the rating type for iconography and styling
    var ratingType: RatingType {
        switch source {
        case "Internet Movie Database":
            return .imdb
        case "Rotten Tomatoes":
            return .rottenTomatoes
        case "Metacritic":
            return .metacritic
        default:
            return .unknown
        }
    }

    /// Converts the value to a normalized Double (0.0 - 1.0)
    var normalizedValue: Double? {
        let cleanValue = value.trimmingCharacters(in: .whitespaces)

        if cleanValue.contains("/10") {
            let numStr = cleanValue.replacingOccurrences(of: "/10", with: "")
            return Double(numStr).map { $0 / 10.0 }
        } else if cleanValue.contains("%") {
            let numStr = cleanValue.replacingOccurrences(of: "%", with: "")
            return Double(numStr).map { $0 / 100.0 }
        } else if cleanValue.contains("/100") {
            let numStr = cleanValue.replacingOccurrences(of: "/100", with: "")
            return Double(numStr).map { $0 / 100.0 }
        }

        return nil
    }

    /// Display value (cleaned up for UI)
    var displayValue: String {
        switch ratingType {
        case .imdb:
            return value.replacingOccurrences(of: "/10", with: "")
        case .rottenTomatoes, .metacritic:
            return value
        case .unknown:
            return value
        }
    }

    /// Short name for display
    var shortName: String {
        ratingType.shortName
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case source = "Source"
        case value = "Value"
    }
}

// MARK: - Rating Type

enum RatingType: String, CaseIterable {
    case imdb
    case rottenTomatoes
    case metacritic
    case unknown

    var shortName: String {
        switch self {
        case .imdb: return "IMDb"
        case .rottenTomatoes: return "Rotten Tomatoes"
        case .metacritic: return "Metacritic"
        case .unknown: return "Rating"
        }
    }

    var iconName: String {
        switch self {
        case .imdb: return "star.fill"
        case .rottenTomatoes: return "leaf.fill"
        case .metacritic: return "m.square.fill"
        case .unknown: return "number"
        }
    }

    var color: Color {
        switch self {
        case .imdb: return .imdbYellow
        case .rottenTomatoes: return .rottenRed
        case .metacritic: return .metacriticGreen
        case .unknown: return .gray
        }
    }

    /// Returns appropriate color based on the score
    func scoreColor(for normalizedValue: Double) -> Color {
        switch self {
        case .rottenTomatoes:
            return normalizedValue >= 0.60 ? .rottenGreen : .rottenRed
        case .metacritic:
            if normalizedValue >= 0.61 {
                return .metacriticGreen
            } else if normalizedValue >= 0.40 {
                return .metacriticYellow
            } else {
                return .metacriticRed
            }
        default:
            return color
        }
    }

    /// Returns the URL for this rating platform
    func url(imdbId: String?, title: String?) -> URL? {
        switch self {
        case .imdb:
            guard let imdbId else { return nil }
            return URL(string: "https://www.imdb.com/title/\(imdbId)/")
        case .rottenTomatoes:
            guard let title else { return nil }
            let searchQuery = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
            return URL(string: "https://www.rottentomatoes.com/search?search=\(searchQuery)")
        case .metacritic:
            guard let title else { return nil }
            let searchQuery = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
            return URL(string: "https://www.metacritic.com/search/\(searchQuery)/")
        case .unknown:
            return nil
        }
    }
}

// MARK: - Preview Data

extension RatingSource {
    static let imdbPreview = RatingSource(source: "Internet Movie Database", value: "8.9/10")
    static let rottenPreview = RatingSource(source: "Rotten Tomatoes", value: "96%")
    static let metacriticPreview = RatingSource(source: "Metacritic", value: "87/100")

    static let previewRatings: [RatingSource] = [
        imdbPreview,
        rottenPreview,
        metacriticPreview
    ]
}
