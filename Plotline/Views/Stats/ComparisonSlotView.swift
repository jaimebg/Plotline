import SwiftUI

/// Displays a single comparison slot: filled (poster + title), loading (spinner), or empty (dashed border + plus)
struct ComparisonSlotView: View {
    let item: MediaItem?
    let isLoading: Bool
    let onTap: () -> Void
    let onRemove: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isLoading {
                    loadingState
                } else if let item {
                    filledState(item: item)
                } else {
                    emptyState
                }
            }
            .frame(width: 100, height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - States

    private func filledState(item: MediaItem) -> some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: item.posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    posterPlaceholder
                case .empty:
                    posterPlaceholder
                        .overlay {
                            ProgressView()
                                .tint(.secondary)
                        }
                @unknown default:
                    posterPlaceholder
                }
            }
            .frame(width: 100, height: 170)
            .clipped()

            // Gradient overlay for text readability
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
            }

            // Title and year
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if let year = item.year {
                        Text(year)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Remove button
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, .black.opacity(0.6))
                        .shadow(radius: 2)
                }
                .padding(4)
            }
        }
    }

    private var loadingState: some View {
        posterPlaceholder
            .overlay {
                ProgressView()
                    .tint(.plotlineGold)
            }
    }

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
            .foregroundStyle(.secondary.opacity(0.5))
            .background(Color.plotlineCard.opacity(0.5))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Add")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
    }

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(Color.plotlineCard)
            .overlay {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.secondary.opacity(0.5))
            }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 12) {
        ComparisonSlotView(
            item: .moviePreview,
            isLoading: false,
            onTap: {},
            onRemove: {}
        )
        ComparisonSlotView(
            item: nil,
            isLoading: true,
            onTap: {},
            onRemove: nil
        )
        ComparisonSlotView(
            item: nil,
            isLoading: false,
            onTap: {},
            onRemove: nil
        )
    }
    .padding()
    .background(Color.plotlineBackground)
}
