import SwiftUI
import Charts

/// Main comparison screen for side-by-side movie and series analysis
struct CompareView: View {
    @State private var viewModel = CompareViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    slotsRow
                    if viewModel.canCompare {
                        ratingsSection
                        if viewModel.hasAnyMovie {
                            boxOfficeSection
                        }
                        if viewModel.hasAnySeries {
                            episodeOverlaySection
                        }
                        metadataSection
                    } else {
                        emptyPrompt
                    }
                }
                .padding()
            }
            .background(Color.plotlineBackground)
            .navigationTitle("Compare")
            .sheet(isPresented: $viewModel.showSearch) {
                searchSheet
            }
        }
    }

    // MARK: - Slots Row

    private var slotsRow: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                ComparisonSlotView(
                    item: viewModel.slots[index],
                    isLoading: viewModel.isLoadingSlot[index] == true,
                    onTap: {
                        viewModel.openSearchSheet(for: index)
                    },
                    onRemove: viewModel.slots[index] != nil ? {
                        viewModel.removeSlot(index)
                    } : nil
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Ratings Section

    private var ratingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Ratings", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(viewModel.allRatingSources, id: \.self) { sourceName in
                RatingComparisonBar(
                    sourceName: sourceName,
                    items: viewModel.filledSlots,
                    normalizedValue: { source, item in
                        viewModel.normalizedRating(for: source, item: item)
                    },
                    displayValue: { source, item in
                        viewModel.displayRating(for: source, item: item)
                    }
                )
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Box Office Section

    private var boxOfficeSection: some View {
        let movieSlots = viewModel.filledSlots.filter { !$0.item.isTVSeries && $0.item.boxOffice != nil }

        return Group {
            if movieSlots.count >= 1 {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Box Office", systemImage: "dollarsign.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Chart {
                        ForEach(movieSlots, id: \.item.id) { index, item in
                            if let boxOffice = item.boxOffice {
                                if boxOffice.budget > 0 {
                                    BarMark(
                                        x: .value("Amount", Double(boxOffice.budget)),
                                        y: .value("Title", item.displayTitle)
                                    )
                                    .foregroundStyle(by: .value("Type", "Budget"))
                                }
                                if boxOffice.revenue > 0 {
                                    BarMark(
                                        x: .value("Amount", Double(boxOffice.revenue)),
                                        y: .value("Title", item.displayTitle)
                                    )
                                    .foregroundStyle(by: .value("Type", "Revenue"))
                                }
                            }
                        }
                    }
                    .chartForegroundStyleScale([
                        "Budget": Color.plotlineSecondaryAccent,
                        "Revenue": Color.rottenGreen
                    ])
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(formatCurrency(amount))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartLegend(.visible)
                    .frame(height: CGFloat(max(movieSlots.count, 1)) * 80 + 40)
                }
                .padding()
                .background(Color.plotlineCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Episode Overlay Section

    private var episodeOverlaySection: some View {
        let seriesSlots = viewModel.filledSlots.filter { $0.item.isTVSeries }
        let lineColors: [Color] = [.plotlineGold, .plotlineSecondaryAccent, .plotlinePrimary]

        return Group {
            if seriesSlots.count >= 1 {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Episode Ratings", systemImage: "chart.xyaxis.line")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Chart {
                        ForEach(seriesSlots, id: \.item.id) { index, item in
                            let episodes = viewModel.allEpisodesFlat(for: item.id)
                                .filter { $0.hasValidRating }

                            ForEach(Array(episodes.enumerated()), id: \.offset) { epIndex, episode in
                                LineMark(
                                    x: .value("Episode", epIndex + 1),
                                    y: .value("Rating", episode.rating)
                                )
                                .foregroundStyle(by: .value("Series", item.displayTitle))
                                .interpolationMethod(.catmullRom)

                                PointMark(
                                    x: .value("Episode", epIndex + 1),
                                    y: .value("Rating", episode.rating)
                                )
                                .foregroundStyle(by: .value("Series", item.displayTitle))
                                .symbolSize(20)
                            }
                        }
                    }
                    .chartForegroundStyleScale(
                        domain: seriesSlots.map(\.item.displayTitle),
                        range: seriesSlots.enumerated().map { idx, _ in
                            lineColors[idx % lineColors.count]
                        }
                    )
                    .chartYScale(domain: 0...10)
                    .chartYAxis {
                        AxisMarks(values: [0, 2, 4, 6, 8, 10]) { value in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartLegend(.visible)
                    .frame(height: 220)
                }
                .padding()
                .background(Color.plotlineCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Genres", systemImage: "tag.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            let shared = viewModel.sharedGenreIds

            FlowLayout(spacing: 8) {
                ForEach(viewModel.allGenreIds, id: \.self) { genreId in
                    if let name = GenreLookup.name(for: genreId) {
                        let isShared = shared.contains(genreId)
                        Text(name)
                            .font(.caption)
                            .fontWeight(isShared ? .semibold : .regular)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                isShared
                                    ? Color.plotlineGold.opacity(0.2)
                                    : Color.plotlineCard
                            )
                            .foregroundStyle(isShared ? Color.plotlineGold : .secondary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        isShared ? Color.plotlineGold.opacity(0.5) : Color.secondary.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    }
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Empty Prompt

    private var emptyPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Add at least 2 titles to compare")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Search Sheet

    private var searchSheet: some View {
        NavigationStack {
            List {
                ForEach(viewModel.searchResults) { item in
                    Button {
                        viewModel.showSearch = false
                        Task {
                            await viewModel.selectItem(item, for: viewModel.searchSlotIndex)
                        }
                    } label: {
                        searchResultRow(item: item)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchQuery, prompt: "Movies or TV series")
            .onChange(of: viewModel.searchQuery) {
                viewModel.performSearch()
            }
            .overlay(content: {
                Group {
                    if viewModel.isSearching {
                        ProgressView()
                    } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                        ContentUnavailableView.search(text: viewModel.searchQuery)
                    }
                }
            })
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showSearch = false
                    }
                }
            }
        }
    }

    // MARK: - Search Result Row

    private func searchResultRow(item: MediaItem) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    Rectangle()
                        .fill(Color.plotlineCard)
                        .overlay(content: {
                            Image(systemName: "film")
                                .foregroundStyle(.secondary)
                        })
                }
            }
            .frame(width: 44, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let year = item.year {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if item.isTVSeries {
                        Text("TV")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.plotlineSecondaryAccent.opacity(0.2))
                            .foregroundStyle(Color.plotlineSecondaryAccent)
                            .clipShape(Capsule())
                    } else {
                        Text("Movie")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.plotlineGold.opacity(0.2))
                            .foregroundStyle(Color.plotlineGold)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            if item.voteAverage > 0 {
                Text(item.formattedRating)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.plotlineGold)
            }
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return String(format: "$%.1fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "$%.0fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "$%.0fK", value / 1_000)
        }
        return String(format: "$%.0f", value)
    }
}

// MARK: - Flow Layout

// MARK: - Preview

#Preview {
    CompareView()
}
