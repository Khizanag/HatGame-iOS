//
//  LocalSessionView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import Navigation
import Networking
import SwiftUI

/// Phase-switching container for an active nearby-play session. Routes
/// through the shared `MultiplayerSessionView`, like `OnlineGameFlowView`,
/// but the underlying `RoomManager` is a `LocalRoomManager` backed by
/// Multipeer, and a guest is told when the host's device drops.
struct LocalSessionView: View {
    @Environment(LocalRoomManager.self) private var localRoomManager
    @Environment(Navigator.self) private var navigator

    @State private var showHostLostAlert: Bool = false
    @State private var hasBeenConnected: Bool = false

    /// A version mismatch wins over a refusal: either device may be the
    /// older one, and the host cannot be joined until both match.
    private var terminal: MultiplayerSessionView.Terminal? {
        if localRoomManager.connectionState == .unsupported || localRoomManager.room?.isSupported == false {
            return .unsupported
        }
        return localRoomManager.connectionState == .closed ? .closed : nil
    }

    var body: some View {
        MultiplayerSessionView(
            terminal: terminal,
            // Only the host's device runs setup on nearby: it holds the room.
            runsSetup: localRoomManager.isHostInternal,
            canStartEarly: localRoomManager.isHostInternal,
            connecting: MultiplayerSessionView.Connecting(
                symbol: "antenna.radiowaves.left.and.right",
                title: localized("local.session.connecting"),
                hint: localized("local.session.connectingHint")
            ),
            closedNotice: closedNotice,
            unsupportedNotice: unsupportedNotice
        )
        .onChange(of: localRoomManager.isConnected) { _, isConnected in
            if isConnected {
                hasBeenConnected = true
            } else if hasBeenConnected, !localRoomManager.isHostInternal {
                showHostLostAlert = true
            }
        }
        .alert(localized("local.session.hostLost"), isPresented: $showHostLostAlert) {
            Button(localized("local.session.hostLost.action"), role: .cancel, action: leaveSession)
        } message: {
            Text(localized("local.session.hostLost.message"))
        }
    }
}

// MARK: - Notices
private extension LocalSessionView {
    /// This device and the host run different protocol or data versions;
    /// either one may be the older build.
    var unsupportedNotice: OnlineNoticeView {
        OnlineNoticeView(
            symbol: "arrow.down.app",
            title: localized("local.session.versionMismatch.title"),
            message: localized("local.session.versionMismatch"),
            actionTitle: localized("local.session.hostLost.action"),
            action: leaveSession
        )
    }

    /// The host refused this device, or never answered its hello.
    var closedNotice: OnlineNoticeView {
        OnlineNoticeView(
            symbol: "door.left.hand.closed",
            title: localized("local.session.hostLost"),
            message: localRoomManager.rejection.map { NetworkErrorMessage.message(for: $0) }
                ?? localized("local.session.hostLost.message"),
            actionTitle: localized("local.session.hostLost.action"),
            action: leaveSession
        )
    }

    func leaveSession() {
        Task { try? await localRoomManager.leaveRoom() }
        navigator.popToRoot()
    }
}
