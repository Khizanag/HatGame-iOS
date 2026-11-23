//
//  LocalizationCatalogTests.swift
//  HatGameTests
//

import Foundation
import Testing

/// Reads the String Catalog itself, so a string added in English alone fails
/// the build's tests instead of shipping as English in Georgian
/// (constitution article 19).
@Suite("String Catalog")
struct LocalizationCatalogTests {
    static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "HatGame/Localization/Localizable.xcstrings")

    static let languages = ["en", "ka"]

    @Test("Every string ships translated in every language")
    func everyStringIsTranslated() throws {
        let data = try Data(contentsOf: Self.catalogURL)
        let catalog = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: [String: Any]])
        #expect(!strings.isEmpty)

        var missing: [String] = []
        for (key, entry) in strings where entry["shouldTranslate"] as? Bool != false {
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            for language in Self.languages {
                guard let node = localizations[language] as? [String: Any], Self.isTranslated(node) else {
                    missing.append("\(language): \(key)")
                    continue
                }
            }
        }
        #expect(missing.isEmpty, "Untranslated: \(missing.sorted().joined(separator: ", "))")
    }

    /// A node is translated when its own unit is, and every plural, device,
    /// or substitution variation under it is too.
    private static func isTranslated(_ node: [String: Any]) -> Bool {
        if let unit = node["stringUnit"] as? [String: Any], unit["state"] as? String != "translated" {
            return false
        }
        let variations = (node["variations"] as? [String: [String: [String: Any]]] ?? [:])
            .values.flatMap(\.values)
        let substitutions = (node["substitutions"] as? [String: [String: Any]] ?? [:]).values
        let children = Array(variations) + Array(substitutions)
        let hasContent = node["stringUnit"] != nil || !children.isEmpty
        return hasContent && children.allSatisfy(isTranslated)
    }
}
