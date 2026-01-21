import Foundation

/// Mock data for SwiftUI previews
enum MockData {
    // MARK: - Media Items

    static let breakingBad = MediaItem(
        id: 1396,
        overview: "A chemistry teacher diagnosed with inoperable lung cancer turns to manufacturing and selling methamphetamine with a former student to secure his family's future.",
        posterPath: "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
        backdropPath: "/tsRy63Mu5cu8etL1X7ZLyf7UFy8.jpg",
        voteAverage: 8.9,
        voteCount: 12500,
        genreIds: [18, 80],
        title: nil,
        releaseDate: nil,
        name: "Breaking Bad",
        firstAirDate: "2008-01-20",
        mediaType: .tv,
        imdbId: "tt0903747",
        externalRatings: MockData.ratings,
        seasonEpisodes: nil,
        totalSeasons: 5
    )

    static let fightClub = MediaItem(
        id: 550,
        overview: "A depressed man suffering from insomnia meets a strange soap salesman and soon finds himself living in his squalid house after his perfect apartment is destroyed.",
        posterPath: "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
        backdropPath: "/rr7E0NoGKxvbkb89eR1GwfoYjpA.jpg",
        voteAverage: 8.4,
        voteCount: 26000,
        genreIds: [18, 53],
        title: "Fight Club",
        releaseDate: "1999-10-15",
        name: nil,
        firstAirDate: nil,
        mediaType: .movie,
        imdbId: "tt0137523",
        externalRatings: nil,
        seasonEpisodes: nil,
        totalSeasons: nil
    )

    static let theOffice = MediaItem(
        id: 2316,
        overview: "The everyday lives of office employees in the Scranton, Pennsylvania branch of the fictional Dunder Mifflin Paper Company.",
        posterPath: "/qWnJzyZhyy74gjpSjIXWmuk0ifX.jpg",
        backdropPath: "/vNpuAxGTl9HsUbHqam3E9CzqCvX.jpg",
        voteAverage: 8.6,
        voteCount: 4200,
        genreIds: [35],
        title: nil,
        releaseDate: nil,
        name: "The Office",
        firstAirDate: "2005-03-24",
        mediaType: .tv,
        imdbId: "tt0386676",
        externalRatings: nil,
        seasonEpisodes: nil,
        totalSeasons: 9
    )

    static let inception = MediaItem(
        id: 27205,
        overview: "Cobb, a skilled thief who commits corporate espionage by infiltrating the subconscious of his targets is offered a chance to regain his old life.",
        posterPath: "/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg",
        backdropPath: "/s3TBrRGB1iav7gFOCNx3H31MoES.jpg",
        voteAverage: 8.4,
        voteCount: 34000,
        genreIds: [28, 878, 12],
        title: "Inception",
        releaseDate: "2010-07-16",
        name: nil,
        firstAirDate: nil,
        mediaType: .movie,
        imdbId: "tt1375666",
        externalRatings: nil,
        seasonEpisodes: nil,
        totalSeasons: nil
    )

    static let gameOfThrones = MediaItem(
        id: 1399,
        overview: "Seven noble families fight for control of the mythical land of Westeros. Friction between the houses leads to full-scale war.",
        posterPath: "/u3bZgnGQ9T01sWNhyveQz0wH0Hl.jpg",
        backdropPath: "/suopoADq0k8YZr4dQXcU6pToj6s.jpg",
        voteAverage: 8.4,
        voteCount: 21000,
        genreIds: [10765, 18, 10759],
        title: nil,
        releaseDate: nil,
        name: "Game of Thrones",
        firstAirDate: "2011-04-17",
        mediaType: .tv,
        imdbId: "tt0944947",
        externalRatings: nil,
        seasonEpisodes: nil,
        totalSeasons: 8
    )

    // MARK: - Sample Lists

    static let trendingMovies: [MediaItem] = [
        fightClub,
        inception,
        fightClub,
        inception
    ]

    static let trendingSeries: [MediaItem] = [
        breakingBad,
        theOffice,
        gameOfThrones,
        breakingBad
    ]

    // MARK: - Ratings

    static let ratings: [RatingSource] = [
        RatingSource(source: "Internet Movie Database", value: "9.5/10"),
        RatingSource(source: "Rotten Tomatoes", value: "96%"),
        RatingSource(source: "Metacritic", value: "87/100")
    ]

    // MARK: - Episodes

    static let breakingBadS1Episodes: [EpisodeMetric] = [
        EpisodeMetric(episodeNumber: 1, seasonNumber: 1, title: "Pilot", imdbRating: "9.0"),
        EpisodeMetric(episodeNumber: 2, seasonNumber: 1, title: "Cat's in the Bag...", imdbRating: "8.5"),
        EpisodeMetric(episodeNumber: 3, seasonNumber: 1, title: "...And the Bag's in the River", imdbRating: "8.7"),
        EpisodeMetric(episodeNumber: 4, seasonNumber: 1, title: "Cancer Man", imdbRating: "8.2"),
        EpisodeMetric(episodeNumber: 5, seasonNumber: 1, title: "Gray Matter", imdbRating: "8.3"),
        EpisodeMetric(episodeNumber: 6, seasonNumber: 1, title: "Crazy Handful of Nothin'", imdbRating: "9.2"),
        EpisodeMetric(episodeNumber: 7, seasonNumber: 1, title: "A No-Rough-Stuff-Type Deal", imdbRating: "8.8")
    ]

    static let breakingBadS5Episodes: [EpisodeMetric] = [
        EpisodeMetric(episodeNumber: 1, seasonNumber: 5, title: "Live Free or Die", imdbRating: "9.1"),
        EpisodeMetric(episodeNumber: 2, seasonNumber: 5, title: "Madrigal", imdbRating: "8.7"),
        EpisodeMetric(episodeNumber: 3, seasonNumber: 5, title: "Hazard Pay", imdbRating: "8.8"),
        EpisodeMetric(episodeNumber: 4, seasonNumber: 5, title: "Fifty-One", imdbRating: "8.8"),
        EpisodeMetric(episodeNumber: 5, seasonNumber: 5, title: "Dead Freight", imdbRating: "9.7"),
        EpisodeMetric(episodeNumber: 6, seasonNumber: 5, title: "Buyout", imdbRating: "9.1"),
        EpisodeMetric(episodeNumber: 7, seasonNumber: 5, title: "Say My Name", imdbRating: "9.4"),
        EpisodeMetric(episodeNumber: 8, seasonNumber: 5, title: "Gliding Over All", imdbRating: "9.6"),
        EpisodeMetric(episodeNumber: 9, seasonNumber: 5, title: "Blood Money", imdbRating: "9.3"),
        EpisodeMetric(episodeNumber: 10, seasonNumber: 5, title: "Buried", imdbRating: "9.2"),
        EpisodeMetric(episodeNumber: 11, seasonNumber: 5, title: "Confessions", imdbRating: "9.5"),
        EpisodeMetric(episodeNumber: 12, seasonNumber: 5, title: "Rabid Dog", imdbRating: "9.0"),
        EpisodeMetric(episodeNumber: 13, seasonNumber: 5, title: "To'hajiilee", imdbRating: "9.8"),
        EpisodeMetric(episodeNumber: 14, seasonNumber: 5, title: "Ozymandias", imdbRating: "10.0"),
        EpisodeMetric(episodeNumber: 15, seasonNumber: 5, title: "Granite State", imdbRating: "9.6"),
        EpisodeMetric(episodeNumber: 16, seasonNumber: 5, title: "Felina", imdbRating: "9.9")
    ]
}
