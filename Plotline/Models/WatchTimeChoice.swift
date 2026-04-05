import Foundation

/// Represents the user's time preference in the recommendation flow
enum WatchTimeChoice: String, CaseIterable {
    case movie = "A Movie"
    case series = "A Series"

    /// SF Symbol icon for each choice
    var icon: String {
        switch self {
        case .movie: return "film"
        case .series: return "tv"
        }
    }
}
