//
//  OnlineWaitingView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import DesignBook
import Networking
import SwiftUI

/// Shown to players who've finished submitting their words while we wait
/// for the rest. Lists every player so the user can see exactly who is
/// still typing and who has handed in their pile.
struct OnlineWaitingView: View {
    @Environment(RoomManager.self) private var roomManager

    let message: String

    private var players: [OnlinePlayer] { roomManager.room?.players ?? [] }
    private var submittedCount: Int { players.filter(\.hasSubmittedWords).count }
    private var totalCount: Int { players.count }

    var body: some View {
        VStack(spacing: DesignBook.Spacing.xl) {
            Spacer()
            hero
            playerStatusCard
            Spacer()
        }
        .paddingHorizontalDefault()
        .padding(.bottom, DesignBook.Spacing.lg)
        .setDefaultBackground()
    }
}

// MARK: - Subviews
private extension OnlineWaitingView {
    var hero: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignBook.Gradient.primary)
                    .frame(width: 120, height: 120)
                    .blur(radius: 28)
                    .opacity(0.55)
                Circle()
                    .fill(DesignBook.Color.Background.card)
                    .frame(width: 96, height: 96)
                    .shadow(.medium)
                Image(systemName: "hourglass")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(DesignBook.Gradient.primary)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .accessibilityHidden(true)

            Text(message)
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)

            Text(verbatim: "\(submittedCount)/\(totalCount)")
                .font(DesignBook.Font.headline)
                .foregroundStyle(DesignBook.Color.Text.accent)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    var playerStatusCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "person.3.fill")
                        .font(DesignBook.IconFont.medium)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                    Text(localized("online.playersStatus"))
                        .font(DesignBook.Font.captionBold)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }

                VStack(spacing: DesignBook.Spacing.sm) {
                    ForEach(players, id: \.id) { player in
                        playerRow(player)
                    }
                }
            }
        }
    }

    func playerRow(_ player: OnlinePlayer) -> some View {
        let isDone = player.hasSubmittedWords
        return HStack(spacing: DesignBook.Spacing.md) {
            ZStack {
                Circle()
                    .fill(isDone
                        ? DesignBook.Color.Status.success.opacity(0.20)
                        : DesignBook.Color.Background.secondary)
                    .frame(width: 36, height: 36)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(DesignBook.Font.captionBold)
                        .foregroundStyle(DesignBook.Color.Status.success)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignBook.Color.Text.accent))
                        .scaleEffect(0.7)
                }
            }
            Text(player.name)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)
            if player.id == roomManager.currentPlayerId {
                RoleBadge(style: .you)
            }
            Spacer()
            Text(isDone ? "online.submitted" : "online.typing")
                .font(DesignBook.Font.caption)
                .foregroundStyle(isDone ? DesignBook.Color.Status.success : DesignBook.Color.Text.tertiary)
        }
        .padding(.vertical, DesignBook.Spacing.xs)
    }
}

#Preview {
    OnlineWaitingView(message: "Waiting for other players...")
        .environment(RoomManager())
}
