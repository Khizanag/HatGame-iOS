//
//  View+HatField.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 16.11.26.
//

import DesignBook
import SwiftUI

// MARK: - Field options
/// Input traits for `hatFieldStyle`, spelled once for every platform; the
/// ones a platform lacks (macOS has no software keyboard) are ignored there.
enum HatFieldKeyboard {
    case standard
    /// Latin letters and digits only, for codes.
    case asciiCapable
}

enum HatFieldContentType {
    /// A person's first name, so the system can offer the user's own.
    case givenName
}

enum HatFieldCapitalization {
    case never
    case words
    case sentences
    case characters
}

// MARK: - Field style
extension View {
    /// The app's text field: a padded, rounded box at least 44 pt tall in
    /// which a tap anywhere — not just on the text line — focuses the field
    /// (HIG text-fields.md; accessibility.md hit targets). Apply it to a
    /// `TextField`, keeping `.focused(…)` on the field as usual.
    ///
    /// - Parameters:
    ///   - label: What the field is for, read by VoiceOver instead of the
    ///     placeholder ("Team Name", not "Enter team name").
    ///   - focus: Moves focus to this field; runs when the box's padding is
    ///     tapped, e.g. `{ focusedField = .teamName }`.
    ///   - capitalization: `nil` keeps the system default (sentences).
    func hatFieldStyle(
        label: String,
        font: Font = DesignBook.Font.body,
        submitLabel: SubmitLabel = .return,
        keyboard: HatFieldKeyboard = .standard,
        contentType: HatFieldContentType? = nil,
        disablesAutocorrection: Bool = false,
        capitalization: HatFieldCapitalization? = nil,
        focus: @escaping () -> Void
    ) -> some View {
        textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(DesignBook.Color.Text.primary)
            .submitLabel(submitLabel)
            .autocorrectionDisabled(disablesAutocorrection)
            .hatKeyboard(keyboard)
            .hatContentType(contentType)
            .hatCapitalization(capitalization)
            .accessibilityLabel(Text(label))
            .padding(DesignBook.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: DesignBook.Size.touchTargetSize, alignment: .leading)
            .background(
                DesignBook.Color.Background.secondary,
                in: .rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous)
            )
            .contentShape(.rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous))
            .onTapGesture(perform: focus)
    }
}

// MARK: - Platform traits
private extension View {
    @ViewBuilder
    func hatKeyboard(_ keyboard: HatFieldKeyboard) -> some View {
        #if os(macOS)
        self
        #else
        switch keyboard {
        case .standard: self
        case .asciiCapable: keyboardType(.asciiCapable)
        }
        #endif
    }

    @ViewBuilder
    func hatContentType(_ contentType: HatFieldContentType?) -> some View {
        switch contentType {
        case .givenName:
            textContentType(.givenName)
        case nil:
            self
        }
    }

    @ViewBuilder
    func hatCapitalization(_ capitalization: HatFieldCapitalization?) -> some View {
        #if os(macOS)
        self
        #else
        switch capitalization {
        case .never: textInputAutocapitalization(.never)
        case .words: textInputAutocapitalization(.words)
        case .sentences: textInputAutocapitalization(.sentences)
        case .characters: textInputAutocapitalization(.characters)
        case nil: self
        }
        #endif
    }
}
