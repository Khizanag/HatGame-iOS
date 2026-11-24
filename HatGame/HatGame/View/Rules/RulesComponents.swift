//
//  RulesComponents.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// One round's card: its number, its rule, how the example word is explained
/// in it, and what it allows and forbids.
struct RoundRuleCard: View {
    let round: RulesContent.Round

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                header
                example
                VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
                    RuleMark(isAllowed: true, text: round.allowed)
                    RuleMark(isAllowed: false, text: round.notAllowed)
                }
            }
        }
    }
}

// MARK: - Layout
private extension RoundRuleCard {
    var header: some View {
        HStack(alignment: .top, spacing: DesignBook.Spacing.md) {
            Image(systemName: round.systemImage)
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.accent)
                .frame(width: DesignBook.Size.largeIconSize, height: DesignBook.Size.largeIconSize)
                .background(
                    DesignBook.Color.Text.accent.opacity(DesignBook.Opacity.light),
                    in: .rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                Text(localized(round.title))
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .accessibilityAddTraits(.isHeader)
                Text(localized(round.rule))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The same example word, as this round would explain it.
    var example: some View {
        HStack(alignment: .top, spacing: DesignBook.Spacing.sm) {
            Image(systemName: "quote.opening")
                .font(DesignBook.Font.subheadlineSemibold)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .accessibilityHidden(true)
            Text(localized(round.example))
                .font(DesignBook.Font.body)
                .italic()
                .foregroundStyle(DesignBook.Color.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignBook.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            DesignBook.Color.Background.secondary,
            in: .rect(cornerRadius: DesignBook.Size.smallCardCornerRadius, style: .continuous)
        )
    }
}

/// A rule marked allowed or not, by glyph and colour together
/// (constitution article 8), read as "Allowed: …" by VoiceOver.
struct RuleMark: View {
    let isAllowed: Bool
    let text: String.LocalizationValue

    var body: some View {
        Label {
            Text(localized(text))
                .foregroundStyle(DesignBook.Color.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: isAllowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isAllowed ? DesignBook.Color.Status.success : DesignBook.Color.Status.error)
        }
        .font(DesignBook.Font.body)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(localized("rules.mark.a11y \(localized(isAllowed ? "rules.allowed" : "rules.notAllowed")) \(localized(text))")))
    }
}

/// One of the finer points: a question that opens to its answer.
struct RuleQuestion: View {
    let question: RulesContent.Question

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(localized(question.answer))
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DesignBook.Spacing.xs)
        } label: {
            Text(localized(question.question))
                .font(DesignBook.Font.bodySemibold)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .frame(minHeight: DesignBook.Size.touchTargetSize, alignment: .leading)
        }
    }
}
