import SwiftUI

/// Where this title can be watched in one region.
///
/// The attribution below is not decoration. TMDB's terms for this endpoint
/// require JustWatch be credited as the source of the data, and state that
/// non-compliant usage has its API access revoked. Since every screen in this
/// app is served by TMDB, that would not degrade a feature — it would turn the
/// product off. The credit therefore lives in the same view that draws the
/// providers, not in a modifier a call site has to remember.
struct WatchProvidersSection: View {
    static let attribution = "Streaming data provided by JustWatch"

    /// One non-empty category, already sorted for display.
    private struct Category {
        let title: String
        let providers: [WatchProvider]
    }

    let availability: RegionAvailability?
    let region: String
    let regions: [String]
    let onRegionChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let availability, !availability.isEmpty {
                ForEach(categories(in: availability), id: \.title) { category in
                    group(title: category.title, providers: category.providers)
                }
            } else {
                unavailable
            }

            Text(Self.attribution)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header

    /// Title plus the region picker. Rendered above the branch that decides
    /// between providers and the "nothing here" sentence, so it is on screen
    /// in both cases — the region control matters most exactly when the
    /// current region has nothing to show.
    private var header: some View {
        HStack {
            Text("Where to Watch")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            regionPicker
        }
    }

    private var regionPicker: some View {
        Picker(
            selection: Binding(get: { region }, set: onRegionChange)
        ) {
            ForEach(regions, id: \.self) { code in
                Text(regionName(for: code)).tag(code)
            }
        } label: {
            Text(regionName(for: region))
        }
        .pickerStyle(.menu)
        .font(.subheadline)
        .tint(Color.plotlineSecondaryAccent)
        .accessibilityLabel("Region")
        .accessibilityValue(regionName(for: region))
    }

    /// The region's English name when TMDB's own code maps to one, else the
    /// code itself. Anchored to `en_US` rather than `.current` so the label
    /// stays in English regardless of the device's own locale.
    private func regionName(for code: String) -> String {
        Locale(identifier: "en_US").localizedString(forRegionCode: code) ?? code
    }

    // MARK: - Groups

    private func group(title: String, providers: [WatchProvider]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(providers) { provider in
                        providerCell(provider)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func providerCell(_ provider: WatchProvider) -> some View {
        VStack(spacing: 4) {
            AsyncImage(url: provider.logoURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    logoPlaceholder
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(provider.providerName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 64)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(provider.providerName)
    }

    private var logoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.plotlineSecondary.opacity(0.3))
    }

    // MARK: - Unavailable

    private var unavailable: some View {
        let message = "Not available to stream, rent, or buy in \(regionName(for: region)) right now."

        return Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(message)
    }

    // MARK: - Categories

    /// The five categories in display order, with the empty ones dropped and
    /// the rest sorted by `displayPriority`.
    ///
    /// The order here — Stream, Free, With ads, Rent, Buy — is a deliberate
    /// choice about what a reader wants first: what is already included with
    /// something they may already pay for, ahead of what asks for money now.
    private func categories(in availability: RegionAvailability) -> [Category] {
        let groups: [(title: String, providers: [WatchProvider]?)] = [
            ("Stream", availability.flatrate),
            ("Free", availability.free),
            ("With ads", availability.ads),
            ("Rent", availability.rent),
            ("Buy", availability.buy),
        ]

        return groups.compactMap { title, providers in
            guard let providers, !providers.isEmpty else { return nil }
            return Category(title: title, providers: sortedByPriority(providers))
        }
    }

    /// TMDB's own ranking, ascending, with unranked providers pushed to the
    /// end rather than substituted with an alphabetical order that would
    /// discard a real signal TMDB is giving us.
    private func sortedByPriority(_ providers: [WatchProvider]) -> [WatchProvider] {
        providers.sorted { lhs, rhs in
            switch (lhs.displayPriority, rhs.displayPriority) {
            case let (left?, right?):
                return left < right
            case (nil, nil):
                return false
            case (nil, _):
                return false
            case (_, nil):
                return true
            }
        }
    }
}
