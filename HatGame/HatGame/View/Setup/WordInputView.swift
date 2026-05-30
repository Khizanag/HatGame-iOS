//
//  WordInputView.swift
//  HatGame
//
//  Created by Giga Khizanishvili on 15.11.25.
//

import DesignBook
import Navigation
import SwiftUI

struct WordInputView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentPlayerIndex: Int = 0
    @State private var playerWords: [String] = []
    @State private var currentWord: String = ""
    @State private var shouldScrollToTextField: Bool = false
    @State private var shouldScrollToLatestWord: Bool = false
    @State private var isAutoFilling: Bool = false

    @FocusState private var isWordFieldFocused: Bool
    @Namespace private var addButtonNamespace

    private let appConfiguration = AppConfiguration.shared

    private var allPlayers: [Player] {
        gameManager.configuration.teams.flatMap(\.players)
    }

    private var currentPlayer: Player? {
        allPlayers[safe: currentPlayerIndex]
    }

    private var nextPlayerName: String? {
        allPlayers[safe: currentPlayerIndex + 1]?.name
    }

    private var wordsPerPlayer: Int { gameManager.configuration.wordsPerPlayer }

    private var isCurrentPlayerDone: Bool { playerWords.count >= wordsPerPlayer }

    private var isAddWordButtonDisabled: Bool {
        currentWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCurrentPlayerDone
    }

    private var isLastPlayer: Bool { currentPlayerIndex == allPlayers.indices.last }

    var body: some View {
        content
            .navigationTitle(String(localized: "wordInput.title"))
            .setDefaultStyle()
            .onAppear(perform: prepareCurrentPlayer)
            .onChange(of: currentPlayerIndex) { _, _ in prepareCurrentPlayer() }
    }
}

// MARK: - Subviews
private extension WordInputView {
    var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: DesignBook.Spacing.lg) {
                    headerCard
                    wordEntrySection
                }
                .paddingHorizontalDefault()
                .padding(.bottom, DesignBook.Spacing.xxl)
            }
            .safeAreaInset(edge: .bottom) { footer }
            .onAppear { scrollToTextField(proxy: proxy, delay: 0.5) }
            .onChange(of: isWordFieldFocused) { _, focused in
                if focused { scrollToTextField(proxy: proxy, delay: 0.2) }
            }
            .onChange(of: playerWords.count) { _, _ in
                scrollToTextField(proxy: proxy, delay: 0.15)
            }
            .onChange(of: currentPlayerIndex) { _, _ in
                scrollToTextField(proxy: proxy, delay: 0.4)
            }
            .onChange(of: shouldScrollToTextField) { _, scroll in
                guard scroll else { return }
                scrollToTextField(proxy: proxy, delay: 0.1)
                shouldScrollToTextField = false
            }
            .onChange(of: shouldScrollToLatestWord) { _, scroll in
                guard scroll else { return }
                scrollToLatestWord(proxy: proxy)
                shouldScrollToLatestWord = false
            }
        }
    }

    var headerCard: some View {
        HeaderCard(
            title: String(localized: "wordInput.title"),
            description: currentPlayer.map { player in
                String(
                    format: String(localized: "wordInput.playerInstruction"),
                    player.name,
                    wordsPerPlayer
                )
            }
        ) {
            PlayerStepIndicator(
                playerCount: allPlayers.count,
                currentIndex: currentPlayerIndex
            )
        }
    }

    @ViewBuilder
    var wordEntrySection: some View {
        if currentPlayer != nil {
            if isCurrentPlayerDone {
                VStack(spacing: DesignBook.Spacing.md) {
                    CompletionCard(nextPlayerName: nextPlayerName)
                    WordsListCard(
                        playerWords: playerWords,
                        wordsPerPlayer: wordsPerPlayer,
                        onRemove: removeWord
                    )
                }
            } else {
                activeInputCard
            }
        }
    }

    var activeInputCard: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.lg) {
                progressHeader

                AutoFillButton(
                    isAutoFilling: isAutoFilling,
                    isDisabled: isCurrentPlayerDone || isAutoFilling,
                    action: handleAutoFillWords
                )

                if !playerWords.isEmpty {
                    WordsList(playerWords: playerWords, onRemove: removeWord)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                wordTextField
            }
        }
    }

    var progressHeader: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
            HStack {
                Text("wordInput.wordsAdded")
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
                .progressViewStyle(.linear)
        }
    }

    var wordTextField: some View {
        TextField("wordInput.enterWord", text: $currentWord)
            .textFieldStyle(.plain)
            .submitLabel(.next)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .font(DesignBook.Font.body)
            .foregroundStyle(DesignBook.Color.Text.primary)
            .padding(DesignBook.Spacing.md)
            .background(DesignBook.Color.Background.secondary)
            .cornerRadius(DesignBook.Size.smallCardCornerRadius)
            .focused($isWordFieldFocused)
            .onSubmit {
                guard !isAddWordButtonDisabled else { return }
                handleAddWord()
                shouldScrollToTextField = true
            }
            .id("wordTextField")
    }

    @ViewBuilder
    var footer: some View {
        Group {
            if isWordFieldFocused, !isCurrentPlayerDone {
                HStack {
                    Spacer()
                    FloatingAddButton(
                        action: handleAddWord,
                        isDisabled: isAddWordButtonDisabled,
                        namespace: addButtonNamespace
                    )
                }
            } else {
                actionButton
            }
        }
        .paddingHorizontalDefault()
        .padding(.bottom, DesignBook.Spacing.sm)
        .withFooterGradient()
    }

    @ViewBuilder
    var actionButton: some View {
        if !isCurrentPlayerDone {
            PrimaryButton(title: String(localized: "wordInput.addWord"), icon: "plus.circle.fill") {
                handleAddWord()
            }
            .disabled(isAddWordButtonDisabled)
            .opacity(isAddWordButtonDisabled ? DesignBook.Opacity.disabled : DesignBook.Opacity.enabled)
            .matchedGeometryEffect(id: "addButton", in: addButtonNamespace)
        } else {
            PrimaryButton(title: nextActionTitle, icon: nextActionIcon, action: handleSaveWords)
        }
    }

    var nextActionTitle: String {
        isLastPlayer ? String(localized: "wordInput.finish") : String(localized: "wordInput.nextPlayer")
    }

    var nextActionIcon: String {
        isLastPlayer ? "checkmark.circle.fill" : "arrow.right.circle.fill"
    }
}

