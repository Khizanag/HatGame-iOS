//
//  TeamNameSuggestions.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 20.05.26.
//

import Foundation

/// Curated, party-friendly team-name suggestions used as inspiration in the team form.
/// Tone: playful, punny, and on-theme for a word-guessing game. Avoids offensive content.
/// Each language has its own list; puns don't translate.
nonisolated enum TeamNameSuggestions {
    static func random(count: Int = 4, in language: WordLanguage) -> [String] {
        Array(all(in: language).shuffled().prefix(count))
    }

    static func all(in language: WordLanguage) -> [String] {
        switch language {
        case .english: english
        case .georgian: georgian
        }
    }

    static let english: [String] = [
        // Word / hat / game-themed
        "The Hat Trick",
        "Word Wizards",
        "Mind Readers",
        "Charade Chasers",
        "Word Nerds",
        "Hat Heads",
        "Brain Storm",
        "The Mime Crew",
        "Guess Who",
        "Wordsmiths",

        // Punny
        "Inglorious Speakers",
        "Quiztopher Walken",
        "Smarty Pants",
        "The Win Doors",
        "The Hat Pack",
        "Sherlock Homies",
        "Hocus Focus",
        "Quick Wits",
        "Vocab Vandals",
        "Pun-ic War",

        // Animal-themed
        "Howling Wolves",
        "Quokka Stars",
        "Wise Owls",
        "Fierce Foxes",
        "Penguin Posse",
        "Roaring Lions",
        "Bunny Brains",
        "Otter Geniuses",
        "Hippo Squad",
        "Koala-fied",

        // Food-themed
        "Spice Squad",
        "Pizza Slayers",
        "Taco 'bout Words",
        "Pretzel Logic",
        "Hot Sauce",
        "Hummus Heroes",
        "Donut Worry",
        "Soup Stars",
        "Mango Mob",
        "Sushi Roll Call",

        // Pop-culture nods
        "Stranger Strings",
        "Game of Phrases",
        "Friends with Words",
        "The Office Party",
        "Breaking Word",
        "The Hat-fields",
        "Lord of the Phrases",
        "Mission Impossi-word",
        "Avengers Assemble",
        "Star Words",

        // Tech / modern
        "Ctrl+Alt+Defeat",
        "The Algorithm",
        "Cache Money",
        "Beta Testers",
        "Pixel Perfect",
        "The Update",
        "Cookie Clickers",
        "Glitch Mob",
        "Wi-Fi Wonders",
        "Bit by Bit",

        // General funny
        "The Underdogs",
        "Bad Spellers Untie",
        "The Procrastinators",
        "Highly Unmotivated",
        "Couch Crusaders",
        "The Nappers",
        "Tactical Bananas",
        "Chaos Coordinators",
        "The Dream Team",
        "Plan B",

        // Sports parody
        "Slow Pokes",
        "Bench Warmers",
        "Yardstick Yetis",
        "Casual Friday",
        "Last Picks",
        "Marathon Sitters",
        "Athlete's Foot Note",
        "Time Outs",
        "Half-Time Heroes",
        "Game Over",

        // Tongue-in-cheek
        "We're With Smarty",
        "Last Place Champions",
        "Loose Cannons",
        "Backseat Drivers",
        "Comically Late",
        "Punday Funday",
        "Question Marks",
        "What Knots",
        "We Got This (Maybe)",
        "The Probably's",

        // Random brilliance
        "Loose Lips",
        "Word Vomit",
        "Hat in Hand",
        "Whisper Whisperers",
        "Charade Charioteers",
        "Guess-tastic",
        "Word Slingers",
        "Phrase Phantoms",
        "Mystery Mob",
        "Brain Trusts",
    ]

    static let georgian: [String] = [
        // სიტყვები და ქუდი
        "ქუდის ოსტატები",
        "სიტყვის ჯადოქრები",
        "ფიქრის მკითხველები",
        "ჯადოსნური ქუდი",
        "ქუდში კურდღელი",
        "სიტყვის მჭედლები",
        "ტვინის შტორმი",
        "მიმების გუნდი",
        "გამოიცანი ვინ",
        "ენაწყლიანები",

        // ცხოველები
        "ბრძენი ბუები",
        "ცბიერი მელიები",
        "მოღრიალე ლომები",
        "პინგვინების ბანდა",
        "ჰიპოპოტამების რაზმი",
        "ჭკვიანი წავები",
        "მთის არწივები",
        "თბილისის ვეფხვები",
        "კურდღლის ტვინები",
        "მგლების ხროვა",

        // სუფრა
        "ხაჭაპურის გმირები",
        "ხინკლის ბრიგადა",
        "ჩურჩხელები",
        "ტყემლის ძალა",
        "ლობიანის ლეგიონი",
        "აჯიკის ცეცხლი",
        "საფერავის საზოგადოება",
        "სუფრის ოსტატები",
        "თამადები",
        "მწვადის მოყვარულები",

        // ტექნოლოგია
        "ალგორითმი",
        "ბეტა ტესტერები",
        "პიქსელები",
        "ვაიფაის ვარსკვლავები",
        "ბიტ-ბიტად",

        // იუმორით
        "აუტსაიდერები",
        "ბოლო წუთის გმირები",
        "დივნის რაინდები",
        "ძილისგუდები",
        "ქაოსის კოორდინატორები",
        "ოცნების გუნდი",
        "გეგმა ბ",
        "სათადარიგოები",
        "ტაიმაუტი",
        "ბოლო ადგილის ჩემპიონები",
        "იქნებ მოვიგოთ",
        "ჩვენ შევძლებთ",
        "კითხვის ნიშნები",
        "მოლაყბეები",
        "ჭორიკანები",

        // სხვადასხვა
        "ჩურჩულის ოსტატები",
        "ჟესტების მეფეები",
        "უსიტყვოები",
        "სწრაფი ენები",
        "იდუმალი ბრბო",
        "ცისარტყელა",
        "კომეტები",
        "ვარსკვლავთცვენა",
        "ჭკვიანი თავები",
        "სწრაფი გონება",
    ]
}

// MARK: - App language
extension TeamNameSuggestions {
    /// Suggestions in the app's current language.
    static func random(count: Int = 4) -> [String] {
        random(count: count, in: WordDatabase.currentLanguage)
    }
}
