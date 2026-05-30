//
//  PrimaryButton.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

struct PrimaryButton<Label: View>: View {
    private let action: () -> Void
    @ViewBuilder private let label: () -> Label

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
                .font(DesignBook.Font.headline)
                .padding(8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
    }
}

// MARK: - Convenience initializers
extension PrimaryButton where Label == Text {
    init(title: String, action: @escaping () -> Void) {
        self.action = action
        self.label = { Text(title) }
    }
}

// MARK: - Title + icon initializer
extension PrimaryButton where Label == AnyView {
    init(title: String, icon: String, action: @escaping () -> Void) {
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

// MARK: - Preview
#Preview {
    PrimaryButton(title: "Start Game") {}
        .padding()
        .background(DesignBook.Color.Background.primary)
}
