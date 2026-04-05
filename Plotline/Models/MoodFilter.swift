import Foundation

struct MoodFilter: Identifiable, Hashable {
    let id: String
    let label: String
    let icon: String
    let genreIds: [Int]
    let minRating: Double?
    let minVoteCount: Int?
    let maxVoteCount: Int?

    static let all: [MoodFilter] = [
        MoodFilter(id: "light", label: "Something Light", icon: "sun.max.fill", genreIds: [35, 16, 10751], minRating: nil, minVoteCount: nil, maxVoteCount: nil),
        MoodFilter(id: "mind_bending", label: "Mind-Bending", icon: "brain.head.profile", genreIds: [878, 9648, 53], minRating: 7.5, minVoteCount: nil, maxVoteCount: nil),
        MoodFilter(id: "emotional", label: "Emotional", icon: "heart.fill", genreIds: [18, 10749], minRating: nil, minVoteCount: nil, maxVoteCount: nil),
        MoodFilter(id: "action", label: "Action-Packed", icon: "flame.fill", genreIds: [28, 12], minRating: nil, minVoteCount: nil, maxVoteCount: nil),
        MoodFilter(id: "acclaimed", label: "Critically Acclaimed", icon: "trophy.fill", genreIds: [], minRating: 8.0, minVoteCount: 1000, maxVoteCount: nil),
        MoodFilter(id: "hidden_gem", label: "Hidden Gem", icon: "sparkle", genreIds: [], minRating: 7.0, minVoteCount: 100, maxVoteCount: 1000),
    ]
}

enum WatchTimeChoice: String, CaseIterable {
    case movie = "Movie (~2h)"
    case series = "Start a Series"

    var icon: String {
        switch self {
        case .movie: return "film"
        case .series: return "tv"
        }
    }
}
