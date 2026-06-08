//
//  CrossPlatform.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 08.06.26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Navigation title
extension View {
    /// Applies an inline navigation-bar title on iOS. A no-op on macOS, which
    /// has no navigation-bar title display mode.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

// MARK: - List edit mode
extension View {
    /// Drives SwiftUI's list edit mode from a Bool on iOS (for reordering and
    /// multi-delete). A no-op on macOS, where lists are directly reorderable.
    @ViewBuilder
    func editModeEnvironment(isEditing: Binding<Bool>) -> some View {
        #if os(iOS)
        environment(\.editMode, Binding(
            get: { isEditing.wrappedValue ? .active : .inactive },
            set: { isEditing.wrappedValue = ($0 == .active) }
        ))
        #else
        self
        #endif
    }
}

// MARK: - List and navigation chrome
extension View {
    /// An inset-grouped list on iOS, an inset list on macOS (no inset-grouped).
    @ViewBuilder
    func groupedListStyle() -> some View {
        #if os(macOS)
        listStyle(.inset)
        #else
        listStyle(.insetGrouped)
        #endif
    }

    /// Hides the navigation bar on iOS while `hidden` is true. A no-op on macOS,
    /// which has no navigation bar to hide.
    @ViewBuilder
    func hidesNavigationBar(_ hidden: Bool) -> some View {
        #if os(iOS)
        toolbar(hidden ? .hidden : .automatic, for: .navigationBar)
        #else
        self
        #endif
    }
}

// MARK: - Toolbar placement
extension ToolbarItemPlacement {
    /// A trailing action placement: the navigation bar's trailing edge on iOS,
    /// the window toolbar on macOS.
    static var trailingAction: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }
}

// MARK: - Text input autocapitalization
extension View {
    /// Uppercases typed characters on iOS. A no-op on macOS, whose text fields
    /// have no input autocapitalization.
    @ViewBuilder
    func autocapitalizeCharacters() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.characters)
        #else
        self
        #endif
    }

    /// Capitalizes each typed word on iOS. A no-op on macOS, whose text fields
    /// have no input autocapitalization.
    @ViewBuilder
    func autocapitalizeWords() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.words)
        #else
        self
        #endif
    }
}

// MARK: - Platform
enum Platform {
    /// True on native macOS. Use to branch UI that must differ at runtime —
    /// e.g. always showing a primary footer button, since macOS has no software
    /// keyboard to dismiss and `.keyboard` toolbars don't render there.
    static var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    /// Copies a string to the system clipboard (UIPasteboard on iOS,
    /// NSPasteboard on macOS).
    static func copyToClipboard(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    /// The user's device name — `UIDevice` on iOS, the host name on macOS.
    static var deviceDisplayName: String {
        #if canImport(UIKit)
        UIDevice.current.name
        #elseif canImport(AppKit)
        Host.current().localizedName ?? "Mac"
        #else
        "Device"
        #endif
    }
}
