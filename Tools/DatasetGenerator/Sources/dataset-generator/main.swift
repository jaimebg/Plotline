import DatasetGeneratorCore

// Run with: TMDB_API_KEY=... swift run --package-path Tools/DatasetGenerator dataset-generator
// This tool is never part of the app build. It is run by hand when preparing a
// release, and its output is committed as Plotline/Resources/PlotlineDataset.json.

try await Generator.run()
