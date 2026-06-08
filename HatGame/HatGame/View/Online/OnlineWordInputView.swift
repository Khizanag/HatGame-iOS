//
//  OnlineWordInputView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 22.12.24.
//

import DesignBook
import Navigation
import Networking
import SwiftUI

struct OnlineWordInputView: View {
    @Environment(RoomManager.self) private var roomManager
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var playerWords: [String] = []
    @State private var currentWord: String = ""
    @State private var isSubmitting: Bool = false
    @State private var error: Error?

    @FocusState private var isFieldFocused: Bool

    private let appConfiguration = AppConfiguration.shared

    private var wordsPerPlayer: Int { roomManager.room?.settings.wordsPerPlayer ?? 5 }
    private var trimmed: String { currentWord.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canAdd: Bool { !trimmed.isEmpty && playerWords.count < wordsPerPlayer && !playerWords.contains(trimmed) }
    private var canSubmit: Bool { playerWords.count == wordsPerPlayer && !isSubmitting }

    var body: some View {
        content
            .navigationTitle(localized("onlineWordInput.title"))
            .setDefaultStyle()
            .toolbar { keyboardToolbar }
            .onAppear { isFieldFocused = true }
            .alert("common.error", isPresented: errorBinding) {
                Button("common.gotIt") { error = nil }
            } message: {
                Text(error?.localizedDescription ?? "")
            }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
}

// MARK: - Composition
private extension OnlineWordInputView {
    var content: some View {
        ScrollView {
            VStack(spacing: DesignBook.Spacing.lg) {
                headerCard
                if playerWords.count < wordsPerPlayer {
                    inputCard
                } else {
                    readyCard
                    summaryCard
                }
            }
            .paddingHorizontalDefault()
            .padding(.bottom, DesignBook.Spacing.xxl)
        }
        .safeAreaInset(edge: .bottom) {
            if !isFieldFocused {
                primaryAction
                    .paddingHorizontalDefault()
                    .padding(.top, DesignBook.Spacing.md)
                    .padding(.bottom, DesignBook.Spacing.sm)
                    .withFooterGradient()
            }
        }
    }

    var headerCard: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.md) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(DesignBook.Color.Text.accent)
                Text(localized("onlineWordInput.instruction"))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    var inputCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.lg) {
                progressHeader
                if !playerWords.isEmpty {
                    wordsList
                }
                textField
            }
        }
    }

    var progressHeader: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
            HStack {
                Text(localized("onlineWordInput.wordsAdded"))
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                Spacer()
                Text(verbatim: "\(playerWords.count)/\(wordsPerPlayer)")
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.accent)
                    .monospacedDigit()
            }
            ProgressView(value: Double(playerWords.count), total: Double(wordsPerPlayer))
                .tint(DesignBook.Color.Text.accent)
        }
    }

    var wordsList: some View {
        VStack(spacing: DesignBook.Spacing.sm) {
            ForEach(playerWords.indices, id: \.self) { index in
                wordRow(at: index)
                    .transition(
                        .asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
        }
    }

    func wordRow(at index: Int) -> some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            Text(verbatim: "\(index + 1)")
                .font(DesignBook.Font.caption)
                .foregroundStyle(DesignBook.Color.Text.tertiary)
                .frame(width: 24, height: 24)
                .background(DesignBook.Color.Background.secondary)
                .clipShape(Circle())
            Text(playerWords[index])
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)
            Spacer()
            Button { removeWord(at: index) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(DesignBook.IconFont.small)
                    .foregroundStyle(DesignBook.Color.Status.error.opacity(0.7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(localized("wordInput.removeWord")))
        }
        .padding(DesignBook.Spacing.md)
        .background(DesignBook.Color.Background.secondary)
        .cornerRadius(DesignBook.Size.smallCardCornerRadius)
    }

    var textField: some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            TextField("onlineWordInput.enterWord", text: $currentWord)
                .textFieldStyle(.plain)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)
                .padding(DesignBook.Spacing.md)
                .background(DesignBook.Color.Background.secondary)
                .cornerRadius(DesignBook.Size.smallCardCornerRadius)
                .focused($isFieldFocused)
                .onSubmit { addWord() }

            Button { addWord() } label: {
                Image(systemName: "plus.circle.fill")
                    .font(DesignBook.Font.title2)
                    .foregroundStyle(canAdd ? DesignBook.Color.Text.accent : DesignBook.Color.Text.tertiary)
            }
            .buttonStyle(.plain)
            .disabled(!canAdd)
        }
    }

    var readyCard: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DesignBook.IconFont.extraLarge)
                    .foregroundStyle(DesignBook.Color.Status.success)
                Text(localized("onlineWordInput.ready"))
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                Text(localized("onlineWordInput.readyHint"))
                    .font(DesignBook.Font.body)
                    .foregroundStyle(DesignBook.Color.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(DesignBook.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
    }

    var summaryCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                Text(localized("onlineWordInput.summary"))
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)
                wordsList
            }
        }
    }

    var primaryAction: some View {
        Group {
            if isSubmitting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignBook.Color.Text.accent))
                    .scaleEffect(1.2)
                    .padding(.vertical, DesignBook.Spacing.md)
            } else if playerWords.count == wordsPerPlayer {
                PrimaryButton(title: localized("onlineWordInput.submit"), icon: "paperplane.fill") {
                    submit()
                }
            } else {
                PrimaryButton(title: localized("wordInput.addWord"), icon: "plus.circle.fill") {
                    addWord()
                }
                .disabled(!canAdd)
                .opacity(canAdd ? DesignBook.Opacity.enabled : DesignBook.Opacity.disabled)
            }
        }
    }

    @ToolbarContentBuilder
    var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            if playerWords.count == wordsPerPlayer {
                Button(action: submit) {
                    Label(localized("onlineWordInput.submit"), systemImage: "paperplane.fill")
                        .labelStyle(.titleAndIcon)
                        .fontWeight(.semibold)
                }
                .disabled(!canSubmit)
            } else {
                Button(action: addWord) {
                    Label(localized("wordInput.addWord"), systemImage: "plus.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .fontWeight(.semibold)
                }
                .disabled(!canAdd)
            }
        }
    }
}

// MARK: - Actions
private extension OnlineWordInputView {
    func addWord() {
        guard canAdd else { return }
        DesignBook.Haptics.tap()
        let animation = reduceMotion ? nil : DesignBook.Motion.bouncy
        withAnimation(animation) {
            playerWords.append(trimmed)
        }
        currentWord = ""
    }

    func removeWord(at index: Int) {
        DesignBook.Haptics.soft()
        let animation = reduceMotion ? nil : DesignBook.Motion.snappy
        _ = withAnimation(animation) {
            playerWords.remove(at: index)
        }
    }

    func submit() {
        guard canSubmit else { return }
        DesignBook.Haptics.confirm()
        isSubmitting = true
        isFieldFocused = false
        let snapshot = playerWords

        Task {
            do {
                try await roomManager.submitWords(snapshot)
            } catch {
                self.error = error
            }
            isSubmitting = false
        }
    }
}

#Preview {
    NavigationView { OnlineWordInputView() }
        .environment(Navigator())
        .environment(RoomManager())
}
