//
//  OnlineGameFlowView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import Navigation
import Networking
import SwiftUI

/// Single-screen controller pushed onto the OnlineFlow navigation stack once
/// a player has joined or created a room. Routes through the shared
/// `MultiplayerSessionView`, re-using the GameSyncManager already in the
/// environment from `OnlineFlowView`.
struct OnlineGameFlowView: View {
    @Environment(RoomManager.self) private var roomManager
    @Environment(Navigator.self) private var navigator

    /// A closed room wins; otherwise any part of the room this build cannot
    /// read makes it unsupported.
    private var terminal: MultiplayerSessionView.Terminal? {
        switch roomManager.connectionState {
        case .closed: .closed
        case .unsupported: .unsupported
        case .idle, .joining, .live: roomManager.room?.isSupported == false ? .unsupported : nil
        }
    }

    var body: some View {
        MultiplayerSessionView(
            terminal: terminal,
            runsSetup: true,
            canStartEarly: roomManager.canActAsHost,
            connecting: MultiplayerSessionView.Connecting(
                symbol: "wifi",
                title: localized("online.session.joining"),
                hint: localized("online.session.joiningHint")
            ),
            closedNotice: closedNotice,
            unsupportedNotice: unsupportedNotice
        )
    }
}

// MARK: - Notices
private extension OnlineGameFlowView {
    /// The host closed the room while this device was in it.
    var closedNotice: OnlineNoticeView {
        OnlineNoticeView(
            symbol: "door.left.hand.closed",
            title: localized("online.session.closed"),
            message: localized("online.session.closed.message"),
            actionTitle: localized("local.session.hostLost.action"),
            action: leaveToMenu
        )
    }

    /// A newer build wrote a status, phase, or round this one can't read.
    var unsupportedNotice: OnlineNoticeView {
        OnlineNoticeView(
            symbol: "arrow.down.app",
            title: localized("online.unsupported.title"),
            message: localized("online.unsupported.message"),
            actionTitle: localized("local.session.hostLost.action"),
            action: leaveToMenu
        )
    }

    /// Detaches without writing — the room is gone or unreadable — and
    /// returns to the online menu.
    func leaveToMenu() {
        Task {
            try? await roomManager.leaveRoom()
            navigator.popToRoot()
        }
    }
}
