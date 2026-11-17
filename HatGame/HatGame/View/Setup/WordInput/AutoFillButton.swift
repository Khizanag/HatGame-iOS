//
//  AutoFillButton.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 09.06.26.
//

import DesignBook
import SwiftUI

/// Word-input call-to-action that fills the remaining words automatically.
struct AutoFillButton: View {
    let isAutoFilling: Bool
    let isDisabled: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Label {
                Text(localized(isAutoFilling ? "wordInput.autoFill.thinking" : "wordInput.autoFill"))
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: isAutoFilling ? "sparkles" : "wand.and.stars")
                    .fontWeight(.semibold)
                    .symbolEffect(.pulse, options: .repeating, isActive: isAutoFilling && !reduceMotion)
            }
            .font(DesignBook.Font.body)
            .foregroundStyle(DesignBook.Color.Text.accent)
            .frame(maxWidth: .infinity)
        }
        .glassButtonStyle()
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .disabled(isDisabled)
    }
}
