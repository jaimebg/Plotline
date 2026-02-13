import SwiftUI

/// Grid view for browsing all genres
struct GenreBrowseView: View {
    let genres: [Genre]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    /// Predefined color palette for genre cards
    private static let genreColors: [Color] = [
        Color(hex: "E53935"), // Red
        Color(hex: "8E24AA"), // Purple
        Color(hex: "3949AB"), // Indigo
        Color(hex: "1E88E5"), // Blue
        Color(hex: "00ACC1"), // Cyan
        Color(hex: "00897B"), // Teal
        Color(hex: "43A047"), // Green
        Color(hex: "7CB342"), // Light Green
        Color(hex: "F9A825"), // Yellow
        Color(hex: "FB8C00"), // Orange
        Color(hex: "6D4C41"), // Brown
        Color(hex: "546E7A"), // Blue Grey
        Color(hex: "D81B60"), // Pink
        Color(hex: "5E35B1"), // Deep Purple
        Color(hex: "1565C0"), // Dark Blue
        Color(hex: "2E7D32"), // Dark Green
        Color(hex: "EF6C00"), // Dark Orange
        Color(hex: "AD1457"), // Dark Pink
        Color(hex: "4527A0"), // Dark Indigo
        Color(hex: "00838F"), // Dark Cyan
    ]

    var body: some View {
        ScrollView {
            if genres.isEmpty {
                genreLoadingGrid
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(genres.enumerated()), id: \.element.id) { index, genre in
                        NavigationLink(value: genre) {
                            GenreCard(genre: genre, color: Self.genreColors[index % Self.genreColors.count])
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .background(Color.plotlineBackground)
        .navigationTitle("Browse by Genre")
        .navigationBarTitleDisplayMode(.large)
    }

    private var genreLoadingGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<12, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.plotlineCard)
                    .frame(height: 80)
                    .shimmering()
            }
        }
        .padding()
    }
}

/// Card representing a single genre
struct GenreCard: View {
    let genre: Genre
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(genre.name)
                .font(.system(.headline, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(height: 80)
        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GenreBrowseView(genres: [
            Genre(id: 28, name: "Action"),
            Genre(id: 12, name: "Adventure"),
            Genre(id: 16, name: "Animation"),
            Genre(id: 35, name: "Comedy"),
        ])
    }
}
