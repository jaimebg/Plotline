import Accessibility
import Charts
import SwiftUI

/// Donut chart showing genre distribution for a person's career
struct GenreDNAChart: View {
    let genres: [CareerGenreStat]

    private var topGenres: [CareerGenreStat] {
        Array(genres.prefix(8))
    }

    private let genreColors: [Color] = [
        .plotlineGold,
        .plotlineSecondaryAccent,
        .plotlinePrimary,
        .rottenGreen,
        .metacriticGreen,
        .cyan,
        .purple,
        .orange,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Genre DNA", systemImage: "theatermasks")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 16) {
                // Donut chart
                Chart(Array(topGenres.enumerated()), id: \.element.id) { index, genre in
                    SectorMark(
                        angle: .value("Count", genre.count),
                        innerRadius: .ratio(0.6),
                        outerRadius: .inset(10),
                        angularInset: 1.5
                    )
                    .cornerRadius(3)
                    .foregroundStyle(colorFor(index: index))
                }
                .frame(width: 160, height: 160)
                .accessibilityChartDescriptor(GenreDNAAccessibility(genres: topGenres))
                .accessibilityLabel("Genre distribution chart")

                // Legend
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(topGenres.enumerated()), id: \.element.id) { index, genre in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(colorFor(index: index))
                                .frame(width: 8, height: 8)

                            Text(genre.genre)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer()

                            Text("\(genre.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func colorFor(index: Int) -> Color {
        genreColors[index % genreColors.count]
    }
}

struct GenreDNAAccessibility: AXChartDescriptorRepresentable {
    let genres: [CareerGenreStat]

    func makeChartDescriptor() -> AXChartDescriptor {
        let total = genres.reduce(0) { $0 + $1.count }

        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Genre",
            categoryOrder: genres.map(\.genre)
        )

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Count",
            range: 0...Double(genres.first?.count ?? 1),
            gridlinePositions: []
        ) { "\(Int($0)) titles" }

        let dataPoints = genres.map { genre in
            AXDataPoint(
                x: genre.genre,
                y: Double(genre.count),
                label: "\(genre.genre): \(genre.count) titles (\(total > 0 ? "\(genre.count * 100 / total)%" : "0%"))"
            )
        }

        let series = AXDataSeriesDescriptor(
            name: "Genre Distribution",
            isContinuous: false,
            dataPoints: dataPoints
        )

        return AXChartDescriptor(
            title: "Genre DNA",
            summary: "Top genres: \(genres.prefix(3).map(\.genre).joined(separator: ", ")). \(total) total titles.",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview {
    GenreDNAChart(genres: [
        CareerGenreStat(genre: "Drama", count: 25),
        CareerGenreStat(genre: "Action", count: 18),
        CareerGenreStat(genre: "Thriller", count: 12),
        CareerGenreStat(genre: "Comedy", count: 8),
        CareerGenreStat(genre: "Sci-Fi", count: 6),
        CareerGenreStat(genre: "Romance", count: 4),
    ])
    .padding()
    .background(Color.plotlineBackground)
}