// MARK: - Scrolling
private extension WordInputView {
    func scrollToTextField(proxy: ScrollViewProxy, delay: TimeInterval = 0.2) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
                proxy.scrollTo("wordTextField", anchor: .center)
            }
        }
    }

    func scrollToLatestWord(proxy: ScrollViewProxy) {
        guard !playerWords.isEmpty else { return }
        let latestIndex = playerWords.count - 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
                proxy.scrollTo("word_\(latestIndex)", anchor: .top)
            }
        }
    }
}

// MARK: - Actions
private extension WordInputView {
    func prepareCurrentPlayer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isWordFieldFocused = true
        }
    }

    func handleAddWord() {
        let trimmed = currentWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isCurrentPlayerDone else { return }
        // Signal silent duplicate rejections so the input doesn't feel dead.
        guard !playerWords.contains(trimmed) else {
            DesignBook.Haptics.warning()
            return
        }

        DesignBook.Haptics.tap()
        let animation = reduceMotion ? nil : DesignBook.Motion.bouncy
        withAnimation(animation) {
            playerWords.append(trimmed)
        }
        currentWord = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            shouldScrollToLatestWord = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isWordFieldFocused = true
        }
    }

    func removeWord(at index: Int) {
        DesignBook.Haptics.soft()
        let animation = reduceMotion ? nil : DesignBook.Motion.snappy
        _ = withAnimation(animation) {
            playerWords.remove(at: index)
        }
    }

    func handleSaveWords() {
        guard let currentPlayer else { return }
        DesignBook.Haptics.confirm()
        gameManager.addWords(playerWords, by: currentPlayer)

        if isLastPlayer {
            navigator.push(.randomization)
        } else {
            currentPlayerIndex += 1
            playerWords = []
        }
    }

    func handleAutoFillWords() {
        let remainingCount = wordsPerPlayer - playerWords.count
        guard remainingCount > 0, !isAutoFilling else { return }

        DesignBook.Haptics.tap()
        isWordFieldFocused = false

        var excluded = Set(playerWords)
        if !appConfiguration.allowDuplicateWords {
            excluded.formUnion(gameManager.getAllUsedWords())
        }

        let newWords = WordDatabase.words
            .filter { !excluded.contains($0) }
            .shuffled()
            .prefix(remainingCount)

        withAnimation(.easeInOut(duration: 0.3)) {
            isAutoFilling = true
        }

        for (index, word) in newWords.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3 + 0.5) {
                withAnimation(reduceMotion ? nil : DesignBook.Motion.bouncy) {
                    playerWords.append(word)
                }
                if index == newWords.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isAutoFilling = false
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Subview types
private struct PlayerStepIndicator: View {
    let playerCount: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: DesignBook.Spacing.xs) {
            ForEach(0..<playerCount, id: \.self) { index in
                Capsule()
                    .fill(color(for: index))
                    .frame(height: 6)
                    .overlay {
                        if index == currentIndex {
                            Capsule().stroke(DesignBook.Color.Text.accent, lineWidth: 2)
                        }
                    }
            }
        }
    }

    private func color(for index: Int) -> Color {
        if index < currentIndex {
            DesignBook.Color.Status.success
        } else if index == currentIndex {
            DesignBook.Color.Text.accent
        } else {
            DesignBook.Color.Background.secondary
        }
    }
}

