// swift-tools-version: 6.0
import Foundation
import PackageDescription

// The app's sources are shared into this package as symlinks. Rename one of
// them app-side and the link dangles — at which point SwiftPM simply drops it
// from the target and says nothing. The only symptom is `cannot find 'X' in
// scope` at some unrelated use site, while the app's own build stays green, so
// the breakage can sit unnoticed until release time.
//
// A manifest is ordinary Swift, so it can just check. `fileExists(atPath:)`
// follows symlinks and returns false for a dangling one, which is exactly the
// question being asked.
let sharedDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Sources/DatasetGeneratorCore/Shared")

for file in ["EpisodeMetric.swift", "PlotlineDataset.swift", "SeriesAnalysis.swift", "SeriesAnalysisEngine.swift"] {
    let path = sharedDirectory.appendingPathComponent(file).path
    guard FileManager.default.fileExists(atPath: path) else {
        fatalError("""
        Shared source '\(file)' does not resolve at \(path).
        The symlink into the app's sources is dangling — the app-side file was \
        renamed, moved or deleted. Repoint the symlink; do not copy the file, \
        because two copies is exactly the drift sharing by path exists to prevent.
        """)
    }
}

let package = Package(
    name: "DatasetGenerator",
    platforms: [.macOS(.v13)],
    targets: [
        // One module holding both the generator's own code and symlinks to the
        // app's engine sources. Same module means `internal` works across both,
        // so sharing costs the app nothing — not one `public` keyword.
        .target(
            name: "DatasetGeneratorCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // A one-line shell. Everything worth testing lives in the library,
        // because a test target cannot `@testable import` an executable whose
        // main.swift carries top-level code.
        .executableTarget(
            name: "dataset-generator",
            dependencies: ["DatasetGeneratorCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "DatasetGeneratorTests",
            dependencies: ["DatasetGeneratorCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
