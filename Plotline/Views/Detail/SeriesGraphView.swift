import SwiftUI
import Charts
import Accessibility

/// Interactive rating graph for TV series episodes using Swift Charts
struct SeriesGraphView: View {
    let episodes: [EpisodeMetric]
    let seasonNumber: Int
    var showAverage: Bool = true

    @State private var selectedEpisode: EpisodeMetric?
    @State private var selectedEpisodeNumber: Int?
    @State private var animateChart: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with average
            headerView

            // Chart
            chartView
                .frame(height: 200)

            // Selected episode detail
            if let episode = selectedEpisode {
                selectedEpisodeDetail(episode)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateChart = true
            }
        }
        .onChange(of: episodes) { _, _ in
            // Reset and reanimate when episodes change (season switch)
            animateChart = false
            selectedEpisode = nil
            selectedEpisodeNumber = nil
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                animateChart = true
            }
        }
        .onChange(of: selectedEpisodeNumber) { _, newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                if let num = newValue {
                    selectedEpisode = episodes.first { $0.episodeNumber == num }
                } else {
                    selectedEpisode = nil
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(Color.plotlineGold)
                Text("Episode Ratings")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Average badge
            if showAverage, let avg = averageRating {
                HStack(spacing: 4) {
                    Text("Avg:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", avg))
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(Color.plotlineGold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.plotlineCard)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Chart View

    private var chartView: some View {
        Chart {
            // Average line (drawn first so it's behind)
            if showAverage, let avg = averageRating {
                RuleMark(y: .value("Average", avg))
                    .foregroundStyle(Color.plotlineSecondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("avg")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }
            }

            // Area fill under the line
            ForEach(validEpisodes) { episode in
                AreaMark(
                    x: .value("Episode", episode.episodeNumber),
                    yStart: .value("Min", ratingYDomain.lowerBound),
                    yEnd: .value("Rating", animateChart ? episode.rating : ratingYDomain.lowerBound)
                )
                .foregroundStyle(areaGradient)
                .interpolationMethod(.catmullRom)
            }

            // Line
            ForEach(validEpisodes) { episode in
                LineMark(
                    x: .value("Episode", episode.episodeNumber),
                    y: .value("Rating", animateChart ? episode.rating : ratingYDomain.lowerBound)
                )
                .foregroundStyle(Color.plotlineGold)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }

            // Points
            ForEach(validEpisodes) { episode in
                PointMark(
                    x: .value("Episode", episode.episodeNumber),
                    y: .value("Rating", animateChart ? episode.rating : ratingYDomain.lowerBound)
                )
                .foregroundStyle(ratingColor(for: episode.rating))
                .symbolSize(selectedEpisodeNumber == episode.episodeNumber ? 120 : 60)
                .annotation(position: .top, spacing: 4) {
                    if selectedEpisodeNumber == episode.episodeNumber {
                        Text(episode.formattedRating)
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.plotlineCard)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: ratingYDomain)
        .chartXAxis {
            AxisMarks(values: xAxisValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.primary.opacity(0.1))
                AxisValueLabel {
                    if let episode = value.as(Int.self) {
                        Text("E\(episode)")
                            .font(.caption2)
                            .foregroundStyle(Color.plotlineSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 2.5, 5, 7.5, 10]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.primary.opacity(0.1))
                AxisValueLabel {
                    if let rating = value.as(Double.self) {
                        Text(String(format: "%.0f", rating))
                            .font(.caption2)
                            .foregroundStyle(Color.plotlineSecondary)
                    }
                }
            }
        }
        .chartXSelection(value: $selectedEpisodeNumber)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.plotlineCard.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityChartDescriptor(SeriesGraphAccessibility(episodes: episodes, seasonNumber: seasonNumber))
        .accessibilityLabel("Episode ratings chart for season \(seasonNumber)")
    }

    // MARK: - Selected Episode Detail

    private func selectedEpisodeDetail(_ episode: EpisodeMetric) -> some View {
        HStack(spacing: 12) {
            // Episode number badge
            Text("E\(episode.episodeNumber)")
                .font(.system(.headline, design: .monospaced, weight: .bold))
                .foregroundStyle(Color.plotlineGold)
                .frame(width: 40)

            // Title and info
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(episode.fullCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Rating
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(Color.imdbYellow)
                Text(episode.formattedRating)
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }

    // MARK: - Helpers

    private var validEpisodes: [EpisodeMetric] {
        episodes.filter { $0.hasValidRating }.sorted { $0.episodeNumber < $1.episodeNumber }
    }

    private var averageRating: Double? {
        guard !validEpisodes.isEmpty else { return nil }
        let sum = validEpisodes.reduce(0.0) { $0 + $1.rating }
        return sum / Double(validEpisodes.count)
    }

    private var xDomain: ClosedRange<Int> {
        guard !validEpisodes.isEmpty else { return 1...10 }
        let minEp = validEpisodes.map(\.episodeNumber).min() ?? 1
        let maxEp = validEpisodes.map(\.episodeNumber).max() ?? 10
        return max(0, minEp - 1)...(maxEp + 1)
    }

    private var ratingYDomain: ClosedRange<Double> {
        guard !validEpisodes.isEmpty else { return 0...10 }
        let ratings = validEpisodes.map(\.rating)
        let minRating = (ratings.min() ?? 5) - 0.5
        let maxRating = min((ratings.max() ?? 10) + 0.5, 10)
        return max(0, minRating)...maxRating
    }

    private var xAxisValues: [Int] {
        let episodeNumbers = validEpisodes.map(\.episodeNumber)
        guard episodeNumbers.count > 10 else { return episodeNumbers }

        // Show every Nth episode for larger seasons
        let step = max(1, episodeNumbers.count / 8)
        return stride(from: episodeNumbers.first!, through: episodeNumbers.last!, by: step).map { $0 }
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.plotlineGold.opacity(0.3),
                Color.plotlineGold.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func ratingColor(for rating: Double) -> Color {
        switch rating {
        case 8.5...:
            return .chartHigh
        case 7.0...:
            return .chartMedium
        default:
            return .chartLow
        }
    }
}

// MARK: - Compact Graph (for overview)

struct CompactSeriesGraphView: View {
    let episodes: [EpisodeMetric]

    var body: some View {
        Chart(validEpisodes) { episode in
            LineMark(
                x: .value("Episode", episode.episodeNumber),
                y: .value("Rating", episode.rating)
            )
            .foregroundStyle(Color.plotlineGold)
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: ratingYDomain)
    }

    private var validEpisodes: [EpisodeMetric] {
        episodes.filter { $0.hasValidRating }
    }

    private var ratingYDomain: ClosedRange<Double> {
        guard !validEpisodes.isEmpty else { return 0...10 }
        let ratings = validEpisodes.map(\.rating)
        let minRating = (ratings.min() ?? 5) - 1
        let maxRating = min((ratings.max() ?? 10) + 1, 10)
        return max(0, minRating)...maxRating
    }
}

// MARK: - All Seasons Overview Graph

struct AllSeasonsGraphView: View {
    let seasonData: [(season: Int, episodes: [EpisodeMetric])]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Seasons Overview")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            Chart {
                ForEach(seasonData, id: \.season) { data in
                    ForEach(data.episodes.filter(\.hasValidRating)) { episode in
                        LineMark(
                            x: .value("Episode", globalEpisodeIndex(season: data.season, episode: episode.episodeNumber)),
                            y: .value("Rating", episode.rating),
                            series: .value("Season", "S\(data.season)")
                        )
                        .foregroundStyle(seasonColor(data.season))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartYScale(domain: 0...10)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 5, 10]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.primary.opacity(0.1))
                    AxisValueLabel {
                        if let rating = value.as(Double.self) {
                            Text(String(format: "%.0f", rating))
                                .font(.caption2)
                                .foregroundStyle(Color.plotlineSecondary)
                        }
                    }
                }
            }
            .frame(height: 150)

            // Season legend
            seasonLegend
        }
    }

    private var seasonLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(seasonData, id: \.season) { data in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(seasonColor(data.season))
                            .frame(width: 8, height: 8)
                        Text("S\(data.season)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func globalEpisodeIndex(season: Int, episode: Int) -> Int {
        var index = episode
        for data in seasonData where data.season < season {
            index += data.episodes.count
        }
        return index
    }

    private func seasonColor(_ season: Int) -> Color {
        let colors: [Color] = [
            .plotlineGold,
            .plotlineSecondaryAccent,
            .plotlinePrimary,
            .rottenGreen,
            .metacriticGreen
        ]
        return colors[(season - 1) % colors.count]
    }
}

// MARK: - Audio Graph Accessibility

/// Provides audio graph accessibility for VoiceOver users
struct SeriesGraphAccessibility: AXChartDescriptorRepresentable {
    let episodes: [EpisodeMetric]
    let seasonNumber: Int

    func makeChartDescriptor() -> AXChartDescriptor {
        let validEpisodes = episodes.filter { $0.hasValidRating }.sorted { $0.episodeNumber < $1.episodeNumber }

        // X-axis: Episode numbers
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Episode",
            range: Double(validEpisodes.first?.episodeNumber ?? 1)...Double(validEpisodes.last?.episodeNumber ?? 10),
            gridlinePositions: validEpisodes.map { Double($0.episodeNumber) }
        ) { value in
            "Episode \(Int(value))"
        }

        // Y-axis: Ratings
        let ratings = validEpisodes.map(\.rating)
        let minRating = (ratings.min() ?? 0) - 0.5
        let maxRating = min((ratings.max() ?? 10) + 0.5, 10)

        let yAxis = AXNumericDataAxisDescriptor(
            title: "IMDb Rating",
            range: minRating...maxRating,
            gridlinePositions: [0, 2.5, 5, 7.5, 10].filter { $0 >= minRating && $0 <= maxRating }
        ) { value in
            String(format: "%.1f", value)
        }

        // Data series
        let dataPoints = validEpisodes.map { episode in
            AXDataPoint(
                x: Double(episode.episodeNumber),
                y: episode.rating,
                label: "\(episode.title): \(episode.formattedRating)"
            )
        }

        let series = AXDataSeriesDescriptor(
            name: "Episode Ratings for Season \(seasonNumber)",
            isContinuous: true,
            dataPoints: dataPoints
        )

        return AXChartDescriptor(
            title: "Episode Ratings Graph",
            summary: makeSummary(from: validEpisodes),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }

    private func makeSummary(from episodes: [EpisodeMetric]) -> String {
        guard !episodes.isEmpty else {
            return "No episode data available"
        }

        let ratings = episodes.map(\.rating)
        let average = ratings.reduce(0, +) / Double(ratings.count)
        let highest = episodes.max { $0.rating < $1.rating }
        let lowest = episodes.min { $0.rating < $1.rating }

        var summary = "Season \(seasonNumber) has \(episodes.count) episodes. "
        summary += "Average rating is \(String(format: "%.1f", average)). "

        if let highest = highest {
            summary += "Highest rated: Episode \(highest.episodeNumber) (\(highest.title)) with \(highest.formattedRating). "
        }

        if let lowest = lowest {
            summary += "Lowest rated: Episode \(lowest.episodeNumber) (\(lowest.title)) with \(lowest.formattedRating)."
        }

        return summary
    }
}

// MARK: - Preview

#Preview("Series Graph") {
    VStack {
        SeriesGraphView(
            episodes: EpisodeMetric.breakingBadS5,
            seasonNumber: 5
        )
    }
    .padding()
    .background(Color.plotlineBackground)
}

#Preview("Compact Graph") {
    CompactSeriesGraphView(episodes: EpisodeMetric.breakingBadS1)
        .frame(width: 150, height: 50)
        .padding()
        .background(Color.plotlineBackground)
}