private struct AutoFillButton: View {
    let isAutoFilling: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignBook.Spacing.sm) {
                Image(systemName: isAutoFilling ? "sparkles" : "wand.and.stars")
                    .font(DesignBook.Font.body)
                    .fontWeight(.semibold)
                    .symbolEffect(.pulse, options: .repeating, isActive: isAutoFilling)
                Text(isAutoFilling ? "wordInput.autoFill.thinking" : "wordInput.autoFill")
                    .font(DesignBook.Font.body)
                    .fontWeight(.medium)
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        DesignBook.Color.Text.accent,
                        DesignBook.Color.Text.accent.opacity(0.8),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.vertical, DesignBook.Spacing.md)
            .padding(.horizontal, DesignBook.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(background)
            .shadow(color: DesignBook.Color.Text.accent.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? DesignBook.Opacity.disabled : DesignBook.Opacity.enabled)
    }

    private var background: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignBook.Color.Text.accent.opacity(0.15),
                            DesignBook.Color.Text.accent.opacity(0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: DesignBook.Size.cardCornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            DesignBook.Color.Text.accent.opacity(0.3),
                            DesignBook.Color.Text.accent.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
    }
}

private struct FloatingAddButton: View {
    let action: () -> Void
    let isDisabled: Bool
    let namespace: Namespace.ID

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus.circle.fill")
                .font(DesignBook.IconFont.large)
                .frame(width: DesignBook.Size.floatingButtonSize, height: DesignBook.Size.floatingButtonSize)
        }
        .buttonStyle(.glassProminent)
        .disabled(isDisabled)
        .opacity(isDisabled ? DesignBook.Opacity.disabled : DesignBook.Opacity.enabled)
        .matchedGeometryEffect(id: "addButton", in: namespace)
    }
}

private struct WordsList: View {
    let playerWords: [String]
    let onRemove: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.sm) {
            ForEach(playerWords.indices, id: \.self) { index in
                WordRow(
                    index: index,
                    text: playerWords[index],
                    onRemove: { onRemove(index) }
                )
                .id("word_\(index)")
                .transition(
                    .asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    )
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        onRemove(index)
                    } label: {
                        Label(String(localized: "common.buttons.delete"), systemImage: "trash.fill")
                    }
                }
            }
        }
    }
}

private struct WordRow: View {
    let index: Int
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            Text(verbatim: "\(index + 1)")
                .font(DesignBook.Font.caption)
                .foregroundStyle(DesignBook.Color.Text.tertiary)
                .frame(width: DesignBook.Size.badgeSize, height: DesignBook.Size.badgeSize)
                .background(DesignBook.Color.Background.secondary)
                .clipShape(Circle())

            Text(text)
                .font(DesignBook.Font.body)
                .foregroundStyle(DesignBook.Color.Text.primary)

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(DesignBook.IconFont.small)
                    .foregroundStyle(DesignBook.Color.Status.error.opacity(0.7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("wordInput.removeWord"))
        }
        .padding(DesignBook.Spacing.md)
        .background(DesignBook.Color.Background.secondary)
        .cornerRadius(DesignBook.Size.smallCardCornerRadius)
    }
}

private struct CompletionCard: View {
    let nextPlayerName: String?

    var body: some View {
        GameCard {
            VStack(spacing: DesignBook.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DesignBook.IconFont.extraLarge)
                    .foregroundStyle(DesignBook.Color.Status.success)

                Text("wordInput.allWordsAdded")
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                if let nextPlayerName {
                    Text(String(format: String(localized: "wordInput.readyToPass"), nextPlayerName))
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("wordInput.allPlayersEntered")
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(DesignBook.Spacing.lg)
        }
    }
}

private struct WordsListCard: View {
    let playerWords: [String]
    let wordsPerPlayer: Int
    let onRemove: (Int) -> Void

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: DesignBook.Spacing.md) {
                Text(String(format: String(localized: "wordInput.wordsAddedProgress"), playerWords.count, wordsPerPlayer))
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                WordsList(playerWords: playerWords, onRemove: onRemove)
            }
        }
    }
}

// MARK: - Safe collection subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        WordInputView()
    }
    .environment(Navigator())
    .environment(GameManager())
}
