//
//  GlassCard.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// A card that is itself a control — it opens a mode, picks a choice, or
/// folds open — drawn as Liquid Glass so it reads as something to press.
/// Cards that only show content stay `GameCard`. Pass `selection` with the
/// color of a picked choice: the glass takes its tint and a ring.
struct GlassCardButtonStyle: ButtonStyle {
    var selection: Color?
    var alignment: Alignment = .leading

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // The label dims when disabled; glass styles itself and is never dimmed.
            .opacity(isEnabled ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)
            .padding(DesignBook.Spacing.md)
            .frame(maxWidth: .infinity, alignment: alignment)
            .glassCard(selection: selection, isInteractive: true)
            .pointerHoverEffect()
    }
}

// MARK: - Style shorthand
extension ButtonStyle where Self == GlassCardButtonStyle {
    /// A tappable card in Liquid Glass.
    static var glassCard: GlassCardButtonStyle { GlassCardButtonStyle() }

    /// A choice card in Liquid Glass, tinted and ringed with `selection`
    /// while picked; `nil` while not.
    static func glassCard(selection: Color?, alignment: Alignment = .leading) -> GlassCardButtonStyle {
        GlassCardButtonStyle(selection: selection, alignment: alignment)
    }
}

// MARK: - Glass card surface
extension View {
    /// The glass card shape behind a control card. Use `.buttonStyle(.glassCard)`
    /// when the whole card is one button; this directly when only part of it
    /// is, as in a card that folds open.
    func glassCard(selection: Color? = nil, isInteractive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous)
        // The ring is part of the content so it sits on the glass, not under it.
        return overlay {
            shape.strokeBorder(selection ?? .clear, lineWidth: DesignBook.Size.strokeThick)
        }
        .contentShape(shape)
        .glassSurface(
            in: shape,
            isInteractive: isInteractive,
            tint: selection?.opacity(DesignBook.Opacity.highlight)
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: DesignBook.Spacing.md) {
        Button {} label: {
            Text(verbatim: "Play Online")
                .foregroundStyle(DesignBook.Color.Text.primary)
        }
        .buttonStyle(.glassCard)

        Button {} label: {
            Text(verbatim: "Picked")
                .foregroundStyle(DesignBook.Color.Text.primary)
        }
        .buttonStyle(.glassCard(selection: .blue))
    }
    .padding()
    .background(DesignBook.Gradient.brandBackdrop)
}
