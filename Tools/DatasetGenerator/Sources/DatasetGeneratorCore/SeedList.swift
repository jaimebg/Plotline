import Foundation

/// TMDB series ids baked into the dataset.
///
/// The first 24 were picked by hand to span the shapes the analysis exists to
/// describe — runs that hold their level, runs that fall off, runs that start
/// slow and climb, runs that land their finale — rather than merely the most
/// popular shows. The rest come from TMDB's top-rated, most-popular and
/// most-voted listings, filtered to drop talk shows, news and reality, which
/// have no episode arc to analyse.
///
/// Ordering does not affect the output: `DatasetBuilder` sorts by id.
enum SeedList {
    static let seriesIds: [Int] = [
        1396,  // Breaking Bad
        1398,  // The Sopranos
        1622,  // Supernatural
        1408,  // House
        1668,  // Friends
        1418,  // The Big Bang Theory
        60059,  // Better Call Saul
        1399,  // Game of Thrones
        66732,  // Stranger Things
        63174,  // Lucifer
        1438,  // The Wire
        4614,  // NCIS
        456,  // The Simpsons
        2316,  // The Office
        31917,
        62286,  // Fear the Walking Dead
        1402,  // The Walking Dead
        71712,  // The Good Doctor
        60625,  // Rick and Morty
        82856,  // The Mandalorian
        87108,  // Chernobyl
        76479,  // The Boys
        94605,  // Arcane
        85271,  // WandaVision
        276161,  // Teach You a Lesson
        299167,  // Dutton Ranch
        273240,  // Off Campus
        259837,  // The WONDERfools
        209867,  // Frieren: Beyond Journey's End
        85077,  // The Chosen
        246,  // Avatar: The Last Airbender
        64010,  // Reply 1988
        219246,  // When Life Gives You Tangerines
        37854,  // One Piece
        301507,  // Heated Rivalry
        250307,  // The Pitt
        31911,  // Fullmetal Alchemist: Brotherhood
        200709,  // Weak Hero
        1429,  // Attack on Titan
        138502,  // X-Men '97
        92685,  // The Owl House
        127532,  // Solo Leveling
        42573,  // Slam Dunk
        261145,  // The Amazing Digital Circus
        46298,  // Hunter x Hunter
        42705,  // Fighting Spirit
        131378,  // Adventure Time: Fionna and Cake
        280945,  // Bon Appétit, Your Majesty
        89456,  // Primal
        70785,  // Anne with an E
        68595,  // Planet Earth II
        85937,  // Demon Slayer: Kimetsu no Yaiba
        1430,  // Cosmos: A Personal Voyage
        289219,  // Star Wars: Maul - Shadow Lord
        95557,  // INVINCIBLE
        74313,  // Blue Planet II
        31132,  // Regular Show
        234763,  // The Boy's Word: Blood on the Asphalt
        1044,  // Planet Earth
        72637,  // Once
        3498,  // Wizards of Waverly Place
        62741,  // Kamisama Kiss
        13916,  // Death Note
        259666,  // No One Will Miss Us
        3854,  // The Spectacular Spider-Man
        271607,  // The Fragrant Flower Blooms with Dignity
        57706,  // Ranma ½
        40075,  // Gravity Falls
        67915,  // Guardian: The Lonely and Great God
        220542,  // The Apothecary Diaries
        60863,  // Haikyu!!
        35790,  // Cardcaptor Sakura
        100,  // I Am Not an Animal
        43,  // 31 Minutes
        62914,  // Merlí
        80040,  // Desafío Champions Sendokai
        65930,  // My Hero Academia
        85349,  // Amphibia
        79141,  // Scissor Seven
        4613,  // Band of Brothers
        21650,  // I'm in the Band
        119464,  // Navillera
        82728,  // Bluey
        37419,  // Zoids: Chaotic Century
        135157,  // Alchemy of Souls
        46896,  // The Originals
        95479,  // JUJUTSU KAISEN
        2098,  // Batman: The Animated Series
        95269,  // Toilet-Bound Hanako-kun
        124834,  // Heartstopper
        230923,  // Lovely Runner
        36189,  // Boris
        31356,  // Big Time Rush
        61663,  // Your Lie in April
        35610,  // InuYasha
        98214,  // Villainous
        61617,  // Over the Garden Wall
        80564,  // Banana Fish
        45790,  // JoJo's Bizarre Adventure
        890,  // Neon Genesis Evangelion
        97186,  // Love, Victor
        94954,  // Hazbin Hotel
        76662,  // My Mister
        2192,  // Robotech
        9302,  // Digimon Tamers
        79744,  // The Rookie
        73488,  // Les Contes de la rue Broca
        12313,  // Shadow Hunter
        65844,  // KONOSUBA - God's blessing on this wonderful 
        86031,  // Dr. STONE
        240411,  // Dan Da Dan
        83121,  // Kaguya-sama: Love Is War
        37606,  // The Amazing World of Gumball
        32118,  // Generator Rex
        207250,  // The Dangers in My Heart
        9160,  // Candy Candy
        259909,  // Dexter: Resurrection
        31910,  // Naruto Shippūden
        88040,  // given
        61222,  // BoJack Horseman
        210733,  // Hidden Love
        83880,  // Our Planet
        60574,  // Peaky Blinders
        94796,  // Crash Landing on You
        83100,  // Dororo
        256721,  // Gachiakuta
        28136,  // Rurouni Kenshin
        30981,  // Monster
        126506,  // Smiling Friends
        114410,  // Chainsaw Man
        90447,  // Hotel Del Luna
        82739,  // Rascal Does Not Dream of Bunny Girl Senpai
        76121,  // DARLING in the FRANXX
        108291,  // Snowdrop
        117376,  // Vincenzo
        3793,  // Invader ZIM
        67389,  // Golden Time
        68129,  // Yuri!!! on Ice
        120089,  // SPY x FAMILY
        83639,  // Girl from Nowhere
        73223,  // Black Clover
        19885,  // Sherlock
        15260,  // Adventure Time
        126485,  // Moving
        89901,  // Dickinson
        88803,  // Vinland Saga
        125910,  // Young Royals
        110070,  // Horimiya
        58474,  // Cosmos
        77721,  // Real Girl
        6357,  // The Twilight Zone
        75214,  // Violet Evergarden
        127529,  // Bloodhounds
        96462,  // It's Okay to Not Be Okay
        67075,  // Mob Psycho 100
        45950,  // High School DxD
        68349,  // Weightlifting Fairy Kim Bok-joo
        11466,  // Kaamelott
        124364,  // FROM
        66433,  // Scarlet Heart: Ryeo
        229480,  // No Gain No Love
        108261,  // Mr. Queen
        40143,  // Shaman King
        30991,  // Cowboy Bebop
        225180,  // BLUE EYE SAMURAI
        42444,  // Saint Seiya
        35935,  // Berserk
        56568,  // NANA
        1600,  // Ned's Declassified School Survival Guide
        197067,  // Extraordinary Attorney Woo
        79818,  // Meteor Garden
        5920,  // The Mentalist
        233643,  // Secret Mission - Undercover Agents Never Bac
        94997,  // House of the Dragon
        2734,  // Law & Order: Special Victims Unit
        1416,  // Grey's Anatomy
        125988,  // Silo
        65334,  // Miraculous: Tales of Ladybug & Cat Noir
        549,  // Law & Order
        13945,  // Gute Zeiten, schlechte Zeiten
    ]
}
