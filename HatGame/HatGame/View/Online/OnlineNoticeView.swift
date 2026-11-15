//
//  OnlineNoticeView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// Full-screen terminal state for a multiplayer session that cannot
/// continue — the room closed, or it was written by a newer build. Shared by
/// the online and nearby flows so both end the same way.
struct OnlineNoticeView: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: DesignBook.Spacing.lg) {
            Spacer()
            Image(systemName: symbol)
                .font(DesignBook.IconFont.extraLarge)
                .foregroundStyle(DesignBook.Color.Text.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignBook.Spacing.lg)
            Spacer()
            PrimaryButton(title: actionTitle, icon: "arrow.uturn.backward", action: action)
        }
        .paddingHorizontalDefault()
        .padding(.bottom, DesignBook.Spacing.lg)
        .frame(maxWidth: .infinity)
        .setDefaultBackground()
    }
}

// MARK: - Preview
#Preview {
    OnlineNoticeView(
        symbol: "arrow.down.app",
        title: "Error",
        message: "This room was created by a newer version of Hat Game.",
        actionTitle: "Back to menu",
        action: {}
    )
}
