/// What `dataset-generator` was asked to do. Strict on purpose: the default
/// command sends thousands of TMDB requests and rewrites the bundled dataset,
/// so a typo must never fall through to it.
public enum GeneratorCommand: Equatable {
    /// No argument: build `Plotline/Resources/PlotlineDataset.json`.
    case generate
    /// `seed`: rewrite `SeedList.swift` from TMDB's listings.
    case seed

    /// Nil for anything but no argument or exactly `seed`.
    public init?(arguments: [String]) {
        switch arguments {
        case []: self = .generate
        case ["seed"]: self = .seed
        default: return nil
        }
    }

    public static let usage = """
        usage: dataset-generator          rebuild Plotline/Resources/PlotlineDataset.json
               dataset-generator seed     rewrite the seed list from TMDB's listings
        Run from the repository root with TMDB_API_KEY set.

        """
}
