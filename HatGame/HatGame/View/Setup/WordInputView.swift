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
    @State private var isAutoFilling: Bool = false
    /// Each new request schedules one scroll; a newer request supersedes it.
    @State private var scrollRequest: ScrollRequest?
    /// Bumped to (re)focus the word field after a short settle delay.
    @State private var focusRequest: Int = 0
    /// The words an auto-fill is adding; its task is cancelled on disappear.
    @State private var autoFillRequest: AutoFillRequest?

    @FocusState private var isWordFieldFocused: Bool
    @Namespace private var addButtonNamespace

    private var allPlayers: [Player] {
        gameManager.configuration.players
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
            .navigationTitle(localized("wordInput.title"))
            .setDefaultStyle()
            .task(id: currentPlayerIndex) {
                loadCurrentPlayerWords()
            }
            .task(id: focusRequest) {
                guard (try? await Task.sleep(for: .milliseconds(300))) != nil else { return }
                isWordFieldFocused = true
            }
            .task(id: autoFillRequest) {
                await runAutoFill()
            }
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
            .onAppear { requestScrollToTextField(after: .milliseconds(500)) }
            .onChange(of: isWordFieldFocused) { _, focused in
                if focused { requestScrollToTextField(after: .milliseconds(200)) }
            }
            .onChange(of: playerWords.count) { _, _ in
                requestScrollToTextField(after: .milliseconds(150))
            }
            .onChange(of: currentPlayerIndex) { _, _ in
                requestScrollToTextField(after: .milliseconds(400))
            }
            .task(id: scrollRequest) {
                await performScroll(with: proxy)
            }
        }
    }

    var headerCard: some View {
        HeaderCard(
            title: localized("wordInput.title"),
            description: currentPlayer.map { player in
                String(
                    format: localized("wordInput.playerInstruction"),
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
                    isDisabled: isCurrentPlayerDone || isAutoFilling || WordDatabase.words.isEmpty,
                    action: handleAutoFillWords
                )

                if !playerWords.isEmpty {
                    WordsList(playerWords: playerWords, onRemove: removeWord)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }

                wordTextField
            }
        }
    }

    var progressHeader: some View {
        VStack(alignment: .leading, spacing: DesignBook.Spacing.xs) {
            HStack {
                Text(localized("wordInput.wordsAdded"))
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
            .autocapitalizeWords()
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
                requestScrollToTextField(after: .milliseconds(100))
            }
            .id(ScrollTarget.textField)
    }

    @ViewBuilder
    var footer: some View {
        Group {
            if isWordFieldFocused, !isCurrentPlayerDone, !Platform.isMac {
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
            PrimaryButton(title: localized("wordInput.addWord"), icon: "plus.circle.fill") {
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
        isLastPlayer ? localized("wordInput.finish") : localized("wordInput.nextPlayer")
    }

    var nextActionIcon: String {
        isLastPlayer ? "checkmark.circle.fill" : "arrow.right.circle.fill"
    }
}

// MARK: - Scrolling
private extension WordInputView {
    enum ScrollTarget {
        static let textField = "wordTextField"

        static func word(at index: Int) -> String {
            "word_\(index)"
        }
    }

    struct ScrollRequest: Equatable {
        let id = UUID()
        let target: String
        let anchor: UnitPoint
        let delay: Duration
    }

    func requestScrollToTextField(after delay: Duration) {
        scrollRequest = ScrollRequest(target: ScrollTarget.textField, anchor: .center, delay: delay)
    }

    func requestScrollToLatestWord() {
        guard !playerWords.isEmpty else { return }
        scrollRequest = ScrollRequest(
            target: ScrollTarget.word(at: playerWords.count - 1),
            anchor: .top,
            delay: .milliseconds(300)
        )
    }

    func performScroll(with proxy: ScrollViewProxy) async {
        guard let request = scrollRequest,
              (try? await Task.sleep(for: request.delay)) != nil
        else { return }
        withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
            proxy.scrollTo(request.target, anchor: request.anchor)
        }
    }
}

// MARK: - Actions
private extension WordInputView {
    struct AutoFillRequest: Equatable {
        let id = UUID()
        let words: [String]
    }

    /// Shows what this player already saved (after going back), so saving
    /// again replaces their words instead of adding a second copy.
    func loadCurrentPlayerWords() {
        guard let currentPlayer else { return }
        playerWords = gameManager.configuration.words
            .filter { $0.authorId == currentPlayer.id }
            .map(\.text)
        focusRequest += 1
    }

    func handleAddWord() {
        guard let currentPlayer else { return }
        let trimmed = currentWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isCurrentPlayerDone else { return }
        // Signal silent duplicate rejections so the input doesn't feel dead.
        guard !WordEntryRules.isDuplicate(
            trimmed,
            ownWords: playerWords,
            otherPlayersWords: gameManager.wordTexts(excluding: currentPlayer),
            allowsDuplicates: gameManager.configuration.allowsDuplicateWords
        ) else {
            DesignBook.Haptics.warning()
            return
        }

        DesignBook.Haptics.tap()
        withAnimation(reduceMotion ? nil : DesignBook.Motion.bouncy) {
            playerWords.append(trimmed)
        }
        currentWord = ""
        requestScrollToLatestWord()
        focusRequest += 1
    }

    func removeWord(at index: Int) {
        guard playerWords.indices.contains(index) else { return }
        DesignBook.Haptics.soft()
        _ = withAnimation(reduceMotion ? nil : DesignBook.Motion.snappy) {
            playerWords.remove(at: index)
        }
    }

    func handleSaveWords() {
        guard let currentPlayer else { return }
        DesignBook.Haptics.confirm()
        autoFillRequest = nil
        gameManager.setWords(playerWords, for: currentPlayer)

        if isLastPlayer {
            navigator.push(.randomization)
        } else {
            currentPlayerIndex += 1
        }
    }

    func handleAutoFillWords() {
        guard let currentPlayer, !isAutoFilling else { return }
        let excluded = playerWords + (
            gameManager.configuration.allowsDuplicateWords ? [] : gameManager.wordTexts(excluding: currentPlayer)
        )
        let words = WordEntryRules.distinct(
            WordDatabase.words.shuffled(),
            excluding: excluded,
            limit: wordsPerPlayer - playerWords.count
        )
        guard !words.isEmpty else {
            DesignBook.Haptics.warning()
            return
        }

        DesignBook.Haptics.tap()
        isWordFieldFocused = false
        withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
            isAutoFilling = true
        }
        autoFillRequest = AutoFillRequest(words: words)
    }

    /// Adds the auto-filled words one by one. Each append re-checks capacity
    /// and duplicates, since the player can still edit the list meanwhile.
    func runAutoFill() async {
        guard let request = autoFillRequest else { return }
        defer {
            withAnimation(reduceMotion ? nil : DesignBook.Motion.standard) {
                isAutoFilling = false
            }
        }
        for (index, word) in request.words.enumerated() {
            if !reduceMotion {
                let delay: Duration = index == 0 ? .milliseconds(500) : .milliseconds(300)
                guard (try? await Task.sleep(for: delay)) != nil else { return }
            }
            guard !isCurrentPlayerDone else { return }
            guard !WordEntryRules.isDuplicate(
                word,
                ownWords: playerWords,
                otherPlayersWords: [],
                allowsDuplicates: true
            ) else { continue }
            withAnimation(reduceMotion ? nil : DesignBook.Motion.bouncy) {
                playerWords.append(word)
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
                        Label(localized("common.buttons.delete"), systemImage: "trash.fill")
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

    @ScaledMetric(relativeTo: .subheadline) private var badgeSize: CGFloat = DesignBook.Size.badgeSize

    var body: some View {
        HStack(spacing: DesignBook.Spacing.sm) {
            Text(verbatim: "\(index + 1)")
                .font(DesignBook.Font.caption)
                .foregroundStyle(DesignBook.Color.Text.tertiary)
                .frame(width: badgeSize, height: badgeSize)
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
            .accessibilityLabel(Text(localized("wordInput.removeWord")))
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

                Text(localized("wordInput.allWordsAdded"))
                    .font(DesignBook.Font.title3)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                if let nextPlayerName {
                    Text(String(format: localized("wordInput.readyToPass"), nextPlayerName))
                        .font(DesignBook.Font.body)
                        .foregroundStyle(DesignBook.Color.Text.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text(localized("wordInput.allPlayersEntered"))
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
                Text(String(format: localized("wordInput.wordsAddedProgress"), playerWords.count, wordsPerPlayer))
                    .font(DesignBook.Font.headline)
                    .foregroundStyle(DesignBook.Color.Text.primary)

                WordsList(playerWords: playerWords, onRemove: onRemove)
            }
        }
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
