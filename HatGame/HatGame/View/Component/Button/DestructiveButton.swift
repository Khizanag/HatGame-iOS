//
//  DestructiveButton.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import SwiftUI

struct DestructiveButton<Label: View>: View {
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
        .tint(DesignBook.Color.Status.error)
    }
}

// MARK: - Convenience initializers
extension DestructiveButton where Label == Text {
    init(title: String, action: @escaping () -> Void) {
        self.action = action
        self.label = { Text(title) }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: DesignBook.Spacing.md) {
        DestructiveButton(title: "Cancel") {}
        DestructiveButton(title: "Delete") {}
        DestructiveButton(action: {}) {
            HStack {
                Image(systemName: "trash")
                Text("Delete Item")
            }
        }
    }
    .padding()
    .background(DesignBook.Color.Background.primary)
}
