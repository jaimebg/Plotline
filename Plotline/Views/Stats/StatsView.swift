import Charts
import SwiftUI

/// Personal analytics dashboard with Swift Charts visualizations
struct StatsView: View {
    @Environment(\.favoritesManager) private var favoritesManager
    @Environment(\.watchlistManager) private var watchlistManager
    @State private var viewModel = StatsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isEmpty {
                    emptyState
                } else {
                    statsContent
                }
            }
            .navigationTitle("Stats")
        }
        .onAppear { updateStats() }
        .onChange(of: favoritesManager.favorites.count) { updateStats() }
        .onChange(of: watchlistManager.watchlistItems.count) { updateStats() }
    }

    private func updateStats() {
        viewModel.computeStats(
            favorites: favoritesManager.favorites,
            watchlistItems: watchlistManager.watchlistItems
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Stats Yet",
            systemImage: "chart.bar.fill",
            description: Text("Add favorites and watchlist items to see your personal analytics.")
        )
    }

    // MARK: - Stats Content

    private var statsContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                overviewCards
                mediaTypeSplit
                ratingDistribution
                if !viewModel.activityPoints.isEmpty {
                    activityTimeline
                }
                if !viewModel.topGenres.isEmpty {
                    genreBreakdown
                }
                averageRatings
            }
            .padding()
        }
        .background(Color.plotlineBackground)
    }

    // MARK: - Overview Cards

    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                icon: "heart.fill",
                value: "\(viewModel.totalFavorites)",
                label: "Favorites",
                color: .plotlinePrimary
            )
            StatCard(
                icon: "list.bullet",
                value: "\(viewModel.totalWatchlist)",
                label: "Watchlist",
                color: .plotlineSecondaryAccent
            )
            StatCard(
                icon: "checkmark.circle.fill",
                value: "\(viewModel.watchedCount)",
                label: "Watched",
                color: .rottenGreen
            )
            StatCard(
                icon: "percent",
                value: String(format: "%.0f%%", viewModel.completionRate),
                label: "Completion",
                color: .plotlineGold
            )
        }
    }

    // MARK: - Movies vs Series Donut

    private var mediaTypeSplit: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Movies vs Series", icon: "film")

            Chart {
                SectorMark(
                    angle: .value("Count", viewModel.moviesCount),
                    innerRadius: .ratio(0.6),
                    outerRadius: .inset(10),
                    angularInset: 2
                )
                .cornerRadius(4)
                .foregroundStyle(Color.plotlineSecondaryAccent)
                .annotation(position: .overlay) {
                    if viewModel.moviesCount > 0 {
                        Text("\(viewModel.moviesCount)")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                }

                SectorMark(
                    angle: .value("Count", viewModel.seriesCount),
                    innerRadius: .ratio(0.6),
                    outerRadius: .inset(10),
                    angularInset: 2
                )
                .cornerRadius(4)
                .foregroundStyle(Color.plotlineGold)
                .annotation(position: .overlay) {
                    if viewModel.seriesCount > 0 {
                        Text("\(viewModel.seriesCount)")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                }
            }
            .frame(height: 200)
            .chartBackground { _ in
                VStack {
                    Text("\(viewModel.moviesCount + viewModel.seriesCount)")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                legendItem(color: .plotlineSecondaryAccent, label: "Movies")
                legendItem(color: .plotlineGold, label: "Series")
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Rating Distribution

    private var ratingDistribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Rating Distribution", icon: "star.fill")

            Chart(viewModel.ratingBuckets) { bucket in
                BarMark(
                    x: .value("Rating", bucket.label),
                    y: .value("Count", bucket.count)
                )
                .foregroundStyle(barColor(for: bucket.label))
                .cornerRadius(4)
                .annotation(position: .top) {
                    if bucket.count > 0 {
                        Text("\(bucket.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.primary.opacity(0.1))
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Activity Timeline

    private var activityTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Recent Activity", icon: "calendar")

            Chart(viewModel.activityPoints) { point in
                AreaMark(
                    x: .value("Week", point.week, unit: .weekOfYear),
                    y: .value("Items", point.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.plotlineGold.opacity(0.3), Color.plotlineGold.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Week", point.week, unit: .weekOfYear),
                    y: .value("Items", point.count)
                )
                .foregroundStyle(Color.plotlineGold)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Week", point.week, unit: .weekOfYear),
                    y: .value("Items", point.count)
                )
                .foregroundStyle(Color.plotlineGold)
                .symbolSize(20)
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.primary.opacity(0.1))
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Genre Breakdown

    private var genreBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Top Genres", icon: "tag.fill")

            Chart(viewModel.topGenres) { genre in
                BarMark(
                    x: .value("Count", genre.count),
                    y: .value("Genre", genre.name)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.plotlinePrimary, .plotlineSecondaryAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(4)
                .annotation(position: .trailing) {
                    Text("\(genre.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: CGFloat(viewModel.topGenres.count) * 32)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Average Ratings

    private var averageRatings: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Average Ratings", icon: "chart.line.uptrend.xyaxis")

            HStack(spacing: 12) {
                ratingPill(label: "Favorites", value: viewModel.favoritesAvgRating, color: .plotlinePrimary)
                ratingPill(label: "Watchlist", value: viewModel.watchlistAvgRating, color: .plotlineSecondaryAccent)
                ratingPill(label: "Watched", value: viewModel.watchedAvgRating, color: .rottenGreen)
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func ratingPill(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1f", value))
                .font(.title3.bold())
                .foregroundStyle(value > 0 ? color : .secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func barColor(for label: String) -> Color {
        switch label {
        case "0-2": return .chartLow
        case "3-4": return .plotlinePrimary
        case "5-6": return .chartMedium
        case "7-8": return .plotlineGold
        case "9-10": return .chartHigh
        default: return .secondary
        }
    }
}

#Preview {
    StatsView()
}
