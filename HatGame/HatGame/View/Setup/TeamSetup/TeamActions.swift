//
//  TeamActions.swift
//  HatGame
//

import DesignBook
import SwiftUI

// MARK: - Team actions
extension View {
    /// Everything a team row offers beyond its tap, defined once for every
    /// list that shows a team (constitution article 12): a long press that
    /// previews the team, then Edit, then Delete apart and last; and a swipe
    /// with Delete outermost. Delete always asks first, so it never takes the
    /// destructive role in a swipe, which would remove the row before asking.
    func teamActions(_ team: Team, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        modifier(TeamActionsModifier(team: team, onEdit: onEdit, onDelete: onDelete))
    }
}

private struct TeamActionsModifier: ViewModifier {
    let team: Team
    let onEdit: () -> Void
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(action: onDelete) {
                    Label(localized("teamCard.delete"), systemImage: "trash")
                }
                .tint(DesignBook.Color.Status.errorFill)
                Button(action: onEdit) {
                    Label(localized("teamCard.edit"), systemImage: "pencil")
                }
            }
            .contextMenu {
                Button(action: onEdit) {
                    Label(localized("common.buttons.edit"), systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label(localized("common.buttons.delete"), systemImage: "trash")
                }
            } preview: {
                // Opaque and one fixed width, so the lift never shows a hole
                // or a band of the platter's grey.
                TeamCard(team: team)
                    .frame(width: DesignBook.Size.previewWidth)
                    .padding(DesignBook.Spacing.md)
                    .background(DesignBook.Color.Background.primary)
            }
            .accessibilityActions {
                Button(localized("common.buttons.edit"), action: onEdit)
                Button(localized("common.buttons.delete"), action: onDelete)
            }
    }
}
