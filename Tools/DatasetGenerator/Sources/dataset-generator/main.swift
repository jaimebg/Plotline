import DatasetGeneratorCore
import Foundation

// Run from the repository root:
//   TMDB_API_KEY=... swift run --package-path Tools/DatasetGenerator dataset-generator seed
//     Rewrites Tools/DatasetGenerator/Sources/DatasetGeneratorCore/SeedList.swift.
//   TMDB_API_KEY=... swift run --package-path Tools/DatasetGenerator dataset-generator
//     Writes Plotline/Resources/PlotlineDataset.json.
// Any other argument prints usage and exits 2, without touching TMDB.
//
// Never part of the app build; run by hand when preparing a release.

switch GeneratorCommand(arguments: Array(CommandLine.arguments.dropFirst())) {
case .generate:
    try await Generator.run()
case .seed:
    try await SeedCommand.run()
case nil:
    FileHandle.standardError.write(Data(GeneratorCommand.usage.utf8))
    exit(2)
}
