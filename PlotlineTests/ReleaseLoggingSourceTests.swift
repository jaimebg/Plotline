import Foundation
import Testing
@testable import Plotline

/// Keeps diagnostic logging out of release builds.
///
/// Neither `print` nor `debugPrint` is compiled out of a release build — both
/// are ordinary functions, and their output is readable in Console.app on any
/// device running the shipped app. Every logging call in this project is
/// currently wrapped in `#if DEBUG`, which is what makes that safe. Nothing
/// enforced it until this suite: a new `print` added to a `catch` block during
/// debugging looks harmless in review and ships.
///
/// The exposure is not hypothetical. Most of these calls sit in `catch` blocks
/// and interpolate the error, and a `URLError` from `NetworkManager`'s TMDB
/// requests carries the failing URL in its description — including
/// `api_key=…`. `NetworkManager` also logs raw response JSON on a decoding
/// failure. Unguarded, that is the app printing its own credentials and
/// payloads into a log any connected Mac can read.
///
/// Scanned at source level rather than asserted at runtime for the same reason
/// as `CloudKitSchemaSourceTests`: the failure is that something *is emitted*
/// in a configuration these tests never run in, so there is nothing to observe
/// from inside them.
@Suite("Logging stays out of release builds")
struct ReleaseLoggingSourceTests {
    private static var appSources: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PlotlineTests/
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Plotline")
    }

    /// A logging call found outside any `#if DEBUG`.
    private struct Unguarded {
        let file: String
        let line: Int
        let text: String
    }

    /// Tracks `#if` nesting so a call is judged by whether *any* enclosing
    /// block is a DEBUG block. `#else` inverts the innermost condition, which
    /// matters: the release half of an `#if DEBUG / #else` is not guarded.
    private func unguardedLoggingCalls(in source: String, file: String) -> [Unguarded] {
        var conditions: [Bool] = []
        var found: [Unguarded] = []

        for (offset, rawLine) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("#if") {
                conditions.append(line.contains("DEBUG"))
                continue
            }
            if line.hasPrefix("#endif") {
                if !conditions.isEmpty { conditions.removeLast() }
                continue
            }
            if line.hasPrefix("#else") {
                if !conditions.isEmpty { conditions[conditions.count - 1].toggle() }
                continue
            }
            if line.hasPrefix("//") { continue }

            guard mentionsLoggingCall(line) else { continue }
            if conditions.contains(true) { continue }

            found.append(Unguarded(file: file, line: offset + 1, text: String(line.prefix(100))))
        }

        return found
    }

    /// `print(` / `debugPrint(` as a call, not as part of a longer identifier
    /// (`sprint(`) and not as a method on something else (`logger.print(`).
    private func mentionsLoggingCall(_ line: String) -> Bool {
        for name in ["print(", "debugPrint("] {
            var searchRange = line.startIndex..<line.endIndex
            while let found = line.range(of: name, range: searchRange) {
                let precedingIndex = found.lowerBound == line.startIndex
                    ? nil
                    : line.index(before: found.lowerBound)
                let preceding = precedingIndex.map { line[$0] }
                let isCallStart = preceding == nil
                    || !(preceding!.isLetter || preceding!.isNumber || preceding! == "." || preceding! == "_")
                if isCallStart { return true }
                searchRange = found.upperBound..<line.endIndex
            }
        }
        return false
    }

    @Test("no print or debugPrint runs outside #if DEBUG")
    func noUnguardedLogging() throws {
        let enumerator = try #require(
            FileManager.default.enumerator(at: Self.appSources, includingPropertiesForKeys: nil),
            "could not walk \(Self.appSources.path)"
        )

        var scannedFiles = 0
        var offenders: [Unguarded] = []

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            scannedFiles += 1
            offenders += unguardedLoggingCalls(in: source, file: url.lastPathComponent)
        }

        // Without this the suite passes trivially if the walk finds nothing —
        // the same trap release-preflight.sh guards against when it asserts it
        // extracted exactly five shelf titles.
        #expect(
            scannedFiles > 20,
            "only scanned \(scannedFiles) Swift file(s) under Plotline/ — the walk is not reaching the sources, so the assertion below proves nothing"
        )

        let report = offenders
            .map { "\($0.file):\($0.line)  \($0.text)" }
            .joined(separator: "\n  ")

        #expect(
            offenders.isEmpty,
            "\(offenders.count) logging call(s) run in release builds. print and debugPrint are not compiled out; in a catch block they interpolate errors whose description can carry the failing TMDB URL, api_key included. Wrap each in #if DEBUG:\n  \(report)"
        )
    }
}
