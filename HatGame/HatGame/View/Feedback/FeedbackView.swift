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
    @FocusState private var isMessageFocused: Bool

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedMessage.isEmpty && !service.isSubmitting
    }

    var body: some View {
        content
            .navigationTitle(localized("feedback.title"))
            .setDefaultStyle()
            .toolbar { keyboardToolbar }
            .alert("common.error", isPresented: errorBinding) {
                Button("common.gotIt") { service.resetAfterFailure() }
            } message: {
                Text(service.errorMessage ?? "")
            }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { service.errorMessage != nil },
            set: { if !$0 { service.resetAfterFailure() } }
        )
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
        .safeAreaInset(edge: .bottom) {
            submitButton
                .paddingHorizontalDefault()
                .padding(.top, DesignBook.Spacing.md)
                .padding(.bottom, DesignBook.Spacing.sm)
                .withFooterGradient()
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
                .textFieldStyle(.plain)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .lineLimit(5...12)
                .focused($isMessageFocused)
                .padding(DesignBook.Spacing.md)
                .background(DesignBook.Color.Background.secondary)
                .cornerRadius(DesignBook.Size.smallCardCornerRadius)
            }
        }
    }

    func cardHeader(icon: String, title: String) -> some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            Image(systemName: icon)
                .font(DesignBook.IconFont.small)
                .foregroundStyle(DesignBook.Color.Text.accent)
                .contentTransition(.symbolEffect(.replace))
            Text(title)
                .font(DesignBook.Font.captionBold)
                .foregroundStyle(DesignBook.Color.Text.secondary)
        }
    }

    @ViewBuilder
    var submitButton: some View {
        if service.isSubmitting {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignBook.Color.Text.accent))
                .scaleEffect(1.2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignBook.Spacing.md)
        } else {
            PrimaryButton(title: localized("feedback.submit"), icon: "paperplane.fill") {
                DesignBook.Haptics.confirm()
                isMessageFocused = false
                Task { await service.submit(category: category, message: message) }
            }
            .disabled(!canSubmit)
            .opacity(canSubmit ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)
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

            VStack(spacing: DesignBook.Spacing.xs) {
                Text(localized("feedback.success.title"))
                    .font(DesignBook.Font.title2)
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
                DesignBook.Haptics.tap()
                dismiss()
            }
            .paddingHorizontalDefault()
            .padding(.bottom, DesignBook.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .onAppear { DesignBook.Haptics.success() }
    }

    @ToolbarContentBuilder
    var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button {
                isMessageFocused = false
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
            }
            .accessibilityLabel(Text(localized("common.gotIt")))
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        FeedbackView()
    }
}
