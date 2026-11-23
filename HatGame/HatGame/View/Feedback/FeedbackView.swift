//
//  FeedbackView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 01.06.26.
//

import DesignBook
import SwiftUI

/// In-app feedback form. Collects a category + message and submits straight to
/// Firebase, replacing the old mailto link so users never leave the app.
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var service = FeedbackService()
    @State private var category: FeedbackCategory = .idea
    @State private var message: String = ""
    @State private var isDiscardDialogPresented = false
    @FocusState private var isMessageFocused: Bool

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedMessage.isEmpty && !service.isSubmitting
    }

    /// An unsent message that leaving the screen would throw away.
    private var hasDraft: Bool {
        !trimmedMessage.isEmpty && service.state != .submitted
    }

    var body: some View {
        content
            .navigationTitle(localized("feedback.title"))
            .setDefaultStyle()
            .haptic(.success, trigger: service.state) { _, new in new == .submitted }
            .navigationBarBackButtonHidden(hasDraft)
            .toolbar {
                if hasDraft {
                    backToolbarItem
                }
                keyboardToolbar
            }
            .errorAlert(
                title: localized("error.title.sendFeedback"),
                message: service.errorMessage, onDismiss: service.resetAfterFailure)
    }
}

// MARK: - Composition
private extension FeedbackView {
    @ViewBuilder
    var content: some View {
        if service.state == .submitted {
            successState.transition(.opacity)
        } else {
            form.transition(.opacity)
        }
    }

    var form: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                SetupHero(
                    systemImage: "bubble.left.and.text.bubble.right.fill",
                    title: localized("feedback.hero.title"),
                    subtitle: localized("feedback.hero.subtitle")
                )
                categoryCard
                messageCard
            }
            .paddingHorizontalDefault()
            .padding(.top, DesignBook.Spacing.lg)
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .dismissesKeyboardOnScroll()
        .actionBar {
            submitButton
                .paddingHorizontalDefault()
                .padding(.top, DesignBook.Spacing.md)
                .padding(.bottom, DesignBook.Spacing.sm)
        }
    }

    var categoryCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                cardHeader(icon: "tag.fill", title: localized("feedback.category.label"))
                Picker(localized("feedback.category.label"), selection: $category) {
                    ForEach(FeedbackCategory.allCases) { category in
                        Text(category.title).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                // The card header already names it; macOS would repeat it.
                .labelsHidden()
            }
        }
    }

    var messageCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                cardHeader(icon: category.icon, title: localized("feedback.message.title"))
                TextField(
                    localized("feedback.message.placeholder"),
                    text: $message,
                    axis: .vertical
                )
                .lineLimit(5...12)
                .focused($isMessageFocused)
                .hatFieldStyle(label: localized("feedback.message.title")) { isMessageFocused = true }
            }
        }
    }

    func cardHeader(icon: String, title: String) -> some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            Image(systemName: icon)
                .font(DesignBook.IconFont.small)
                .foregroundStyle(DesignBook.Color.Text.secondary)
                .contentTransition(.symbolEffect(.replace))
            Text(title)
                .font(DesignBook.Font.subheadlineSemibold)
                .foregroundStyle(DesignBook.Color.Text.secondary)
        }
    }

    @ViewBuilder
    var submitButton: some View {
        if service.isSubmitting {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignBook.Spacing.md)
        } else {
            PrimaryButton(title: localized("feedback.submit"), icon: "paperplane.fill") {
                isMessageFocused = false
                Task { await service.submit(category: category, message: message) }
            }
            .disabled(!canSubmit)
        }
    }

    var successState: some View {
        VStack(spacing: DesignBook.Spacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(DesignBook.Color.Status.success.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(DesignBook.IconFont.extraLarge)
                    .foregroundStyle(DesignBook.Color.Status.success)
                    .symbolEffect(.bounce, options: reduceMotion ? .nonRepeating : .default)
            }
            .accessibilityHidden(true)
            .decorativeHeroSizing()

            VStack(spacing: DesignBook.Spacing.xs) {
                Text(localized("feedback.success.title"))
                    .font(DesignBook.Font.displaySmall)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                Text(localized("feedback.success.message"))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignBook.Spacing.lg)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            PrimaryButton(title: localized("feedback.success.done"), icon: "checkmark") {
                dismiss()
            }
            .paddingHorizontalDefault()
            .padding(.bottom, DesignBook.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
    }

    /// Stands in for the system Back button while a message is unsent, so
    /// leaving asks first instead of silently dropping the draft. Hiding the
    /// system button also turns off the swipe back.
    var backToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                isMessageFocused = false
                isDiscardDialogPresented = true
            } label: {
                Label(localized("feedback.back"), systemImage: "chevron.backward")
            }
            .help(localized("feedback.back"))
            // Anchored here so the dialog points at the button that asked.
            .confirmationDialog(
                localized("feedback.discard.title"),
                isPresented: $isDiscardDialogPresented,
                titleVisibility: .visible
            ) {
                Button(localized("feedback.discard.confirm"), role: .destructive) { dismiss() }
                Button(localized("feedback.discard.keepEditing"), role: .cancel) { }
            }
        }
    }

    @ToolbarContentBuilder
    var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboardAccessory) {
            Spacer()
            Button {
                isMessageFocused = false
            } label: {
                Label(localized("feedback.dismissKeyboard"), systemImage: "keyboard.chevron.compact.down")
                    .labelStyle(.iconOnly)
            }
            .help(localized("feedback.dismissKeyboard"))
        }
    }
}

// MARK: - Keyboard dismissal
private extension View {
    /// Dragging the form down dismisses the keyboard; visionOS has no
    /// scroll-driven keyboard dismissal.
    @ViewBuilder
    func dismissesKeyboardOnScroll() -> some View {
        #if os(visionOS)
        self
        #else
        scrollDismissesKeyboard(.interactively)
        #endif
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        FeedbackView()
    }
}
