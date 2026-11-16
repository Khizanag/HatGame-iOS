//
//  DesignBook+Haptics.swift
//  DesignBook Package
//
//  Created by Giga Khizanishvili on 19.05.26.
//

#if os(iOS)
import UIKit
#endif

extension DesignBook {
    /// Centralized, semantic haptic feedback, played only on iPhone.
    ///
    /// Use each pattern for its documented meaning and only for moments that
    /// matter; system controls (toggles, sliders, pickers, menus) already
    /// play their own (HIG playing-haptics.md). Every event is a no-op while
    /// `isEnabled` is false, and always on macOS and visionOS — a Mac
    /// trackpad's haptics are reserved for dragging and Force Click.
    @MainActor
    public enum Haptics {
        /// The user's Haptics setting. The app sets it at launch and whenever
        /// the setting changes.
        public static var isEnabled = true

        // MARK: - Semantic events
        /// Light tap — a countdown tick.
        public static func tap() {
            impact(.light)
        }

        /// Medium impact — a confirmed gameplay moment: Got It, a turn or game starting.
        public static func confirm() {
            impact(.medium)
        }

        /// Soft thump — skipping a word.
        public static func soft() {
            impact(.soft)
        }

        /// Rigid thud — a confirmed destructive action.
        public static func rigid() {
            impact(.rigid)
        }

        /// Success notification — a celebratory completion.
        public static func success() {
            notify(.success)
        }

        /// Warning notification — time running out or up, rejected input.
        public static func warning() {
            notify(.warning)
        }

        /// Error notification — an action that failed.
        public static func error() {
            notify(.error)
        }
    }
}

// MARK: - Generators
private extension DesignBook.Haptics {
    #if os(iOS)
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    #else
    enum ImpactStyle { case light, medium, soft, rigid }
    enum NotificationType { case success, warning, error }

    static func impact(_ style: ImpactStyle) { }
    static func notify(_ type: NotificationType) { }
    #endif
}
