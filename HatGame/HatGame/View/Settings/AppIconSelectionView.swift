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
        Form {
            currentSection
            availableSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(localized("settings.appIcon.title"))
        .setDefaultStyle()
        .navigationZoomDestination(id: "appIconSelection", in: zoomNamespace)
    }
}

// MARK: - Sections
private extension AppIconSelectionView {
    var currentSection: some View {
        Section {
            CurrentAppIconRow(icon: appConfiguration.appIcon)
        } header: {
            Text(localized("settings.appIcon.current"))
        } footer: {
            Text(localized("settings.appIcon.description"))
        }
    }

    var availableSection: some View {
        Section {
            LazyVGrid(columns: columns, spacing: DesignBook.Spacing.md) {
                ForEach(AppIcon.allCases) { icon in
                    AppIconCard(
                        icon: icon,
                        isSelected: appConfiguration.appIcon == icon,
                        onSelect: { selectIcon(icon) }
                    )
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
            Text(localized("settings.appIcon.available"))
        }
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
