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
                CurrentAppIconCard(icon: appConfiguration.appIcon)
                iconGrid
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .navigationTitle(localized("settings.appIcon.title"))
        .setDefaultStyle()
        .navigationZoomDestination(id: "appIconSelection", in: zoomNamespace)
    }
}

// MARK: - Subviews
private extension AppIconSelectionView {
    var descriptionText: some View {
        Text(localized("settings.appIcon.description"))
            .font(DesignBook.Font.body)
            .foregroundStyle(DesignBook.Color.Text.secondary)
            .padding(.horizontal, DesignBook.Spacing.sm)
    }

    var iconGrid: some View {
        SettingsSection(title: localized("settings.appIcon.available")) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: DesignBook.Spacing.md)],
                spacing: DesignBook.Spacing.lg
            ) {
                ForEach(AppIcon.allCases) { icon in
                    AppIconCard(
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

// MARK: - Preview
#Preview {
    NavigationStack {
        AppIconSelectionView()
    }
    .environment(AppConfiguration.shared)
    .environment(Navigator())
}
