import SwiftUI

/// Full career analytics screen for an actor or director
struct CareerProfileView: View {
    let personId: Int
    let personName: String

    @State private var viewModel = CareerProfileViewModel()
    @State private var bioExpanded = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.person != nil {
                profileContent
            } else {
                ContentUnavailableView(
                    "Profile Unavailable",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Could not load profile for \(personName).")
                )
            }
        }
        .background(Color.plotlineBackground)
        .navigationTitle(personName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.person == nil {
                await viewModel.loadProfile(personId: personId)
            }
        }
    }

    // MARK: - Profile Content

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                careerScoreSection
                if !viewModel.timelinePoints.isEmpty {
                    CareerTimelineChart(points: viewModel.timelinePoints)
                }
                if !viewModel.topTen.isEmpty {
                    topTenSection
                }
                if !viewModel.genreDistribution.isEmpty {
                    GenreDNAChart(genres: viewModel.genreDistribution)
                }
                quickStatsSection
                filmographySection
            }
            .padding()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Profile photo
            AsyncImage(url: viewModel.person?.profileURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else if case .empty = phase {
                    Rectangle().fill(Color.plotlineCard).shimmering()
                } else {
                    Rectangle().fill(Color.plotlineCard).overlay {
                        Image(systemName: "person.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 100, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.person?.name ?? personName)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                if let age = viewModel.person?.age {
                    let isDeceased = viewModel.person?.deathday != nil
                    Text(isDeceased ? "Died at age \(age)" : "Age \(age)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let place = viewModel.person?.placeOfBirth {
                    Label(place, systemImage: "mappin.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let department = viewModel.person?.knownForDepartment {
                    Text(department)
                        .font(.caption)
                        .foregroundStyle(Color.plotlineGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.plotlineGold.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))

        // Biography below header card
        .overlay(alignment: .bottom) {
            if let bio = viewModel.person?.biography, !bio.isEmpty {
                EmptyView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let bio = viewModel.person?.biography, !bio.isEmpty {
                biographyView(bio)
            }
        }
    }

    @ViewBuilder
    private func biographyView(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(bio)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(bioExpanded ? nil : 3)

            Button(bioExpanded ? "Show Less" : "Read More") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    bioExpanded.toggle()
                }
            }
            .font(.caption.bold())
            .foregroundStyle(Color.plotlineSecondaryAccent)
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Career Score

    private var careerScoreSection: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(String(format: "%.1f", viewModel.careerScore))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.plotlineGold)
                Text("Career Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 50)

            VStack(spacing: 4) {
                Text("\(viewModel.totalTitles)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Total Titles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Career score \(String(format: "%.1f", viewModel.careerScore)) out of 10. \(viewModel.totalTitles) total titles")
    }

    // MARK: - Top 10

    private var topTenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Top 10", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(viewModel.topTen) { item in
                        NavigationLink(value: item) {
                            MediaCard(item: item, style: .poster)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Quick Stats

    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Stats", systemImage: "info.circle")
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                quickStatItem(
                    icon: "calendar.badge.clock",
                    title: "Most Active",
                    value: viewModel.mostActiveDecade ?? "--",
                    color: .plotlineSecondaryAccent
                )
                quickStatItem(
                    icon: "tag.fill",
                    title: "Top Genre",
                    value: viewModel.mostFrequentGenre ?? "--",
                    color: .plotlineGold
                )
                quickStatItem(
                    icon: "arrow.up.circle.fill",
                    title: "Best Rated",
                    value: bestRatedText,
                    color: .rottenGreen
                )
                quickStatItem(
                    icon: "arrow.down.circle.fill",
                    title: "Worst Rated",
                    value: worstRatedText,
                    color: .plotlinePrimary
                )
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var bestRatedText: String {
        guard let best = viewModel.bestTitle else { return "--" }
        return "\(best.name) (\(String(format: "%.1f", best.rating)))"
    }

    private var worstRatedText: String {
        guard let worst = viewModel.worstTitle else { return "--" }
        return "\(worst.name) (\(String(format: "%.1f", worst.rating)))"
    }

    private func quickStatItem(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Filmography

    private var filmographySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Filmography", systemImage: "film.stack")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Picker("", selection: $viewModel.filmographyFilter) {
                    ForEach(CareerProfileViewModel.FilmographyFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            ForEach(viewModel.filteredFilmography, id: \.decade) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.decade)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.plotlineGold)
                        .padding(.top, 4)

                    ForEach(group.items) { item in
                        NavigationLink(value: item) {
                            filmographyRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func filmographyRow(_ item: MediaItem) -> some View {
        HStack(spacing: 12) {
            // Mini poster
            AsyncImage(url: item.posterURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(Color.plotlineCard).overlay {
                        Image(systemName: "film")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 40, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let year = item.year {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if item.isTVSeries {
                        Text("TV")
                            .font(.caption2)
                            .foregroundStyle(Color.plotlineGold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.plotlineGold.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            if item.voteAverage > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.imdbYellow)
                    Text(item.formattedRating)
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading career profile...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        CareerProfileView(personId: 6193, personName: "Leonardo DiCaprio")
    }
}
