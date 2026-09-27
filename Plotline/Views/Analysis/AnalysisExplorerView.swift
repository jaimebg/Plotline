import SwiftUI

/// The Analysis tab: every bundled series, filtered by the engine's own
/// verdicts.
///
/// Reads nothing but the bundled dataset, so it is complete offline and with
/// no TMDB key. Each chip is one engine predicate (`AnalysisTrait`); the
/// optional description field only fills the chips in, through Apple's
/// on-device model, and never says anything about a series itself.
struct AnalysisExplorerView: View {
    /// A result row needs room for a poster, a title and its verdict chips:
    /// one column on every iPhone, two or more on an iPad.
    static let minimumRowWidth = AdaptiveLayout.minimumColumnWidth * 2

    @Environment(\.themeManager) private var themeManager
    @State private var viewModel = AnalysisExplorerViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var interpretTask: Task<Void, Never>?
    /// Remembered per viewer: someone who has learnt the chips can fold them
    /// away and get straight to the results.
    @AppStorage("analysis.showsFilters") private var showsFilters = true
    /// Read again on appear and on returning to the foreground: the model can
    /// finish downloading, or Apple Intelligence be switched on, meanwhile.
    @State private var availability: AnalysisTranslatorAvailability?
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isRequestFocused: Bool
    @Namespace private var namespace

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro
                    requestSection
                    filtersSection
                    resultsSection
                    datasetNote
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.plotlineBackground)
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
            }
            .navigationDestination(for: MediaItem.self) { item in
                MediaDetailView(media: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: namespace))
            }
        }
        .environment(\.navigationNamespace, namespace)
        .preferredColorScheme(themeManager.colorScheme)
        .onAppear { availability = viewModel.translatorAvailability }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                availability = viewModel.translatorAvailability
            }
        }
    }

    // MARK: - Intro

    private var intro: some View {
        Text("Each filter is one of Plotline's verdicts on a series' episode ratings. Several in one group allow any of them; filters in different groups must all hold.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .leadingReadableWidth()
    }

    // MARK: - Natural language

    @ViewBuilder
    private var requestSection: some View {
        switch availability ?? viewModel.translatorAvailability {
        case .available:
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .bottom, spacing: 10) {
                    TextField(
                        "What are you in the mood for?",
                        text: $viewModel.request,
                        axis: .vertical
                    )
                    .lineLimit(1...4)
                    .focused($isRequestFocused)
                    .submitLabel(.search)
                    .onSubmit(interpret)
                    .padding(12)
                    .background(Color.plotlineCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button(action: interpret) {
                        if viewModel.requestState == .interpreting {
                            ProgressView()
                                .frame(width: 22, height: 22)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color.plotlineAccent)
                    .disabled(
                        viewModel.request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || viewModel.requestState == .interpreting
                    )
                    .accessibilityLabel("Turn description into filters")
                }

                requestStatus
            }
            .leadingReadableWidth()

        case .unavailable(let explanation):
            Label(explanation, systemImage: "sparkles")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .leadingReadableWidth()
        }
    }

    @ViewBuilder
    private var requestStatus: some View {
        switch viewModel.requestState {
        case .idle:
            Text("For example: a finished show that ends strong and stays steady. Apple's on-device model only turns your words into the filters below; every verdict comes from Plotline's analysis.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .interpreting:
            Text("Interpreting on device…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .interpreted(let selection, let sort, let unmatched):
            Text(AnalysisExplorerViewModel.interpretationSummary(
                selection: selection,
                sort: sort,
                unmatchedGenres: unmatched
            ) + (selection.isEmpty ? "" : ". Change any chip below to adjust it."))
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func interpret() {
        isRequestFocused = false
        interpretTask?.cancel()
        interpretTask = Task {
            await viewModel.interpretRequest()
        }
    }

    // MARK: - Filters

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Filters")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                if !viewModel.selection.isEmpty {
                    Text("\(viewModel.selection.count) selected")
                        .font(.caption)
                        .foregroundStyle(Color.plotlineAccent)
                }

                Spacer()

                Button(showsFilters ? "Hide" : "Show") {
                    withAnimation(.snappy) { showsFilters.toggle() }
                }
                .font(.subheadline)
                .tint(Color.plotlineAccent)
                .accessibilityLabel(showsFilters ? "Hide filters" : "Show filters")
            }

            if showsFilters {
                filterCategories
            }
        }
    }

    private var filterCategories: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(TraitCategory.allCases) { category in
                let traits = viewModel.traits(in: category)
                if !traits.isEmpty {
                    TraitCategoryRow(
                        category: category,
                        traits: traits,
                        isSelected: viewModel.isSelected,
                        toggle: { trait in
                            withAnimation(.snappy) { viewModel.toggle(trait) }
                        },
                        clear: {
                            withAnimation(.snappy) { viewModel.clear(category) }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Results

    private var resultsSection: some View {
        let results = viewModel.results

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.countSummary)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier(AccessibilityAnchors.analysisResultCount)

                Spacer()

                if !viewModel.selection.isEmpty {
                    Button("Clear filters") {
                        withAnimation(.snappy) { viewModel.clearFilters() }
                    }
                    .font(.subheadline)
                    .tint(Color.plotlineAccent)
                }
            }

            Text("Sorted by \(viewModel.sort.title), highest first")
                .font(.caption)
                .foregroundStyle(.secondary)

            if results.isEmpty {
                emptyState
            } else {
                LazyVGrid(
                    columns: GridItem.adaptiveColumns(minimumWidth: Self.minimumRowWidth),
                    alignment: .leading,
                    spacing: AdaptiveLayout.gridSpacing
                ) {
                    ForEach(results) { entry in
                        let item = PendingDetail(tmdbId: entry.tmdbId, mediaType: .tv, name: entry.name)
                            .mediaItem(bundled: entry)
                        NavigationLink(value: item) {
                            AnalysisResultRow(
                                entry: entry,
                                selection: viewModel.selection,
                                sort: viewModel.sort
                            )
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: item.id, in: namespace)
                        .accessibilityIdentifier(AccessibilityAnchors.analysisResultRow)
                    }
                }
            }
        }
    }

    /// Says which filters exclude everything, with how many series each one
    /// is holding back, and offers to drop it.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("No series matches all of these together", systemImage: "line.3.horizontal.decrease.circle")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.primary)

            let exclusions = viewModel.matchesWithoutEachCategory
            if exclusions.count > 1 {
                ForEach(exclusions, id: \.category) { exclusion in
                    Button {
                        withAnimation(.snappy) { viewModel.clear(exclusion.category) }
                    } label: {
                        HStack {
                            Text("Without \(exclusion.category.title): \(exclusion.count) series")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("Drop")
                                .foregroundStyle(Color.plotlineAccent)
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                }
            } else if let only = exclusions.first {
                Text("No analysed series has any of the \(only.category.title.lowercased()) traits chosen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Clear filters") {
                withAnimation(.snappy) { viewModel.clearFilters() }
            }
            .buttonStyle(.glass)
            .tint(Color.plotlineAccent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .leadingReadableWidth()
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: Binding(
                get: { viewModel.sort },
                set: { newSort in withAnimation(.snappy) { viewModel.sort = newSort } }
            )) {
                ForEach(AnalysisSort.allCases) { sort in
                    Text(sort.title).tag(sort)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.body)
                .foregroundStyle(Color.plotlineAccent)
                .accessibilityLabel("Sort series")
        }
    }

    private var datasetNote: some View {
        Text("These filters run on the analysis bundled with Plotline, built from TMDB episode ratings. A series' own page recomputes it from TMDB's latest ratings when it can, so the two can differ.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .leadingReadableWidth()
    }
}

// MARK: - Category row

/// One filter category: its name, its chips in a horizontal strip, and what
/// its chips can and cannot establish.
private struct TraitCategoryRow: View {
    let category: TraitCategory
    let traits: [AnalysisTrait]
    let isSelected: (AnalysisTrait) -> Bool
    let toggle: (AnalysisTrait) -> Void
    let clear: () -> Void
    @State private var showsFootnote = false

    private var hasSelection: Bool {
        traits.contains(where: isSelected)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(category.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                if category.footnote != nil {
                    Button {
                        withAnimation(.snappy) { showsFootnote.toggle() }
                    } label: {
                        Image(systemName: showsFootnote ? "info.circle.fill" : "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showsFootnote ? "Hide what \(category.title) means" : "What \(category.title) means")
                }

                Spacer()

                if hasSelection {
                    Button("Clear", action: clear)
                        .font(.caption)
                        .tint(Color.plotlineAccent)
                        .accessibilityLabel("Clear \(category.title) filters")
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(traits) { trait in
                        TraitChip(
                            trait: trait,
                            isSelected: isSelected(trait),
                            action: { toggle(trait) }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()

            if showsFootnote, let footnote = category.footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .leadingReadableWidth()
            }
        }
    }
}

/// A selectable filter chip.
private struct TraitChip: View {
    let trait: AnalysisTrait
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
                Text(trait.label)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? Color.plotlineAccent : Color.primary)
            .background(
                Capsule().fill(isSelected ? Color.plotlineAccent.opacity(0.15) : Color.plotlineCard)
            )
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.plotlineAccent : Color.secondary.opacity(0.25),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(trait.category.title): \(trait.label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Result row

/// A series in the results: poster, name, year, Plotline Score, and the
/// engine verdicts it carries — the ones the current filters asked for
/// highlighted.
struct AnalysisResultRow: View {
    let entry: DatasetEntry
    let selection: Set<AnalysisTrait>
    let sort: AnalysisSort

    private var posterURL: URL? {
        guard let path = entry.posterPath, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }

    private var verdicts: [AnalysisTrait] {
        AnalysisTrait.verdicts(of: entry.analysis)
    }

    /// Selected chips this series matches that its verdict list does not
    /// already show — "No decline point found", a status, a genre — so every
    /// reason it is in the results is visible on the row.
    private var otherMatches: [AnalysisTrait] {
        selection
            .filter { !verdicts.contains($0) && $0.matches(entry) }
            .sorted { $0.label < $1.label }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedAsyncImage(url: posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.plotlineBackground)
                    .overlay {
                        Image(systemName: "tv")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 60, height: 90)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.system(.headline, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        if let year = AnalysisExplorer.year(of: entry) {
                            Text(year)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 4)

                    scoreBadge
                }

                FlowLayout(spacing: 6) {
                    ForEach(verdicts + otherMatches) { trait in
                        verdictChip(trait)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the series")
    }

    private var scoreBadge: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("\(entry.analysis.score.value)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Color.plotlineGoldText)
                .monospacedDigit()
            Text(sort == .plotlineScore
                 ? "Score"
                 : "\(sort.title) \(sort.value(of: entry.analysis.score))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func verdictChip(_ trait: AnalysisTrait) -> some View {
        let matched = selection.contains(trait)
        return Text(trait.label)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(matched ? Color.plotlineAccent : Color.secondary)
            .background(
                Capsule().fill(matched ? Color.plotlineAccent.opacity(0.15) : Color.plotlineBackground)
            )
    }

    private var accessibilityLabel: String {
        var parts = [entry.name]
        if let year = AnalysisExplorer.year(of: entry) {
            parts.append(year)
        }
        parts.append("Plotline Score \(entry.analysis.score.value)")
        if sort != .plotlineScore {
            parts.append("\(sort.title) \(sort.value(of: entry.analysis.score))")
        }
        parts.append(contentsOf: (verdicts + otherMatches).map(\.label))
        return parts.joined(separator: ", ")
    }
}

private extension View {
    /// `readableWidth()`, but kept against the leading edge: on this screen
    /// the text sits above left-aligned chips and results, and a centred
    /// column would float away from them on an iPad.
    func leadingReadableWidth() -> some View {
        frame(maxWidth: AdaptiveLayout.readableMaximumWidth, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    AnalysisExplorerView()
}
