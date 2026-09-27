import AppIntents
import SwiftUI

/// Siri's answer to "how does this series hold up?" — the Plotline Score and
/// the verdicts behind it, in numbers, without opening the app.
///
/// A series in the bundled dataset answers from the bundled analysis, and says
/// so. Any other series is fetched and analysed on the spot, under the same
/// rule as the detail screen: a season that fails to load means no verdict,
/// and the engine's own refusal is stated rather than softened.
struct GetPlotlineVerdictIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Plotline Verdict"
    static let description = IntentDescription(
        "Get a series' Plotline Score, its level, consistency and trajectory, and where it declines."
    )
    static let openAppWhenRun = false

    @Parameter(title: "Series", requestValueDialog: "Which series?")
    var series: SeriesEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get the Plotline verdict for \(\.$series)")
    }

    init() {}

    init(series: SeriesEntity) {
        self.series = series
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let report = await VerdictLoader.report(for: series)
        return .result(
            dialog: IntentDialog(stringLiteral: VerdictCopy.dialog(for: report)),
            view: VerdictSnippetView(report: report)
        )
    }
}

// MARK: - Snippet

/// The verdict as Siri and Shortcuts show it: the score with its three
/// components, the decline and ending verdicts with their numbers, and what
/// it all rests on. A refusal shows the engine's reason instead.
struct VerdictSnippetView: View {
    let report: VerdictReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            switch report.outcome {
            case .analyzed(let analysis, let source):
                analyzed(analysis, source: source)
            case .refused(let reason, let failedSeasons):
                let refusal = VerdictCopy.refusal(reason, failedSeasons: failedSeasons)
                message(title: refusal.title, body: refusal.explanation)
            case .couldNotLoad:
                message(title: "Couldn't Load", body: VerdictCopy.couldNotLoad(report.series.name))
            case .timedOut:
                message(title: "Took Too Long", body: VerdictCopy.timedOut(report.series.name))
            }

            Button(intent: OpenSeriesIntent(series: report.series)) {
                Label("Open in Plotline", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.plotlineAccent)
        }
        .padding()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(report.series.name)
                .font(.headline)
                .foregroundStyle(.primary)
            if let year = report.series.year {
                Text(year)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func analyzed(_ analysis: SeriesAnalysis, source: VerdictSource) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(analysis.score.value)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Color.plotlineGold)
            VStack(alignment: .leading, spacing: 0) {
                Text("Plotline Score")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Out of 100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)

        HStack(spacing: 8) {
            component("Level", value: analysis.score.level)
            component("Consistency", value: analysis.score.consistency)
            component("Trajectory", value: analysis.score.trajectory)
        }

        ForEach(Array(VerdictCopy.verdictRows(analysis).enumerated()), id: \.offset) { _, row in
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(row.evidence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }

        Text(VerdictCopy.basis(analysis, source: source))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func component(_ name: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Text("\(value)")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            ProgressView(value: Double(value), total: 100)
                .tint(Color.plotlineGold)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(value) out of 100")
    }

    private func message(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
