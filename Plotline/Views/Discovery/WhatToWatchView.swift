import SwiftUI

/// Interactive 3-step sheet for personalized "What Should I Watch" recommendations
struct WhatToWatchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.favoritesManager) private var favoritesManager
    @Environment(\.watchlistManager) private var watchlistManager
    @State private var viewModel = WhatToWatchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step indicator
                stepIndicator
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                // Step content
                TabView(selection: $viewModel.currentStep) {
                    moodStep
                        .tag(1)

                    timeStep
                        .tag(2)

                    resultsStep
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
            }
            .background(Color.plotlineBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Close")
                    }
                }
            }
            .navigationDestination(for: MediaItem.self) { item in
                MediaDetailView(media: item)
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { step in
                Capsule()
                    .fill(step <= viewModel.currentStep ? Color.plotlineGold : Color.plotlineCard)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.25), value: viewModel.currentStep)
            }
        }
        .padding(.horizontal, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(viewModel.currentStep) of 3")
    }

    // MARK: - Step 1: Mood

    private var moodStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("How are you feeling?")
                        .font(.system(.title, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Pick one or more moods")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                MoodSelectionView(
                    moods: MoodFilter.all,
                    selectedMoods: viewModel.selectedMoods,
                    onToggle: { viewModel.toggleMood($0) }
                )
                .padding(.horizontal)

                Button {
                    withAnimation {
                        viewModel.currentStep = 2
                    }
                } label: {
                    Text("Next")
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(viewModel.canProceedFromStep1 ? .black : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            viewModel.canProceedFromStep1
                                ? Color.plotlineGold
                                : Color.plotlineCard
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!viewModel.canProceedFromStep1)
                .accessibilityHint(viewModel.canProceedFromStep1 ? "Double tap to continue" : "Select at least one mood to continue")
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Step 2: Time

    private var timeStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("What do you have time for?")
                        .font(.system(.title, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Choose your format")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                VStack(spacing: 12) {
                    ForEach(WatchTimeChoice.allCases, id: \.self) { choice in
                        timeChoiceButton(choice)
                    }
                }
                .padding(.horizontal)

                Button {
                    withAnimation {
                        viewModel.currentStep = 3
                    }
                    Task {
                        await viewModel.fetchResults(
                            favoriteIds: favoritesManager.favoriteIds,
                            watchlistIds: watchlistManager.watchlistIds,
                            topGenreIds: []
                        )
                    }
                } label: {
                    Text("Find Something")
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(viewModel.canProceedFromStep2 ? .black : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            viewModel.canProceedFromStep2
                                ? Color.plotlineGold
                                : Color.plotlineCard
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!viewModel.canProceedFromStep2)
                .accessibilityHint(viewModel.canProceedFromStep2 ? "Double tap to get recommendations" : "Select a format to continue")
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func timeChoiceButton(_ choice: WatchTimeChoice) -> some View {
        let isSelected = viewModel.selectedTime == choice

        return Button {
            viewModel.selectedTime = choice
        } label: {
            HStack(spacing: 16) {
                Image(systemName: choice.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.plotlineGold : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(choice.rawValue)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(choice == .movie ? "~2 hours" : "Multiple episodes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.plotlineGold)
                }
            }
            .padding(20)
            .background(isSelected ? Color.plotlineGold.opacity(0.2) : Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? Color.plotlineGold : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel("\(choice.rawValue), \(choice == .movie ? "about 2 hours" : "multiple episodes")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Step 3: Results

    private var resultsStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    loadingState
                } else if viewModel.results.isEmpty {
                    emptyState
                } else {
                    resultsContent
                }
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            ProgressView()
                .controlSize(.large)
                .tint(Color.plotlineGold)

            Text("Finding something great...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Finding recommendations, please wait")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No matches found")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Try different moods or format")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                viewModel.reset()
            } label: {
                Text("Start Over")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.plotlineGold)
            }
            .padding(.top, 8)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No matches found. Try different moods or format")
    }

    private var resultsContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Here's what we found")
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Based on your mood and preferences")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            VStack(spacing: 12) {
                ForEach(viewModel.results) { item in
                    NavigationLink(value: item) {
                        RecommendationCard(
                            item: item,
                            whyLine: viewModel.whyLines[item.id]
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Button {
                viewModel.shuffle(
                    favoriteIds: favoritesManager.favoriteIds,
                    watchlistIds: watchlistManager.watchlistIds
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shuffle")
                    Text("Shuffle")
                }
                .font(.system(.headline, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.plotlineGold)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}

// MARK: - Preview

#Preview {
    WhatToWatchView()
}
