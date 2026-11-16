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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let appConfiguration = AppConfiguration.shared

    var body: some View {
        // A ScrollView, not a Form: a Form row clips its content to the
        // cell's corner shape, which cut the corners off the icon cards.
        ScrollView {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.lg) {
                currentSection
                availableSection
            }
            .padding(.vertical, DesignBook.Spacing.md)
            .paddingHorizontalDefault()
        }
        .navigationTitle(localized("settings.appIcon.title"))
        .setDefaultStyle()
        .navigationZoomDestination(id: "appIconSelection", in: zoomNamespace)
    }
}

// MARK: - Sections
private extension AppIconSelectionView {
    var currentSection: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
            sectionHeader(localized("settings.appIcon.current"))

            CurrentAppIconRow(icon: appConfiguration.appIcon)
                .padding(DesignBook.Spacing.md)
                .cardSurface()

            Text(localized("settings.appIcon.description"))
                .font(DesignBook.Font.footnote)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .padding(.horizontal, DesignBook.Spacing.md)
        }
    }

    var availableSection: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
            sectionHeader(localized("settings.appIcon.available"))

            LazyVGrid(columns: columns, spacing: DesignBook.Spacing.md) {
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

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DesignBook.Font.headline)
            .foregroundStyle(DesignBook.Color.Text.secondary)
            .padding(.horizontal, DesignBook.Spacing.md)
            .accessibilityAddTraits(.isHeader)
    }

    /// One column at accessibility sizes, two or more otherwise.
    var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.flexible())]
        } else {
            [GridItem(.adaptive(minimum: 150), spacing: DesignBook.Spacing.md)]
        }
    }
}

// MARK: - Actions
private extension AppIconSelectionView {
    func selectIcon(_ icon: AppIcon) {
        guard appConfiguration.appIcon != icon else { return }
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
