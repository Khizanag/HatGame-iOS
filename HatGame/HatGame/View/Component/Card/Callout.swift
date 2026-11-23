//
//  Callout.swift
//  HatGame
//

import DesignBook
import SwiftUI

/// A short note set apart from the content: a warning, a failure, a tip.
/// One shared panel of system glass, tinted faintly in its tone, with the
/// card corner every other card has (constitution articles 2 and 30).
struct Callout<Actions: View>: View {
    enum Tone {
        case info
        case warning
        case error

        var color: Color {
            switch self {
            case .info: DesignBook.Color.Text.accent
            case .warning: DesignBook.Color.Status.warning
            case .error: DesignBook.Color.Status.error
            }
        }
    }

    let tone: Tone
    let systemImage: String
    let message: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: DesignBook.Spacing.md) {
            Label {
                Text(message)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(DesignBook.Color.Text.primary)
            }
            .font(DesignBook.Font.body)
            .frame(maxWidth: .infinity, alignment: .leading)

            actions()
        }
        .padding(DesignBook.Spacing.md)
        .frame(maxWidth: .infinity)
        .glassSurface(
            in: .rect(cornerRadius: DesignBook.Size.cardCornerRadius, style: .continuous),
            tint: tone.color.opacity(DesignBook.Opacity.light)
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - No actions
extension Callout where Actions == EmptyView {
    init(tone: Tone, systemImage: String, message: String) {
        self.init(tone: tone, systemImage: systemImage, message: message) { EmptyView() }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: DesignBook.Spacing.md) {
        Callout(tone: .error, systemImage: "wifi.exclamationmark", message: "The words didn’t load.") {
            SecondaryButton(title: "Try Again", icon: "arrow.clockwise") {}
        }
        Callout(tone: .info, systemImage: "info.circle", message: "Words stay on this device.")
    }
    .padding()
    .background(DesignBook.Color.Background.primary)
}
