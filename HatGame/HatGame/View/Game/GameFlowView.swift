//
//  GameFlowView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import Navigation
import SwiftUI

struct GameFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var gameManager = GameManager()
    @State private var gameNavigator = Navigator()

    var body: some View {
        NavigationStack(path: Bindable(gameNavigator).navigationPath) {
            TeamSetupView()
                .navigationDestination(for: AnyPage.self) { page in
                    page.view()
                        .environment(gameManager)
                        .environment(gameNavigator)
                }
        }
        .environment(gameManager)
        .environment(gameNavigator)
        .onReceive(gameNavigator.pleaseDismissViewPublisher) {
            dismiss()
        }
    }
}
