import Foundation

/// TMDB series ids baked into the dataset.
///
/// Chosen to span the shapes the analysis exists to describe, not merely the
/// most popular shows: runs that hold their level, runs that fall off, runs
/// that start slow and climb, and runs that land their finale.
enum SeedList {
    static let seriesIds: [Int] = [
        1396,   // Breaking Bad
        1398,   // The Sopranos
        1622,   // Supernatural
        1408,   // House
        1668,   // Friends
        1418,   // The Big Bang Theory
        60059,  // Better Call Saul
        1399,   // Game of Thrones
        66732,  // Stranger Things
        63174,  // Lucifer
        1438,   // The Wire
        4614,   // NCIS
        456,    // The Simpsons
        2316,   // The Office
        31917,  // Pretty Little Liars
        62286,  // Fear the Walking Dead
        1402,   // The Walking Dead
        71712,  // The Good Doctor
        60625,  // Rick and Morty
        82856,  // The Mandalorian
        87108,  // Chernobyl
        76479,  // The Boys
        94605,  // Arcane
        85271   // WandaVision
    ]
}
