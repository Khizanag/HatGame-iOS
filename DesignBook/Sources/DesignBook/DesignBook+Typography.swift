//
//  DesignBook+Typography.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 20.11.25.
//

import SwiftUI

extension DesignBook {
    public enum Font {
        // Display / hero sizes: fixed by design (no Dynamic Type text style matches
        // these large sizes, and they anchor the visual hierarchy).
        public static let largeTitle = SwiftUI.Font.system(size: 56, weight: .bold, design: .rounded)
        public static let title = SwiftUI.Font.system(size: 42, weight: .bold, design: .rounded)
        public static let title2 = SwiftUI.Font.system(size: 32, weight: .bold, design: .rounded)
        public static let subheadline = SwiftUI.Font.system(size: 18, weight: .semibold, design: .rounded)
        public static let subheadlineBold = SwiftUI.Font.system(size: 18, weight: .bold, design: .rounded)
        public static let footnote = SwiftUI.Font.system(size: 14, weight: .semibold, design: .rounded)
        public static let footnoteBold = SwiftUI.Font.system(size: 14, weight: .bold, design: .rounded)

        // Dynamic Type: each maps to the text style whose default size matches the
        // original fixed size, so these are pixel-identical at the default setting
        // but scale with the user's preferred text size.
        public static let title3 = SwiftUI.Font.system(.title, design: .rounded).weight(.semibold) // 28
        public static let headline = SwiftUI.Font.system(.title3, design: .rounded).weight(.semibold) // 20
        public static let callout = SwiftUI.Font.system(.title2, design: .rounded).weight(.semibold) // 22
        public static let body = SwiftUI.Font.system(.body, design: .rounded).weight(.regular) // 17
        public static let bodyBold = SwiftUI.Font.system(.body, design: .rounded).weight(.semibold) // 17
        public static let caption = SwiftUI.Font.system(.subheadline, design: .rounded).weight(.regular) // 15
        public static let captionBold = SwiftUI.Font.system(.subheadline, design: .rounded).weight(.semibold) // 15
        public static let smallCaption = SwiftUI.Font.system(.caption, design: .rounded).weight(.semibold) // 12
    }

    public enum IconFont {
        public static let small = SwiftUI.Font.system(size: 20, weight: .regular, design: .rounded)
        public static let medium = SwiftUI.Font.system(size: 24, weight: .regular, design: .rounded)
        public static let large = SwiftUI.Font.system(size: 32, weight: .regular, design: .rounded)
        public static let extraLarge = SwiftUI.Font.system(size: 48, weight: .regular, design: .rounded)
        public static let emoji = SwiftUI.Font.system(size: 80, weight: .regular, design: .rounded)
    }
}
