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
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        }
        .actionBar {
            PrimaryButton(title: actionTitle, icon: "arrow.uturn.backward", action: action)
                .paddingHorizontalDefault()
                .padding(.top, DesignBook.Spacing.lg)
                .padding(.bottom, DesignBook.Spacing.lg)
        }
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
