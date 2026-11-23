//
//  AddTeamView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import SwiftUI

struct AddTeamView: View {
    let onTeamCreate: (Team) -> Void

    init(onTeamCreate: @escaping (Team) -> Void) {
        self.onTeamCreate = onTeamCreate
    }

    var body: some View {
        TeamFormView(
            team: nil,
            onPrimaryAction: onTeamCreate
        )
    }
}

// MARK: - Sheet
/// Add Team in its own navigation stack, as the flow presents it.
struct AddTeamSheet: View {
    let onCreate: (Team) -> Void

    var body: some View {
        NavigationStack {
            AddTeamView(onTeamCreate: onCreate)
        }
    }
}
