//
//  SecondaryButton.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

struct SecondaryButton<Label: View>: View {
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
        .buttonStyle(.glass)
    }
}

// MARK: - Convenience initializers
extension SecondaryButton where Label == Text {
    init(title: String, action: @escaping () -> Void) {
        self.action = action
        self.label = { Text(title) }
    }
}

// MARK: - Title + icon initializer
extension SecondaryButton where Label == AnyView {
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

#Preview {
    SecondaryButton(title: "Cancel") {}
        .padding()
        .background(DesignBook.Color.Background.primary)
}
