import Accessibility
import Charts
import SwiftUI

/// Swift Charts visualization of a person's career ratings over time
struct CareerTimelineChart: View {
    let points: [CareerTimelinePoint]
    @State private var selectedYear: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Career Timeline", systemImage: "chart.xyaxis.line")
                .font(.headline)
                .foregroundStyle(.primary)

            Chart(points) { point in
                LineMark(
                    x: .value("Year", point.year),
                    y: .value("Rating", point.avgRating)
                )
                .foregroundStyle(Color.plotlineGold)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Year", point.year),
                    y: .value("Rating", point.avgRating)
                )
                .foregroundStyle(
                    point.year == selectedYear ? Color.plotlineSecondaryAccent : Color.plotlineGold
                )
                .symbolSize(point.year == selectedYear ? 60 : 24)
            }
            .frame(height: 180)
            .chartXSelection(value: $selectedYear)
            .chartYScale(domain: 0...10)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 2, 4, 6, 8, 10]) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color(.separator))
                    AxisValueLabel()
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .accessibilityChartDescriptor(CareerTimelineAccessibility(points: points))
            .accessibilityLabel("Career timeline chart")

            // Selected year overlay
            if let year = selectedYear,
               let point = points.first(where: { $0.year == year }) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(year)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(String(format: "%.1f avg", point.avgRating))
                            .font(.subheadline)
                            .foregroundStyle(Color.plotlineGold)
                    }

                    Text(point.titles.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(10)
                .background(Color.plotlineCard)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CareerTimelineAccessibility: AXChartDescriptorRepresentable {
    let points: [CareerTimelinePoint]

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Year",
            range: Double(points.first?.year ?? 2000)...Double(points.last?.year ?? 2024),
            gridlinePositions: points.map { Double($0.year) }
        ) { value in "Year \(Int(value))" }

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Average Rating",
            range: 0...10,
            gridlinePositions: [0, 2, 4, 6, 8, 10]
        ) { value in String(format: "%.1f", value) }

        let dataPoints = points.map { point in
            AXDataPoint(
                x: Double(point.year),
                y: point.avgRating,
                label: "\(point.year): \(String(format: "%.1f", point.avgRating)) – \(point.titles.joined(separator: ", "))"
            )
        }

        let series = AXDataSeriesDescriptor(
            name: "Career Ratings",
            isContinuous: true,
            dataPoints: dataPoints
        )

        return AXChartDescriptor(
            title: "Career Timeline",
            summary: makeSummary(),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }

    private func makeSummary() -> String {
        guard !points.isEmpty else { return "No career data available" }
        let avg = points.map(\.avgRating).reduce(0, +) / Double(points.count)
        let best = points.max { $0.avgRating < $1.avgRating }
        var summary = "\(points.count) years of data. Average rating \(String(format: "%.1f", avg))."
        if let best { summary += " Best year: \(best.year) with \(String(format: "%.1f", best.avgRating))." }
        return summary
    }
}

#Preview {
    CareerTimelineChart(points: [
        CareerTimelinePoint(year: 2010, avgRating: 6.5, titles: ["Movie A"]),
        CareerTimelinePoint(year: 2012, avgRating: 7.2, titles: ["Movie B", "Movie C"]),
        CareerTimelinePoint(year: 2014, avgRating: 8.1, titles: ["Movie D"]),
        CareerTimelinePoint(year: 2016, avgRating: 7.8, titles: ["Movie E"]),
        CareerTimelinePoint(year: 2018, avgRating: 8.5, titles: ["Movie F"]),
        CareerTimelinePoint(year: 2020, avgRating: 7.0, titles: ["Movie G"]),
    ])
    .padding()
    .background(Color.plotlineBackground)
}
