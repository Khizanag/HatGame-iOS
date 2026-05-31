//
//  AppIconSelectionView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 20.11.25.
//

import DesignBook
import Navigation
import SwiftUI

struct AppIconSelectionView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(\.navZoomNamespace) private var zoomNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let appConfiguration = AppConfiguration.shared

    var body: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.xl) {
                descriptionText
                CurrentIconCard(icon: appConfiguration.appIcon)
                iconGrid
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .navigationTitle(String(localized: "settings.appIcon.title"))
        .setDefaultStyle()
        .navigationZoomDestination(id: "appIconSelection", in: zoomNamespace)
    }
}

// MARK: - Subviews
private extension AppIconSelectionView {
    var descriptionText: some View {
        Text("settings.appIcon.description")
            .font(DesignBook.Font.body)
            .foregroundStyle(DesignBook.Color.Text.secondary)
            .padding(.horizontal, DesignBook.Spacing.sm)
    }

    var iconGrid: some View {
        SettingsSection(title: String(localized: "settings.appIcon.available")) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DesignBook.Spacing.md),
                    GridItem(.flexible(), spacing: DesignBook.Spacing.md),
                ],
                spacing: DesignBook.Spacing.lg
            ) {
                ForEach(AppIcon.allCases) { icon in
                    IconCard(
                        icon: icon,
                        isSelected: appConfiguration.appIcon == icon,
                        onSelect: { selectIcon(icon) }
                    )
                }
            }
        }
    }
}

// MARK: - Actions
private extension AppIconSelectionView {
    func selectIcon(_ icon: AppIcon) {
        guard appConfiguration.appIcon != icon else { return }
        DesignBook.Haptics.confirm()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.snappy) {
            appConfiguration.appIcon = icon
        }
    }
}

// MARK: - Subview types
private struct CurrentIconCard: View {
    let icon: AppIcon

    var body: some View {
        SettingsSection(
            title: String(localized: "settings.appIcon.current"),
            footer: String(localized: "settings.appIcon.current.description")
        ) {
            HStack(spacing: DesignBook.Spacing.md) {
                IconPreview(icon: icon, size: 60, symbolSize: 30)

                VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
                    Text(icon.title)
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Text(icon.subtitle)
                        .font(DesignBook.Font.caption)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                }

                Spacer()
            }
            .padding(DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.card)
            .cornerRadius(DesignBook.Size.cardCornerRadius)
        }
    }
}

private struct IconCard: View {
    let icon: AppIcon
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DesignBook.Spacing.md) {
                preview

                VStack(spacing: DesignBook.Spacing.xs) {
                    Text(icon.title)
                        .font(DesignBook.Font.headline)
                        .foregroundStyle(DesignBook.Color.Text.primary)

                    Text(icon.subtitle)
                        .font(DesignBook.Font.caption)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(DesignBook.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(DesignBook.Color.Background.card)
            .cornerRadius(DesignBook.Size.cardCornerRadius)
            .overlay {
                RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius)
                    .stroke(isSelected ? icon.displayColor : .clear, lineWidth: isSelected ? 2 : 0)
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(Text(icon.title))
    }

    private var preview: some View {
        ZStack(alignment: .topTrailing) {
            IconPreview(icon: icon, size: 100, symbolSize: 40)

            if isSelected {
                SelectedBadge(color: icon.displayColor)
                    .offset(x: 8, y: -8)
            }
        }
    }
}

/// Square gradient icon preview with the symbol centered on top.
private struct IconPreview: View {
    let icon: AppIcon
    let size: CGFloat
    let symbolSize: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: icon.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: size, height: size)
            .cornerRadius(DesignBook.Size.smallCardCornerRadius)
            .shadow(color: icon.displayColor.opacity(0.3), radius: 8, x: 0, y: 4)

            Image(systemName: icon.iconSymbol)
                .font(.system(size: symbolSize))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
        }
    }
}

private struct SelectedBadge: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AppIconSelectionView()
    }
    .environment(AppConfiguration.shared)
    .environment(Navigator())
}
