//
//  WordCard.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 19.05.26.
//

import DesignBook
import SwiftUI

/// Hero word card used during a turn. Supports horizontal drag gestures to
/// signal "got it" (drag right) or "skip" (drag left). Tap-to-fire buttons are
/// also exposed by the parent for accessibility.
struct WordCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let word: String
    let teamTint: Color
    let onGuessed: () -> Void
    let onSkip: () -> Void
    /// Whether skipping is currently allowed. Disabled when only the last word remains.
    let isSkipEnabled: Bool

    @State private var dragOffset: CGSize = .zero
    @State private var isExiting: Bool = false
    @State private var pendingAction: PendingAction?

    /// Horizontal drag distance (in points) needed to fire either action.
    private static let dragThreshold: CGFloat = 100

    private var dragProgress: CGFloat {
        // Normalized [-1, 1] horizontal progress used to fade the action hint.
        let normalized = dragOffset.width / Self.dragThreshold
        return max(-1, min(1, normalized))
    }

    private var dragTint: Color {
        if dragOffset.width > 0 {
            DesignBook.Color.Status.success
        } else if dragOffset.width < 0 {
            DesignBook.Color.Status.warning
        } else {
            teamTint
        }
    }

    var body: some View {
        ZStack {
            cardBackground
            hintOverlay
            wordContent
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.05, contentMode: .fit)
        .offset(dragOffset)
        .rotationEffect(.degrees(reduceMotion ? 0 : Double(dragOffset.width / 18)))
        .scaleEffect(isExiting ? 0.85 : 1.0)
        .opacity(isExiting ? 0 : 1)
        .gesture(dragGesture)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(localized("game.card.accessibility.word \(word)")))
        .accessibilityHint(Text(localized("game.card.accessibility.hint")))
        .accessibilityAddTraits(.isButton)
    }

    private enum PendingAction {
        case guessed
        case skipped
    }
}

// MARK: - Subviews
private extension WordCard {
    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(DesignBook.Color.Background.card)
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(DesignBook.Gradient.brandBackdrop)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(
                        dragTint.opacity(abs(dragProgress) * 0.7),
                        lineWidth: 3
                    )
            }
            .shadow(color: dragTint.opacity(0.2 + abs(dragProgress) * 0.15), radius: 28, x: 0, y: 14)
    }

    var hintOverlay: some View {
        ZStack {
            // Got it hint - top-left of card content area
            HStack {
                VStack {
                    hintBadge(
                        icon: "checkmark",
                        label: "game.card.hint.gotIt",
                        color: DesignBook.Color.Status.success,
                        active: dragOffset.width > 20
                    )
                    .opacity(Double(max(0, dragProgress)))
                    .rotationEffect(.degrees(-12))
                    Spacer()
                }
                Spacer()
            }
            .padding(24)

            // Skip hint - top-right
            HStack {
                Spacer()
                VStack {
                    hintBadge(
                        icon: "arrow.uturn.forward",
                        label: "game.card.hint.skip",
                        color: DesignBook.Color.Status.warning,
                        active: dragOffset.width < -20
                    )
                    .opacity(Double(max(0, -dragProgress)))
                    .rotationEffect(.degrees(12))
                    Spacer()
                }
            }
            .padding(24)
        }
    }

    func hintBadge(icon: String, label: LocalizedStringKey, color: Color, active: Bool) -> some View {
        VStack(spacing: DesignBook.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
            Text(label)
                .font(DesignBook.Font.captionBold)
                .textCase(.uppercase)
                .tracking(1.4)
        }
        .foregroundStyle(color)
        .padding(.horizontal, DesignBook.Spacing.md)
        .padding(.vertical, DesignBook.Spacing.sm)
        .background {
            Capsule()
                .fill(color.opacity(0.18))
                .overlay {
                    Capsule().strokeBorder(color.opacity(0.45), lineWidth: 2)
                }
        }
        .scaleEffect(active ? 1.06 : 0.92)
        .animation(reduceMotion ? nil : DesignBook.Motion.snappy, value: active)
    }

    var wordContent: some View {
        VStack(spacing: DesignBook.Spacing.lg) {
            Spacer(minLength: 0)

            Text(word)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(DesignBook.Color.Text.primary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
                .lineLimit(3)
                .padding(.horizontal, DesignBook.Spacing.lg)
                .contentTransition(.opacity)

            Spacer(minLength: 0)

            Text(localized("game.card.swipeHint"))
                .font(DesignBook.Font.smallCaption)
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(DesignBook.Color.Text.tertiary)
                .padding(.bottom, DesignBook.Spacing.lg)
                .opacity(abs(dragProgress) < 0.05 ? 1 : 0)
                .animation(reduceMotion ? nil : DesignBook.Motion.standard, value: dragProgress)
        }
    }
}

// MARK: - Gestures & actions
private extension WordCard {
    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard pendingAction == nil else { return }
                let horizontal = value.translation.width
                // Soft clamp on skip when not allowed
                let dampedWidth = !isSkipEnabled && horizontal < 0 ? horizontal * 0.25 : horizontal
                let limitedWidth = max(min(dampedWidth, 240), -240)
                dragOffset = CGSize(width: limitedWidth, height: value.translation.height * 0.2)
            }
            .onEnded { value in
                let horizontal = value.translation.width
                if horizontal > Self.dragThreshold {
                    completeGuess()
                } else if horizontal < -Self.dragThreshold, isSkipEnabled {
                    completeSkip()
                } else {
                    reset()
                }
            }
    }

    func completeGuess() {
        complete(action: .guessed, exitX: 600, haptic: DesignBook.Haptics.confirm, callback: onGuessed)
    }

    func completeSkip() {
        complete(action: .skipped, exitX: -600, haptic: DesignBook.Haptics.soft, callback: onSkip)
    }

    /// Shared exit animation used by both guess and skip flows.
    private func complete(
        action: PendingAction,
        exitX: CGFloat,
        haptic: () -> Void,
        callback: @escaping () -> Void
    ) {
        pendingAction = action
        haptic()
        guard !reduceMotion else {
            callback()
            resetState()
            return
        }
        withAnimation(DesignBook.Motion.snappy) {
            dragOffset = CGSize(width: exitX, height: 0)
            isExiting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            callback()
            resetState()
        }
    }

    func reset() {
        DesignBook.Haptics.selection()
        withAnimation(DesignBook.Motion.bouncy) {
            dragOffset = .zero
        }
    }

    func resetState() {
        DispatchQueue.main.async {
            dragOffset = .zero
            isExiting = false
            pendingAction = nil
        }
    }
}

#Preview {
    WordCard(
        word: "ცხენი",
        teamTint: .blue,
        onGuessed: {},
        onSkip: {},
        isSkipEnabled: true
    )
    .padding()
    .background(DesignBook.Color.Background.primary)
}
