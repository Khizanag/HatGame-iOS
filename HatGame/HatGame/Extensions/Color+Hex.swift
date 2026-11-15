//
//  Color+Hex.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import SwiftUI

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        let red, green, blue, alpha: Double

        switch length {
        case 6:
            red = Double((rgb & 0xFF0000) >> 16) / 255.0
            green = Double((rgb & 0x00FF00) >> 8) / 255.0
            blue = Double(rgb & 0x0000FF) / 255.0
            alpha = 1.0
        case 8:
            red = Double((rgb & 0xFF000000) >> 24) / 255.0
            green = Double((rgb & 0x00FF0000) >> 16) / 255.0
            blue = Double((rgb & 0x0000FF00) >> 8) / 255.0
            alpha = Double(rgb & 0x000000FF) / 255.0
        default:
            return nil
        }

        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }

    var hexString: String {
        let resolved = self.resolve(in: EnvironmentValues())
        let red = Int(resolved.red * 255)
        let green = Int(resolved.green * 255)
        let blue = Int(resolved.blue * 255)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
