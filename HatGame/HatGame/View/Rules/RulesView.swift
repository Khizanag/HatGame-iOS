//
//  RulesView.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// The full rules, opened from Home's toolbar: what the game is, the three
/// rounds told through one example word, a turn, scoring, fair play, the
/// finer points as questions to open, and the ways to play. A page to read,
/// so it sits on the opaque ground (constitution article 2).
struct RulesView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.xxl) {
                hero
                glanceSection
                roundsSection
                turnSection
                scoringSection
                fairPlaySection
                questionsSection
                modesSection
            }
            .paddingHorizontalDefault()
            .padding(.vertical, DesignBook.Spacing.lg)
        }
        .navigationTitle(localized("home.howToPlay.title"))
        .setDefaultStyle()
        .accessibilityIdentifier("rules.page")
    }
}

// MARK: - Hero and facts
private extension RulesView {
    var hero: some View {
        VStack(spacing: DesignBook.Spacing.xl) {
            ZStack {
                HeroGlow(.setup)
                Circle()
                    .fill(DesignBook.Color.Background.card)
                    .frame(width: DesignBook.Size.heroDiscSmall, height: DesignBook.Size.heroDiscSmall)
                    .shadow(.medium)
                Text(verbatim: "🎩")
                    .font(DesignBook.IconFont.display)
            }
            .accessibilityHidden(true)
            .decorativeHeroSizing()

            Text(localized("rules.hero.subtitle"))
                .font(DesignBook.Font.title3)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    var glanceSection: some View {
        let facts = RulesContent.facts
        return section("rules.glance.title") {
            VStack(spacing: DesignBook.Spacing.md) {
                ForEach(Array(stride(from: 0, to: facts.count, by: 2)), id: \.self) { start in
                    glanceRow {
                        ForEach(facts[start ..< min(start + 2, facts.count)]) { fact in
                            factCard(fact)
                        }
                    }
                }
            }
        }
    }

    /// Two facts a row; stacked at accessibility sizes, where half a row is
    /// too narrow for the captions.
    func glanceRow(@ViewBuilder content: () -> some View) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DesignBook.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignBook.Spacing.md))
        return layout(content)
            .fixedSize(horizontal: false, vertical: true)
    }

    func factCard(_ fact: RulesContent.Fact) -> some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                Text(verbatim: fact.value)
                    .font(DesignBook.Font.title1)
                    .monospacedDigit()
                    .foregroundStyle(DesignBook.Color.Text.primary)
                Text(localized(fact.caption))
                    .font(DesignBook.Font.subheadline)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Rounds
private extension RulesView {
    var roundsSection: some View {
        section("rules.rounds.title") {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                Text(localized("rules.rounds.intro"))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Label(localized("rules.example.word"), systemImage: "lightbulb.fill")
                    .font(DesignBook.Font.subheadlineSemibold)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                ForEach(RulesContent.rounds) { round in
                    RoundRuleCard(round: round)
                }
            }
        }
    }
}

// MARK: - Turn, scoring, fair play
private extension RulesView {
    var turnSection: some View {
        section("rules.turn.title") {
            GameCard {
                VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                    ForEach(Array(RulesContent.turnSteps.enumerated()), id: \.element.id) { index, step in
                        InstructionRow(index: index + 1, icon: step.systemImage, text: localized(step.text))
                    }
                }
            }
        }
    }

    var scoringSection: some View {
        section("rules.scoring.title") {
            GameCard {
                VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                    scoreLine(value: "+1", systemImage: "checkmark.circle.fill",
                              color: DesignBook.Color.Status.success, caption: "rules.scoring.guess")
                    scoreLine(value: "−1", systemImage: "arrow.uturn.forward.circle.fill",
                              color: DesignBook.Color.Status.warning, caption: "rules.scoring.skip")
                    Divider()
                    note("rules.scoring.repeat", systemImage: "arrow.trianglehead.2.clockwise")
                    note("rules.scoring.win", systemImage: "trophy.fill")
                }
            }
        }
    }

    func scoreLine(value: String, systemImage: String, color: Color, caption: String.LocalizationValue) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignBook.Spacing.md) {
            Label {
                Text(verbatim: value)
                    .monospacedDigit()
            } icon: {
                Image(systemName: systemImage)
            }
            .font(DesignBook.Font.title2)
            .foregroundStyle(color)
            Text(localized(caption))
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    func note(_ text: String.LocalizationValue, systemImage: String) -> some View {
        Label {
            Text(localized(text))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(DesignBook.Font.body)
        .foregroundStyle(DesignBook.Color.Text.primary)
    }

    var fairPlaySection: some View {
        section("rules.fairPlay.title") {
            GameCard {
                VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                    Text(localized("rules.fairPlay.intro"))
                        .font(DesignBook.Font.subheadline)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                    ForEach(RulesContent.fairPlay.indices, id: \.self) { index in
                        RuleMark(isAllowed: false, text: RulesContent.fairPlay[index])
                    }
                    Divider()
                    RuleMark(isAllowed: true, text: "rules.fairPlay.guessers")
                }
            }
        }
    }
}

// MARK: - Questions and modes
private extension RulesView {
    var questionsSection: some View {
        section("rules.deep.title") {
            GameCard {
                VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
                    ForEach(Array(RulesContent.questions.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider() }
                        RuleQuestion(question: item)
                    }
                }
            }
        }
    }

    var modesSection: some View {
        section("rules.modes.title") {
            GameCard {
                VStack(alignment: .leading, spacing: DesignBook.Spacing.lg) {
                    ForEach(RulesContent.modes) { mode in
                        HStack(alignment: .top, spacing: DesignBook.Spacing.md) {
                            Image(systemName: mode.systemImage)
                                .font(DesignBook.Font.title3)
                                .foregroundStyle(DesignBook.Color.Text.primary)
                                .frame(minWidth: DesignBook.Size.iconSize)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: DesignBook.Spacing.xxs) {
                                Text(localized(mode.title))
                                    .font(DesignBook.Font.bodySemibold)
                                    .foregroundStyle(DesignBook.Color.Text.primary)
                                Text(localized(mode.detail))
                                    .font(DesignBook.Font.subheadline)
                                    .foregroundStyle(DesignBook.Color.Text.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    /// A section: its heading, then its content, on one leading line.
    func section(
        _ title: String.LocalizationValue,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
            Text(localized(title))
                .font(DesignBook.Font.title2)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        RulesView()
    }
}
