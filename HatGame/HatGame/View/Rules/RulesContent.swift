//
//  RulesContent.swift
//  HatGame
//

import SwiftUI

/// The rules as data, so the page lays them out and the words live in the
/// String Catalog. Mirrors `docs/` (overview, rounds, turn, scoring).
enum RulesContent {
    struct Fact: Identifiable {
        let value: String
        let caption: String.LocalizationValue
        var id: String { "\(caption)" }
    }

    struct Round: Identifiable {
        let number: Int
        let systemImage: String
        let title: String.LocalizationValue
        let rule: String.LocalizationValue
        let example: String.LocalizationValue
        let allowed: String.LocalizationValue
        let notAllowed: String.LocalizationValue
        var id: Int { number }
    }

    struct Step: Identifiable {
        let systemImage: String
        let text: String.LocalizationValue
        var id: String { systemImage }
    }

    struct Question: Identifiable {
        let question: String.LocalizationValue
        let answer: String.LocalizationValue
        var id: String { "\(question)" }
    }

    struct Mode: Identifiable {
        let systemImage: String
        let title: String.LocalizationValue
        let detail: String.LocalizationValue
        var id: String { systemImage }
    }

    /// The defaults a new game starts from, as this device has them set.
    static var facts: [Fact] {
        let defaults = AppConfiguration.shared.gameDefaults
        return [
            Fact(value: "2–6", caption: "rules.glance.teams"),
            Fact(value: "\(defaults.wordsPerPlayer)", caption: "rules.glance.words"),
            Fact(value: "\(defaults.roundDuration)", caption: "rules.glance.seconds"),
            Fact(value: "3", caption: "rules.glance.rounds"),
        ]
    }

    static let rounds: [Round] = [
        Round(
            number: 1,
            systemImage: "text.bubble.fill",
            title: "round.first.title",
            rule: "round.first.description",
            example: "rules.round1.example",
            allowed: "rules.round1.allowed",
            notAllowed: "rules.round1.notAllowed"
        ),
        Round(
            number: 2,
            systemImage: "quote.bubble.fill",
            title: "round.second.title",
            rule: "round.second.description",
            example: "rules.round2.example",
            allowed: "rules.round2.allowed",
            notAllowed: "rules.round2.notAllowed"
        ),
        Round(
            number: 3,
            systemImage: "figure.wave",
            title: "round.third.title",
            rule: "round.third.description",
            example: "rules.round3.example",
            allowed: "rules.round3.allowed",
            notAllowed: "rules.round3.notAllowed"
        ),
    ]

    static let turnSteps: [Step] = [
        Step(systemImage: "person.wave.2.fill", text: "rules.turn.explainer"),
        Step(systemImage: "checkmark.circle.fill", text: "rules.turn.gotIt"),
        Step(systemImage: "arrow.uturn.forward", text: "rules.turn.skip"),
        Step(systemImage: "timer", text: "rules.turn.timeUp"),
        Step(systemImage: "arrow.trianglehead.2.clockwise", text: "rules.turn.hatEmpty"),
    ]

    static let fairPlay: [String.LocalizationValue] = [
        "rules.fairPlay.spell",
        "rules.fairPlay.rhyme",
        "rules.fairPlay.translate",
        "rules.fairPlay.point",
    ]

    static let questions: [Question] = [
        Question(question: "rules.deep.explainer.q", answer: "rules.deep.explainer.a"),
        Question(question: "rules.deep.carryOver.q", answer: "rules.deep.carryOver.a"),
        Question(question: "rules.deep.skip.q", answer: "rules.deep.skip.a"),
        Question(question: "rules.deep.negative.q", answer: "rules.deep.negative.a"),
        Question(question: "rules.deep.giveUp.q", answer: "rules.deep.giveUp.a"),
        Question(question: "rules.deep.pause.q", answer: "rules.deep.pause.a"),
        Question(question: "rules.deep.again.q", answer: "rules.deep.again.a"),
    ]

    static let modes: [Mode] = [
        Mode(systemImage: "person.2.fill", title: "home.localGame", detail: "rules.modes.passAndPlay"),
        Mode(systemImage: "dot.radiowaves.left.and.right", title: "home.nearbyGame", detail: "rules.modes.nearby"),
        Mode(systemImage: "globe", title: "home.onlineGame", detail: "rules.modes.online"),
    ]
}
