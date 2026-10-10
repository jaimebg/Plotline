import SwiftUI

/// A curated shelf in full: every member, best Plotline Score first, each with
/// the one verdict that put it on the shelf.
struct CuratedListView: View {
    let list: CuratedList

    static func ordered(_ entries: [DatasetEntry]) -> [DatasetEntry] {
        entries.sorted {
            if $0.analysis.score.value != $1.analysis.score.value {
                return $0.analysis.score.value > $1.analysis.score.value
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private var entries: [DatasetEntry] {
        Self.ordered(DatasetStore.shared.entries(for: list))
    }

    private var base: String? { CuratedListID(list.id)?.base }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                header

                ForEach(entries) { entry in
                    NavigationLink(value: entry.asMediaItem) {
                        CuratedListRow(
                            entry: entry,
                            evidence: base.flatMap { CuratedShelfEvidence.line(forShelf: $0, analysis: entry.analysis) }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .readableWidth()
        }
        .background(Color.plotlineBackground)
        .navigationTitle(CuratedListCopy.title(for: list.id) ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let eyebrow = CuratedListCopy.eyebrow(for: list.id) {
                Text(eyebrow)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.plotlineGoldText)
            }
            if let subtitle = CuratedListCopy.subtitle(for: list.id) {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("\(entries.count) series")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CuratedListRow: View {
    let entry: DatasetEntry
    let evidence: String?

    private var posterURL: URL? {
        guard let path = entry.posterPath, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedAsyncImage(url: posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.plotlineBackground)
                    .overlay { Image(systemName: "tv").foregroundStyle(.secondary) }
            }
            .frame(width: 60, height: 90)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let year = AnalysisExplorer.year(of: entry) {
                    Text(year)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let evidence {
                    Text(evidence)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(entry.analysis.score.value)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.plotlineGoldText)
                    .monospacedDigit()
                Text("Score")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the series")
    }
}
