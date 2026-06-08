//
//  FeedbackService.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 01.06.26.
//

import Foundation
import Networking
import Observation
import UIKit

/// What kind of feedback the user is sending. The raw value is what gets
/// stored in Firebase; titles/icons are presentation only.
enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug
    case idea
    case praise
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bug: localized("feedback.category.bug")
        case .idea: localized("feedback.category.idea")
        case .praise: localized("feedback.category.praise")
        case .other: localized("feedback.category.other")
        }
    }

    var icon: String {
        switch self {
        case .bug: "ladybug.fill"
        case .idea: "lightbulb.fill"
        case .praise: "heart.fill"
        case .other: "ellipsis.bubble.fill"
        }
    }
}

/// View-local service that gathers feedback plus lightweight diagnostics and
/// submits it to Firebase, exposing a simple state machine for the UI.
@MainActor
@Observable
final class FeedbackService {
    enum SubmissionState: Equatable {
        case editing
        case submitting
        case submitted
        case failed(String)
    }

    private(set) var state: SubmissionState = .editing

    var isSubmitting: Bool { state == .submitting }

    var errorMessage: String? {
        if case let .failed(message) = state { return message }
        return nil
    }

    func submit(category: FeedbackCategory, message: String) async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, state != .submitting else { return }
        state = .submitting

        let feedback = Feedback(
            category: category.rawValue,
            message: trimmed,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
            systemVersion: UIDevice.current.systemVersion,
            deviceModel: Self.deviceModel,
            locale: Locale.current.identifier,
            deviceId: UserDefaults.standard.string(forKey: "HatGame.deviceId")
        )

        do {
            try await FirebaseService.shared.submitFeedback(feedback)
            state = .submitted
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Returns to the editing state after a failure so the user can retry.
    func resetAfterFailure() {
        if case .failed = state { state = .editing }
    }

    /// The hardware model identifier, e.g. "iPhone17,2".
    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return Mirror(reflecting: systemInfo.machine).children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier += String(UnicodeScalar(UInt8(value)))
        }
    }
}
