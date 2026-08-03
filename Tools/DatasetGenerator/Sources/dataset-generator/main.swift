import DatasetGeneratorCore

// Run with:
//   TMDB_API_KEY=... swift run --package-path Tools/DatasetGenerator dataset-generator
//
// Writes Plotline/Resources/PlotlineDataset.json. Never part of the app build;
// run by hand when preparing a release.

try await Generator.run()
