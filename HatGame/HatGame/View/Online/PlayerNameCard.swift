//
//  PlayerNameCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

/// The "your name" card at the top of every online and nearby form.
struct PlayerNameCard<Field: Hashable>: View {
    let title: String
    let placeholder: String
    @Binding var name: String
    let focus: FocusState<Field?>.Binding
    let field: Field
    var submitLabel: SubmitLabel = .done
    let onSubmit: () -> Void

    private var isNameMissing: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: "person.fill")
                        .font(DesignBook.IconFont.medium)
                        .foregroundStyle(DesignBook.Color.Text.accent)
                    Text(title)
                        .font(DesignBook.Font.subheadlineSemibold)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }
                TextField(placeholder, text: $name)
                    .textFieldStyle(.plain)
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .padding(DesignBook.Spacing.md)
                    .background(DesignBook.Color.Background.secondary)
                    .clipShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
                    .focused(focus, equals: field)
                    .submitLabel(submitLabel)
                    .onSubmit(onSubmit)
                if isNameMissing {
                    Label(localized("multiplayer.nameRequired"), systemImage: "info.circle")
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.tertiary)
                        .accessibilityIdentifier("playerName.requiredHint")
                }
            }
        }
    }
}

// MARK: - Storage
/// The name last typed into any multiplayer form, remembered so the next
/// form starts filled in. Forms bind to it with `@AppStorage(PlayerNameStorage.key)`.
enum PlayerNameStorage {
    static let key = "HatGame.lastPlayerName"

    /// The remembered name, trimmed; empty when none was saved.
    static var savedName: String {
        (UserDefaults.standard.string(forKey: key) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
