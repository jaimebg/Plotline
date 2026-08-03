// swift-tools-version: 6.0
import PackageDescription

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
