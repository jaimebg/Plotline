import SwiftUI

/// The full set of curated genres as a grid of tappable cards.
///
/// Selection is a closure rather than a `NavigationLink` because the caller has
/// to control *when* the push happens, not just where it goes. This grid renders
/// inside Discover's search state, and on iPad a push issued while the search
/// field is collapsing is silently lost. See
/// `DiscoveryView.pushAfterSearchCloses(_:)`.
struct GenreGrid: View {
    let genres: [CuratedGenre]
    let onSelect: (CuratedGenre) -> Void

    private let columns = GridItem.adaptiveColumns(minimumWidth: AdaptiveLayout.minimumColumnWidth)

    /// Predefined palette for genre cards, each fill paired with the label
    /// colour that clears 4.5:1 on it.
    ///
    /// White on every fill used to fail on the light half of the palette —
    /// yellow was under 2:1 — and the old fade to 70% opacity let the page
    /// background through, which cost the rest their margin in light mode.
    /// Fills are now opaque, so a card measures the same in both appearances.
    private static let palette: [GenreCard.Palette] = [
        .init(hex: "E53935", darkLabel: true),  // Red — black 5.0:1
        .init(hex: "8E24AA", darkLabel: false), // Purple
        .init(hex: "3949AB", darkLabel: false), // Indigo
        .init(hex: "1E88E5", darkLabel: true),  // Blue
        .init(hex: "00ACC1", darkLabel: true),  // Cyan
        .init(hex: "00897B", darkLabel: true),  // Teal
        .init(hex: "43A047", darkLabel: true),  // Green
        .init(hex: "7CB342", darkLabel: true),  // Light Green
        .init(hex: "F9A825", darkLabel: true),  // Yellow
        .init(hex: "FB8C00", darkLabel: true),  // Orange
        .init(hex: "6D4C41", darkLabel: false), // Brown
        .init(hex: "546E7A", darkLabel: false), // Blue Grey
        .init(hex: "D81B60", darkLabel: false), // Pink — white 5.0:1
        .init(hex: "5E35B1", darkLabel: false), // Deep Purple
        .init(hex: "1565C0", darkLabel: false), // Dark Blue
        .init(hex: "2E7D32", darkLabel: false), // Dark Green
        .init(hex: "EF6C00", darkLabel: true),  // Dark Orange
        .init(hex: "AD1457", darkLabel: false), // Dark Pink
        .init(hex: "4527A0", darkLabel: false), // Dark Indigo
        .init(hex: "00838F", darkLabel: false), // Dark Cyan — white 4.5:1
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(genres.enumerated()), id: \.element.id) { index, genre in
                Button {
                    onSelect(genre)
                } label: {
                    GenreCard(name: genre.name, palette: Self.palette[index % Self.palette.count])
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Card representing a single genre
struct GenreCard: View {
    struct Palette {
        let fill: Color
        /// Black on light fills, white on dark ones — whichever reaches 4.5:1.
        let label: Color
        let darkLabel: Bool

        init(hex: String, darkLabel: Bool) {
            fill = Color(hex: hex)
            label = darkLabel ? .black : .white
            self.darkLabel = darkLabel
        }
    }

    let name: String
    let palette: Palette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.fill)
                .overlay {
                    // A sheen that only ever moves the fill away from the
                    // label: lighter behind black text, darker behind white.
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.clear, palette.darkLabel ?.white.opacity(0.18) : .black.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

            Text(name)
                .font(.system(.headline, weight: .bold))
                .foregroundStyle(palette.label)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(height: 80)
        .shadow(color: palette.fill.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        GenreGrid(genres: Array(CuratedGenre.all.prefix(4))) { _ in }
            .padding()
    }
    .background(Color.plotlineBackground)
}
