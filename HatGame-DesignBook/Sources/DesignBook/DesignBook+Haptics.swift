//
//  DesignBook+Haptics.swift
//  DesignBook Package
//
//  Created by Giga Khizanishvili on 19.05.26.
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension DesignBook {
    /// Centralized, semantic haptic feedback used across the app.
    /// Wraps UIKit feedback generators so callers don't manage `prepare()` themselves.
    /// On macOS the impact-style events map onto `NSHapticFeedbackManager` (Force
    /// Touch trackpads only); notification-style events have no macOS equivalent
    /// and stay silent.
    @MainActor
    public enum Haptics {
        // MARK: - Semantic events
        /// Light tap — minor selections, picker scrolls.
        public static func selection() {
            #if os(iOS)
            UISelectionFeedbackGenerator().selectionChanged()
            #elseif os(macOS)
            performMac(.generic)
            #endif
        }

        /// Light impact — taps on primary controls.
        public static func tap() {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #elseif os(macOS)
            performMac(.generic)
            #endif
        }

        /// Medium impact — confirmation moments, like marking a word correct.
        public static func confirm() {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #elseif os(macOS)
            performMac(.levelChange)
            #endif
        }

        /// Soft thump — used for "skip" or "pass" interactions.
        public static func soft() {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #elseif os(macOS)
            performMac(.generic)
            #endif
        }

        /// Rigid thud — used for serious or destructive events.
        public static func rigid() {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            #elseif os(macOS)
            performMac(.levelChange)
            #endif
        }

        /// Success notification — celebratory completion.
        public static func success() {
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        }

        /// Warning notification — used for warnings like timer running out.
        public static func warning() {
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            #endif
        }

        /// Error notification — used for failures like running out of time.
        public static func error() {
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
        }

        #if os(macOS)
        private static func performMac(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
            NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
        }
        #endif
    }
}
