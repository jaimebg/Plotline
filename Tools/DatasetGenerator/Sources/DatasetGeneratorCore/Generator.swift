import Foundation

public enum Generator {
    /// Replaced by the real pipeline in Task 5. For now it only proves the
    /// executable can reach the library and the library can reach the engine.
    public static func run() async throws {
        print("dataset-generator: shared engine linked, \(SeriesAnalysisEngine.minimumVotesPerEpisode) vote floor")
    }
}
