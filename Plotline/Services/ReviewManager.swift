import Foundation

/// Manages App Store review request timing based on user engagement with favorites
enum ReviewManager {
    private static let favDetailOpenCountKey = "reviewFavoriteDetailOpenCount"
    private static let lastReviewRequestDateKey = "reviewLastRequestDate"
    private static let openThreshold = 3
    private static let minimumDaysBetweenRequests = 120

    /// Record that the user opened a favorite's detail view
    static func recordFavoriteDetailOpened() {
        let count = UserDefaults.standard.integer(forKey: favDetailOpenCountKey)
        UserDefaults.standard.set(count + 1, forKey: favDetailOpenCountKey)
    }

    /// Whether conditions are met to request a review
    static func shouldRequestReview() -> Bool {
        let count = UserDefaults.standard.integer(forKey: favDetailOpenCountKey)
        guard count >= openThreshold else { return false }

        if let lastDate = UserDefaults.standard.object(forKey: lastReviewRequestDateKey) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            guard daysSince >= minimumDaysBetweenRequests else { return false }
        }

        return true
    }

    /// Mark that a review was just requested, resetting the counter
    static func markReviewRequested() {
        UserDefaults.standard.set(Date(), forKey: lastReviewRequestDateKey)
        UserDefaults.standard.set(0, forKey: favDetailOpenCountKey)
    }
}
