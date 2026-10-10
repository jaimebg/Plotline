import DatasetGeneratorCore

// Run from the repository root:
//   TMDB_API_KEY=... swift run --package-path Tools/DatasetGenerator dataset-generator seed
//     Rewrites Tools/DatasetGenerator/Sources/DatasetGeneratorCore/SeedList.swift.
//   TMDB_API_KEY=... swift run --package-path Tools/DatasetGenerator dataset-generator
//     Writes Plotline/Resources/PlotlineDataset.json.
//
// Never part of the app build; run by hand when preparing a release.

if CommandLine.arguments.dropFirst().first == "seed" {
    try await SeedCommand.run()
} else {
    try await Generator.run()
}
