//
//  TeamEditView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import Navigation
import SwiftUI

struct TeamEditView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(Navigator.self) private var navigator

    let team: Team

    var body: some View {
        TeamFormView(
            team: team,
            onPrimaryAction: { updatedTeam in
                gameManager.updateTeam(updatedTeam)
            }
        )
        .environment(gameManager)
        .environment(navigator)
        .setDefaultBackground()
        .presentationDetents([.large])
    }
}

// MARK: - Sheet
/// Edit Team in its own navigation stack, as the flow presents it.
struct EditTeamSheet: View {
    let team: Team

    var body: some View {
        NavigationStack {
            TeamEditView(team: team)
        }
    }
}
