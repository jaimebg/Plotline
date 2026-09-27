import SwiftUI

/// Plotline's own analysis of each compared series, side by side.
///
/// This is what Compare adds over a ratings table: the engine's score and
/// verdicts, each with the numbers behind it. It names no winner. The only
/// emphasis is on the higher of a number where higher is unambiguous — the
/// score and its three components — and a tie emphasises nothing.
///
/// A slot the engine declined to judge shows its reason instead of numbers,
/// in the detail screen's own words; a movie slot says the analysis applies
/// to series.
struct CompareAnalysisSection: View {
    let entries: [CompareAnalysisEntry]
    let onRetry: (Int) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The same per-slot colours as the ratings bars and the episode chart, so
    /// a title keeps one colour across the whole screen.
    static let slotColors: [Color] = [.plotlineGold, .plotlineSecondaryAccent, .plotlineAccent]

    private var columns: [CompareAnalysisColumn] {
        entries.compactMap { entry in
            if case .analyzed(let column) = entry.state { return column }
            return nil
        }
    }

    var body: some View {
        let rows = CompareAnalysisTable.rows(for: columns)
        let notes = entries.filter { $0.note != nil }

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Plotline Analysis", systemImage: "waveform.path.ecg.rectangle")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Computed by Plotline from each series' TMDB episode ratings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !rows.isEmpty {
                if !stacksCells {
                    header
                }
                ForEach(rows) { row in
                    rowView(row)
                }
            }

            ForEach(notes, id: \.slotIndex) { entry in
                noteView(entry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// At accessibility text sizes three columns cannot hold a sentence, so
    /// each row lists its slots one under another, each named.
    private var stacksCells: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(columns, id: \.slotIndex) { column in
                slotName(column.label, slotIndex: column.slotIndex)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // Every row names its titles when read aloud.
        .accessibilityHidden(true)
    }

    private func slotName(_ label: String, slotIndex: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(Self.slotColors[slotIndex % Self.slotColors.count])
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }

    // MARK: - Rows

    private func rowView(_ row: CompareAnalysisTable.Row) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text(row.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            if let caption = row.caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if stacksCells {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(row.cells, id: \.slotIndex) { cell in
                        VStack(alignment: .leading, spacing: 2) {
                            slotName(cell.label, slotIndex: cell.slotIndex)
                            cellView(cell, isNumeric: row.isNumeric)
                        }
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(row.cells, id: \.slotIndex) { cell in
                        cellView(cell, isNumeric: row.isNumeric)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }

    @ViewBuilder
    private func cellView(_ cell: CompareAnalysisTable.Cell, isNumeric: Bool) -> some View {
        if isNumeric {
            HStack(spacing: 4) {
                Text(cell.value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(cell.isHighlighted ? Color.plotlineGoldText : .primary)
                // A shape as well as a colour, so the emphasis does not rest
                // on colour alone.
                if cell.isHighlighted {
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.plotlineGoldText)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(cell.isHighlighted ? Color.plotlineGold.opacity(0.2) : Color.clear)
            )
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(cell.value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = cell.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Notes

    private func noteView(_ entry: CompareAnalysisEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let note = entry.note {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle()
                        .fill(Self.slotColors[entry.slotIndex % Self.slotColors.count])
                        .frame(width: 8, height: 8)
                    Text(note.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    if entry.state == .loading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                Text(note.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if entry.canRetry {
                Button("Try Again") { onRetry(entry.slotIndex) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        // `.contain` so Try Again stays reachable on its own.
        .accessibilityElement(children: .contain)
    }
}
