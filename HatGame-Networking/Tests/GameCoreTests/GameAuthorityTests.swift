//
//  GameAuthorityTests.swift
//  GameCoreTests
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import Foundation
@testable import GameCore
import Testing

@Suite("OnlineGameRules authority")
struct GameAuthorityTests {
    /// Host "host" spectates; "exp" is explaining for team A; "other" waits.
    private static let teams = [
        Fixture.team("A", players: ["exp", "mate"]),
        Fixture.team("B", players: ["host", "other"], createdOffset: 1),
    ]

    private static func players(explainerOnline: Bool = true) -> [OnlinePlayer] {
        [
            Fixture.player("exp", team: "A", isConnected: explainerOnline),
            Fixture.player("mate", team: "A", joinedOffset: 1),
            Fixture.player("host", team: "B", joinedOffset: 2),
            Fixture.player("other", team: "B", joinedOffset: 3),
        ]
    }

    private static func state(_ phase: GamePhase) -> OnlineGameState {
        OnlineGameState(
            currentWordId: "w1",
            remainingWordIds: ["w1", "w2"],
            allWordIds: ["w1", "w2"],
            phase: phase,
            activePlayerId: "exp",
            timerStartedAt: phase == .playing ? Fixture.epoch : nil,
            roundDuration: 60
        )
    }

    private static func context(explainerOnline: Bool = true, secondsIn: TimeInterval = 10) -> GameContext {
        GameContext(
            hostId: "host",
            teams: teams,
            players: players(explainerOnline: explainerOnline),
            now: Fixture.epoch.addingTimeInterval(secondsIn)
        )
    }

    private static func allowed(
        _ action: GameAction,
        by playerId: String,
        in phase: GamePhase,
        context: GameContext = context()
    ) -> Bool {
        OnlineGameRules.canPerform(action, by: playerId, state: state(phase), context: context)
    }

    @Test("Only the explainer drives their turn", arguments: [
        GameAction.startTurn, .markGuessed(wordId: "w1"), .skip(wordId: "w1"),
    ])
    func explainerOnlyActions(action: GameAction) {
        #expect(Self.allowed(action, by: "exp", in: .playing))
        #expect(!Self.allowed(action, by: "host", in: .playing))
        #expect(!Self.allowed(action, by: "other", in: .playing))
        #expect(!Self.allowed(action, by: "host", in: .playing, context: Self.context(explainerOnline: false)))
    }

    @Test("The explainer ends only a running turn")
    func explainerEndsRunningTurn() {
        #expect(Self.allowed(.endTurn, by: "exp", in: .playing))
        #expect(!Self.allowed(.endTurn, by: "exp", in: .teamPrep))
    }

    @Test("The host may end a turn only when the explainer is away or stalled")
    func hostEndsStalledTurn() {
        let stalled = Self.context(secondsIn: 60 + OnlineGameRules.stallGraceSeconds + 1)
        let barelyOver = Self.context(secondsIn: 60 + OnlineGameRules.stallGraceSeconds - 1)
        let away = Self.context(explainerOnline: false)

        #expect(!Self.allowed(.endTurn, by: "host", in: .playing))
        #expect(!Self.allowed(.endTurn, by: "host", in: .playing, context: barelyOver))
        #expect(Self.allowed(.endTurn, by: "host", in: .playing, context: stalled))
        #expect(Self.allowed(.endTurn, by: "host", in: .playing, context: away))
        #expect(Self.allowed(.endTurn, by: "host", in: .teamPrep, context: away))
        #expect(!Self.allowed(.endTurn, by: "host", in: .teamPrep))
        #expect(!Self.allowed(.endTurn, by: "other", in: .playing, context: stalled))
    }

    @Test("Turn results advance by the explainer, or the host when the explainer is away")
    func advanceAfterTurnResults() {
        #expect(Self.allowed(.advanceAfterTurnResults, by: "exp", in: .turnResults))
        #expect(!Self.allowed(.advanceAfterTurnResults, by: "host", in: .turnResults))
        #expect(Self.allowed(
            .advanceAfterTurnResults,
            by: "host",
            in: .turnResults,
            context: Self.context(explainerOnline: false)
        ))
        #expect(!Self.allowed(.advanceAfterTurnResults, by: "other", in: .turnResults))
    }

    @Test("Only the host moves between rounds")
    func roundAdvanceIsHostOnly() {
        #expect(Self.allowed(.advanceAfterRoundResults, by: "host", in: .roundResults))
        #expect(!Self.allowed(.advanceAfterRoundResults, by: "exp", in: .roundResults))
        #expect(!Self.allowed(.advanceAfterRoundResults, by: "other", in: .roundResults))
    }

    @Test("Apply checks authority before reducing")
    func applyChecksAuthority() {
        let state = Self.state(.playing)
        let context = Self.context()

        let byExplainer = OnlineGameRules.apply(.markGuessed(wordId: "w1"), by: "exp", to: state, context: context)
        let byOther = OnlineGameRules.apply(.markGuessed(wordId: "w1"), by: "other", to: state, context: context)

        #expect(byExplainer?.getScore(for: "A", in: .first) == 1)
        #expect(byOther == nil)
    }

    @Test("Reduce routes every action to its transition")
    func reduceRoutesEveryAction() {
        func reduced(_ phase: GamePhase, _ action: GameAction) -> OnlineGameState? {
            OnlineGameRules.reduce(Self.state(phase), action, context: Self.context())
        }

        #expect(reduced(.teamPrep, .startTurn)?.phase == .playing)
        #expect(reduced(.playing, .skip(wordId: "w1"))?.currentWordId == "w2")
        #expect(reduced(.playing, .endTurn)?.phase == .turnResults)
        #expect(reduced(.turnResults, .advanceAfterTurnResults)?.phase == .teamPrep)
        #expect(reduced(.roundResults, .advanceAfterRoundResults)?.phase == .teamPrep)
    }
}
