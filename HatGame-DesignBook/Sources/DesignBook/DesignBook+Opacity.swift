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
        public static let veryLight: Double = 0.05
        public static let light: Double = 0.1
        public static let subtle: Double = 0.15
        public static let highlight: Double = 0.2
        public static let medium: Double = 0.3
        public static let semiTransparent: Double = 0.6
        public static let semiOpaque: Double = 0.7
        public static let mostlyOpaque: Double = 0.8
    }
}
