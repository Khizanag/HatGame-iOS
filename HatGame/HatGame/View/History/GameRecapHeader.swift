//
//  GameRecapHeader.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// The top of a recap, and the long-press preview of a game: the result in
/// the winner's colour, the winning total and margin, then one quiet line
/// of when, how long, and how it was played (constitution article 28).
struct GameRecapHeader: View {
    let record: GameRecord

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            resultDisc
            VStack(spacing: DesignBook.Spacing.xs) {
                Text(eyebrow)
                    .font(DesignBook.Font.subheadlineSemibold)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .eyebrowUppercase()
                    .tracking(1.2)
                Text(title)
                    .font(DesignBook.Font.displaySmall)
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text(summary)
                    .font(DesignBook.Font.headline)
                    .monospacedDigit()
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .multilineTextAlignment(.center)
            }
            Text(record.detailLine(locale: locale))
                .font(DesignBook.Font.footnote)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Components
private extension GameRecapHeader {
    var resultDisc: some View {
        ZStack {
            Circle()
                .fill(discColor)
                .frame(width: DesignBook.Size.heroDiscSmall, height: DesignBook.Size.heroDiscSmall)
                .shadow(.medium)
            Image(systemName: record.outcome == .finished && !record.isTie ? "trophy.fill" : record.resultSymbol)
                .font(DesignBook.IconFont.hero)
                .foregroundStyle(
                    record.isTie ? DesignBook.Color.Text.primary : DesignBook.Color.onAccent(for: record.resultColor)
                )
        }
        .decorativeHeroSizing()
        .accessibilityHidden(true)
    }

    var discColor: Color {
        record.isTie ? DesignBook.Color.Background.secondary : DesignBook.Color.opaque(record.resultColor)
    }

    var eyebrow: String {
        if record.outcome == .endedEarly {
            return record.outcomeNote ?? localized("history.endedEarly")
        }
        return localized(record.isTie ? "recap.eyebrow.tie" : "recap.eyebrow.winner")
    }

    var title: String {
        let leaders = record.winners
        guard !record.isTie, let first = leaders.first else {
            return leaders.map(\.name).formatted(.list(type: .and).locale(locale))
        }
        return first.name
    }

    var titleColor: Color {
        record.isTie ? DesignBook.Color.Text.primary : DesignBook.Color.teamText(for: record.resultColor)
    }

    /// "24 points · won by 5", or the shared total of a tie.
    var summary: String {
        let top = record.ranking.first?.total ?? 0
        let points = localized("recap.points \(top)")
        guard let margin = record.winningMargin else { return points }
        let lead = record.outcome == .finished
            ? localized("recap.margin.won \(margin)")
            : localized("recap.margin.ahead \(margin)")
        return "\(points) · \(lead)"
    }
}
