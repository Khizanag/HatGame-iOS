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
    /// Applies an inline navigation-bar title on iOS and visionOS. A no-op on
    /// macOS, which has no navigation-bar title display mode.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if !os(macOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

// MARK: - List edit mode
extension View {
    /// Drives SwiftUI's list edit mode from a Bool on iOS and visionOS (for
    /// reordering and multi-delete). A no-op on macOS, where lists are directly
    /// reorderable.
    @ViewBuilder
    func editModeEnvironment(isEditing: Binding<Bool>) -> some View {
        #if !os(macOS)
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

    /// Hides the navigation bar on iOS and visionOS while `hidden` is true. A
    /// no-op on macOS, which has no navigation bar to hide.
    @ViewBuilder
    func hidesNavigationBar(_ hidden: Bool) -> some View {
        #if !os(macOS)
        toolbar(hidden ? .hidden : .automatic, for: .navigationBar)
        #else
        self
        #endif
    }
}

// MARK: - Glass button styles
extension View {
    /// The Liquid Glass button style. visionOS has no `.glass` style (its
    /// windows are already glass), so there it is the bordered style.
    @ViewBuilder
    func glassButtonStyle() -> some View {
        #if os(visionOS)
        buttonStyle(.bordered)
        #else
        buttonStyle(.glass)
        #endif
    }

    /// The prominent Liquid Glass button style; bordered-prominent on visionOS.
    @ViewBuilder
    func glassProminentButtonStyle() -> some View {
        #if os(visionOS)
        buttonStyle(.borderedProminent)
        #else
        buttonStyle(.glassProminent)
        #endif
    }
}

// MARK: - Glass effect container
/// Groups Liquid Glass shapes so they blend and morph together. visionOS has
/// no `GlassEffectContainer` (its windows are already glass), so there the
/// content renders as a plain group.
struct GlassContainer<Content: View>: View {
    let spacing: CGFloat?
    let content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        #if os(visionOS)
        content
        #else
        GlassEffectContainer(spacing: spacing) { content }
        #endif
    }
}

// MARK: - Toolbar placement
extension ToolbarItemPlacement {
    /// A trailing action placement: the navigation bar's trailing edge on iOS
    /// and visionOS, the window toolbar on macOS.
    static var trailingAction: ToolbarItemPlacement {
        #if !os(macOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }

    /// The bar above the software keyboard. visionOS has no keyboard toolbar,
    /// so there the items sit in the window's bottom ornament.
    static var keyboardAccessory: ToolbarItemPlacement {
        #if os(visionOS)
        .bottomOrnament
        #else
        .keyboard
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
