#!/usr/bin/env swift
// App Store copy, checked against the two things that can be checked
// mechanically: Apple's character limits, and characters bought twice.
//
// Two severities, on purpose. Exceeding a limit is a fact — App Store Connect
// will reject it — so it fails. "You are wasting eight characters on a term
// the subtitle already buys" is a judgement about ranking, and a judgement
// should not stop a release at three in the morning. It warns.
import Foundation

// Apple's limits for a single locale's App Store listing.
let budgets: [(file: String, limit: Int)] = [
    ("name", 30),
    ("subtitle", 30),
    ("keywords", 100),
    ("promotional_text", 170),
    ("description", 4000),
    ("release_notes", 4000)
]

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: aso-lint.swift <metadata-dir>\n".utf8))
    exit(2)
}

let localeDirectory = URL(fileURLWithPath: arguments[1]).appendingPathComponent("en-US")
var isDirectory: ObjCBool = false
guard FileManager.default.fileExists(atPath: localeDirectory.path, isDirectory: &isDirectory),
      isDirectory.boolValue else {
    FileHandle.standardError.write(Data("no such metadata directory: \(localeDirectory.path)\n".utf8))
    exit(2)
}

var failures = 0
var warnings = 0

func failed(_ message: String) { print("  ✗ \(message)"); failures += 1 }
func warned(_ message: String) { print("  ⚠ \(message)"); warnings += 1 }

/// Returns nil when the file is absent. An absent file is not an error here:
/// `deliver` simply leaves that App Store field alone.
func read(_ name: String) -> String? {
    let url = localeDirectory.appendingPathComponent("\(name).txt")
    guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
    return raw.trimmingCharacters(in: .whitespacesAndNewlines)
}

// --- Budgets. Over the limit fails. -----------------------------------------
for (file, limit) in budgets {
    guard let value = read(file) else { continue }
    // count on Character, not utf8: Apple counts what a reader sees, and the
    // description contains em dashes and curly quotes.
    let length = value.count
    if length > limit {
        failed("\(file) is \(length)/\(limit) characters — \(length - limit) over")
    }
}

// --- Waste in the keyword field. Warns only. --------------------------------
if let keywords = read("keywords") {
    if keywords.contains(" ") {
        let spaces = keywords.filter { $0 == " " }.count
        warned("keywords contains \(spaces) space character(s) — each one costs a character of the 100 and buys nothing")
    }

    let terms = keywords
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        .filter { !$0.isEmpty }

    // Apple indexes the app name and subtitle together with the keyword field,
    // so a term appearing in both is paid for twice.
    var alreadyBought = Set<String>()
    for field in ["name", "subtitle"] {
        guard let value = read(field) else { continue }
        for word in value.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            alreadyBought.insert(String(word))
        }
    }
    for term in terms where alreadyBought.contains(term) {
        warned("keyword '\(term)' is already bought by the app name or subtitle — \(term.count + 1) characters reclaimable")
    }

    var seen = Set<String>()
    for term in terms {
        if !seen.insert(term).inserted {
            warned("keyword '\(term)' appears more than once in the keyword field")
        }
    }

    // A singular sitting next to its own plural. Not authoritative about
    // Apple's stemming — hence a warning, not a failure.
    let termSet = Set(terms)
    for term in terms where termSet.contains(term + "s") {
        warned("keywords contains both '\(term)' and '\(term)s' — the plural is likely \(term.count + 2) wasted characters")
    }
}

if failures == 0 {
    print("  ✓ every store string within its App Store budget (\(warnings) warning(s))")
}
exit(failures == 0 ? 0 : 1)
