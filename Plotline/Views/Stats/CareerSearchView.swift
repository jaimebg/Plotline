import SwiftUI

/// Search screen for finding people and viewing their career profiles
///
/// Pushed onto the Stats tab's stack, which already registers the
/// `MediaItem` destination every profile's links rely on. It carries neither a
/// stack nor a destination of its own: the nested stack and the three repeated
/// registrations competed with the parent's.
struct CareerSearchView: View {
    @State private var searchText = ""
    @State private var results: [TMDBPersonSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    /// Read from UserDefaults on appear rather than on every body pass, and
    /// re-read each time this screen comes back into view, so a profile just
    /// visited shows up in Recent without leaving the screen first.
    @State private var recentProfiles: [RecentCareerProfile] = []

    var body: some View {
        List {
            if searchText.isEmpty {
                recentSection
            } else if isSearching {
                searchingIndicator
            } else if results.isEmpty && !searchText.isEmpty {
                emptyResults
            } else {
                searchResultsSection
            }
        }
        .listStyle(.plain)
        .navigationTitle("Career Profiles")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search actors and directors")
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
        .onAppear {
            recentProfiles = CareerProfileViewModel.loadRecentProfiles()
        }
    }

    // MARK: - Recent Profiles

    @ViewBuilder
    private var recentSection: some View {
        if !recentProfiles.isEmpty {
            Section {
                ForEach(recentProfiles) { profile in
                    NavigationLink {
                        CareerProfileView(personId: profile.id, personName: profile.name)
                    } label: {
                        personRow(
                            name: profile.name,
                            department: nil,
                            imageURL: profile.profileURL
                        )
                    }
                }
            } header: {
                Text("Recent")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
        } else {
            ContentUnavailableView(
                "Search People",
                systemImage: "person.crop.circle.badge.magnifyingglass",
                description: Text("Find actors and directors to explore their career analytics.")
            )
        }
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        Section {
            ForEach(results) { person in
                NavigationLink {
                    CareerProfileView(personId: person.id, personName: person.name)
                } label: {
                    personRow(
                        name: person.name,
                        department: person.knownForDepartment,
                        imageURL: person.profileURL
                    )
                }
            }
        }
    }

    // MARK: - Person Row

    private func personRow(name: String, department: String?, imageURL: URL?) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: imageURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Circle().fill(Color.plotlineCard).overlay {
                        Image(systemName: "person.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                if let department {
                    Text(department)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - States

    private var searchingIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
    }

    private var emptyResults: some View {
        ContentUnavailableView.search(text: searchText)
    }

    // MARK: - Search Logic

    private func performSearch(query: String) {
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task {
            // Debounce
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            do {
                let searchResults = try await TMDBService.shared.searchPeople(query: query)
                guard !Task.isCancelled else { return }
                results = searchResults
            } catch {
                guard !Task.isCancelled else { return }
                results = []
            }

            isSearching = false
        }
    }
}

#Preview {
    NavigationStack {
        CareerSearchView()
    }
}
