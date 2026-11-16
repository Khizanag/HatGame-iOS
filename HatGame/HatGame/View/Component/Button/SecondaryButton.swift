//
//  SecondaryButton.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

struct SecondaryButton<Label: View>: View {
    private let role: ButtonRole?
    private let action: () -> Void
    @ViewBuilder private let label: () -> Label

    init(role: ButtonRole? = nil, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.role = role
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(role: role, action: action) {
            label()
                .font(DesignBook.Font.title3)
                // Footer buttons stack; past this size they would bury the screen.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .padding(8)
                .frame(maxWidth: .infinity)
        }
        .glassButtonStyle()
    }
}

// MARK: - Convenience initializers
extension SecondaryButton where Label == Text {
    init(title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.role = role
        self.action = action
        self.label = { Text(title) }
    }
}

// MARK: - Title + icon initializer
extension SecondaryButton where Label == AnyView {
    init(title: String, icon: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.role = role
        self.action = action
        self.label = {
            AnyView(
                HStack(spacing: DesignBook.Spacing.sm) {
                    Image(systemName: icon)
                    Text(title)
                }
            )
        }
    }
}

#Preview {
    SecondaryButton(title: "Cancel") {}
        .padding()
        .background(DesignBook.Color.Background.primary)
}
