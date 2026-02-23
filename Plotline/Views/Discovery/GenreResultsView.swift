import SwiftUI

/// Filtered results view for a specific curated genre
struct GenreResultsView: View {
    let genre: CuratedGenre

    @Environment(\.navigationNamespace) private var namespace
    @State private var viewModel = GenreResultsViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Media type toggle
                Picker("Type", selection: Binding(
                    get: { viewModel.selectedMediaType },
                    set: { newType in
                        viewModel.selectedMediaType = newType
                        Task { await viewModel.loadResults(genre: genre) }
                    }
                )) {
                    ForEach(GenreMediaType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if viewModel.isLoadingResults {
                    resultsLoadingGrid
                } else if viewModel.results.isEmpty && viewModel.errorMessage != nil {
                    ContentUnavailableView {
                        Label("Unable to Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(viewModel.errorMessage ?? "")
                    } actions: {
                        Button("Try Again") {
                            Task { await viewModel.loadResults(genre: genre) }
                        }
                        .buttonStyle(.bordered)
                    }
                } else if viewModel.results.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "film",
                        description: Text("No \(viewModel.selectedMediaType.rawValue.lowercased()) found for \(genre.name)")
                    )
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.results) { item in
                            NavigationLink(value: item) {
                                MediaCard(item: item, style: .poster)
                            }
                            .if(namespace != nil) { view in
                                view.matchedTransitionSource(id: item.id, in: namespace!)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if item.id == viewModel.results.last?.id && viewModel.canLoadMore {
                                    Task { await viewModel.loadMore(genre: genre) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding()
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.plotlineBackground)
        .scrollIndicators(.hidden)
        .navigationTitle(genre.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
        .task {
            if viewModel.results.isEmpty {
                await viewModel.loadResults(genre: genre)
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(GenreSort.allCases, id: \.self) { sort in
                Button {
                    viewModel.selectedSort = sort
                    Task { await viewModel.loadResults(genre: genre) }
                } label: {
                    Label(sort.rawValue, systemImage: sort.icon)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.body)
                .foregroundStyle(Color.plotlinePrimary)
        }
    }

    private var resultsLoadingGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<8, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.plotlineCard)
                        .aspectRatio(2.0/3.0, contentMode: .fit)
                        .shimmering()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.plotlineCard)
                        .frame(height: 14)
                        .shimmering()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.plotlineCard)
                        .frame(width: 60, height: 12)
                        .shimmering()
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GenreResultsView(genre: CuratedGenre.all[0])
    }
}
