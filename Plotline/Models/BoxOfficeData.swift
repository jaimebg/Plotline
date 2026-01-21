import Foundation

/// Box office data for movies (budget and revenue)
struct BoxOfficeData: Codable, Hashable {
    let budget: Int
    let revenue: Int

    // MARK: - Computed Properties

    /// Whether the movie has valid box office data
    var hasData: Bool {
        budget > 0 || revenue > 0
    }

    /// Whether the movie is profitable
    var isProfitable: Bool {
        revenue > budget && budget > 0
    }

    /// Profit (revenue - budget)
    var profit: Int {
        revenue - budget
    }

    /// Return on investment as a ratio (e.g., 2.5 means 250% return)
    var roi: Double? {
        guard budget > 0 else { return nil }
        return Double(revenue) / Double(budget)
    }

    /// ROI as a percentage (e.g., 150% for 2.5x return)
    var roiPercentage: Double? {
        guard let roi = roi else { return nil }
        return (roi - 1) * 100
    }

    /// Revenue percentage of budget (for progress visualization)
    var revenueRatio: Double {
        guard budget > 0 else { return 0 }
        return min(Double(revenue) / Double(budget), 10.0) // Cap at 10x for visualization
    }

    // MARK: - Formatted Strings

    /// Formatted budget string (e.g., "$150M")
    var formattedBudget: String {
        formatCurrency(budget)
    }

    /// Formatted revenue string (e.g., "$1.2B")
    var formattedRevenue: String {
        formatCurrency(revenue)
    }

    /// Formatted profit string (e.g., "+$850M" or "-$50M")
    var formattedProfit: String {
        let prefix = profit >= 0 ? "+" : ""
        return prefix + formatCurrency(abs(profit))
    }

    /// Formatted ROI string (e.g., "8.5x" or "+750%")
    var formattedROI: String? {
        guard let roi = roi else { return nil }
        if roi >= 2 {
            return String(format: "%.1fx", roi)
        } else if let percentage = roiPercentage {
            let prefix = percentage >= 0 ? "+" : ""
            return String(format: "%@%.0f%%", prefix, percentage)
        }
        return nil
    }

    // MARK: - Private Helpers

    private func formatCurrency(_ value: Int) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""

        if absValue >= 1_000_000_000 {
            return String(format: "%@$%.1fB", sign, Double(absValue) / 1_000_000_000)
        } else if absValue >= 1_000_000 {
            return String(format: "%@$%.0fM", sign, Double(absValue) / 1_000_000)
        } else if absValue >= 1_000 {
            return String(format: "%@$%.0fK", sign, Double(absValue) / 1_000)
        } else {
            return String(format: "%@$%d", sign, absValue)
        }
    }
}

// MARK: - Preview Data

extension BoxOfficeData {
    /// Blockbuster success (e.g., Avatar)
    static let blockbusterPreview = BoxOfficeData(budget: 237_000_000, revenue: 2_923_706_026)

    /// Modest success (e.g., typical profitable film)
    static let modestPreview = BoxOfficeData(budget: 50_000_000, revenue: 150_000_000)

    /// Box office bomb
    static let flopPreview = BoxOfficeData(budget: 175_000_000, revenue: 75_000_000)

    /// No data available
    static let emptyPreview = BoxOfficeData(budget: 0, revenue: 0)
}
