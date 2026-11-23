//
//  DesignBook+Opacity.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 20.11.25.
//

extension DesignBook {
    public enum Opacity {
        // MARK: - State Opacities
        public static let enabled: Double = 1.0
        public static let disabled: Double = 0.4

        // MARK: - Overlay & Background Opacities
        /// 0 — the clear end of a fade.
        public static let transparent: Double = 0
        public static let veryLight: Double = 0.05
        public static let light: Double = 0.1
        /// 0.15 — a colour washed behind a glyph or a selected row.
        public static let tint: Double = 0.15
        public static let highlight: Double = 0.2
        /// 0.25
        public static let soft: Double = 0.25
        public static let medium: Double = 0.3
        /// 0.35 — a coloured outline around a highlighted row.
        public static let outline: Double = 0.35
        /// 0.45 — a coloured ring or glow that marks a selection.
        public static let emphasis: Double = 0.45
        /// 0.5
        public static let half: Double = 0.5
        /// 0.55 — the halo behind a hero disc.
        public static let glow: Double = 0.55
        public static let semiTransparent: Double = 0.6
        /// 0.65
        public static let vivid: Double = 0.65
        /// 0.7
        public static let strong: Double = 0.7
        public static let mostlyOpaque: Double = 0.8
        /// 0.9
        public static let nearlyOpaque: Double = 0.9
        /// 0.95 — a solid backdrop that still hints at what is behind it.
        public static let backdrop: Double = 0.95
    }
}
