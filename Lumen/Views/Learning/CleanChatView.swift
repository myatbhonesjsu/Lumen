//
//  CleanChatView.swift
//  Lumen
//
//  Simple, accessible chatbot with proper keyboard handling
//

import SwiftUI
import SwiftData
import Combine

struct CleanChatView: View {
    let tabBarHeight: CGFloat

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SkinMetric.timestamp, order: .reverse) private var skinMetrics: [SkinMetric]
    @Query(sort: \PersistedChatMessage.timestamp, order: .forward) private var persistedMessages: [PersistedChatMessage]

    @State private var inputText = ""
    @State private var isLoading = false
    @State private var relatedArticles: [ArticleRecommendation] = []
    @State private var selectedArticle: ArticleRecommendation?
    @State private var showClearChatAlert = false
    @FocusState private var isInputFocused: Bool
    @StateObject private var keyboardObserver = KeyboardObserver()

    // Stable session ID that persists across app launches
    private var sessionId: String {
        if let existing = UserDefaults.standard.string(forKey: "chatSessionId") {
            return existing
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "chatSessionId")
            return newId
        }
    }
    
    // ⚙️ MANUAL PADDING ADJUSTMENTS - Edit these values to fine-tune spacing

    // Adjust these values to change positioning:
    private let inputFieldHeight: CGFloat = 48         // Minimum height for input container
    private let extraPaddingWhenKeyboardHidden: CGFloat = 24  // Extra space above tab bar when keyboard is down
    private let extraPaddingWhenKeyboardVisible: CGFloat = -8  // Extra space above keyboard when keyboard is up
    private let messageClearance: CGFloat = 80                // Extra space below messages for scrolling

    private var isKeyboardVisible: Bool {			
        keyboardObserver.height > 0
    }

    private var inputBottomPadding: CGFloat {
        if isKeyboardVisible {
            // When keyboard is up: position input above keyboard
            // Increase extraPaddingWhenKeyboardVisible to move input field HIGHER (more space from keyboard)
            // Decrease to move input field LOWER (closer to keyboard)
            return keyboardObserver.height + extraPaddingWhenKeyboardVisible
        } else {
            // When keyboard is down: position input above tab bar
            // Increase extraPaddingWhenKeyboardHidden to move input field HIGHER (more space from tab bar)
            // Decrease to move input field LOWER (closer to tab bar)
            return tabBarHeight + extraPaddingWhenKeyboardHidden
        }
    }

    private var scrollBottomPadding: CGFloat {
        // Reserve space for input field + some clearance
        // Increase messageClearance to give more space below messages
        return inputBottomPadding + inputFieldHeight + messageClearance
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if persistedMessages.isEmpty {
                            // Welcome Screen
                            VStack(spacing: 24) {
                                Spacer()
                                    .frame(height: 80)
                                
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 70))
                                    .foregroundStyle(.yellow)
                                
                                VStack(spacing: 12) {
                                    Text("Your AI Skincare Assistant")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Text("Ask me anything about skincare")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Try asking:")
                                        .font(.headline)
                                        .padding(.horizontal)
                                    
                                    ForEach(sampleQuestions, id: \.self) { question in
                                        QuickQuestionButton(question: question) {
                                            inputText = question
                                            sendMessage()
                                        }
                                    }
                                }
                                .padding(.top, 16)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            // Chat Messages
                            ForEach(persistedMessages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                            
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .tint(.yellow)
                                    Text("Thinking...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            }
                            
                            // Related Articles
                            if !relatedArticles.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Related Articles")
                                        .font(.headline)
                                        .padding(.horizontal)
                                    
                                    ForEach(relatedArticles.prefix(3)) { article in
                                        CompactArticleCard(article: article)
                                            .onTapGesture {
                                                selectedArticle = article
                                            }
                                    }
                                }
                                .padding(.top, 12)
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, scrollBottomPadding)
                    .onChange(of: persistedMessages.count) { _, _ in
                        if let lastMessage = persistedMessages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
                .onTapGesture {
                    isInputFocused = false
                }
            }
            
            // Input Bar - positioned just above keyboard/tab bar
            VStack(spacing: 0) {
                Divider()

                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Ask about skincare...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .lineLimit(1...6)  // Allow up to 6 lines
                        .submitLabel(.send)
                        .focused($isInputFocused)
                        .onSubmit {
                            sendMessage()
                        }
                        .frame(minHeight: 44)  // Minimum tap target size

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(canSend ? .yellow : .gray)
                    }
                    .disabled(!canSend)
                    .padding(.bottom, 8)  // Align with bottom of text field
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Color(.systemBackground)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: -4)
                )
            }
            .background(Color(.systemBackground))
            .padding(.bottom, inputBottomPadding)
            .animation(.easeOut(duration: 0.25), value: keyboardObserver.height)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !persistedMessages.isEmpty {
                        Button(action: { showClearChatAlert = true }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert("Clear Chat History", isPresented: $showClearChatAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearChat()
                }
            } message: {
                Text("This will delete all your chat messages. This action cannot be undone.")
            }
            .sheet(item: $selectedArticle) { article in
                ArticleWebView(article: article)
            }
        }
        .accessibilityIdentifier("chat.screen")

    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
    
    private var sampleQuestions: [String] {
        [
            "What's the best routine for my skin?",
            "How can I reduce dark circles?",
            "Should I use retinol?",
            "What causes acne breakouts?"
        ]
    }
    
    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        isInputFocused = false

        // Create and save user message to SwiftData
        let userMessage = PersistedChatMessage(
            role: "user",
            message: trimmed,
            sessionId: sessionId,
            sources: nil
        )
        modelContext.insert(userMessage)
        try? modelContext.save()

        inputText = ""
        isLoading = true

        Task {
            do {
                // Prepare local analysis data from device (most recent 5)
                let localAnalyses = prepareLocalAnalyses()

                let response = try await LearningHubService.shared.sendMessage(
                    message: userMessage.message,
                    sessionId: sessionId,
                    localAnalyses: localAnalyses
                )

                await MainActor.run {
                    // Convert API sources to ChatSource format
                    let chatSources = response.sources?.map { apiSource in
                        ChatSource(
                            id: UUID().uuidString,
                            source: apiSource.source,
                            url: nil
                        )
                    }

                    // Create and save assistant message to SwiftData
                    let assistantMessage = PersistedChatMessage(
                        role: "assistant",
                        message: response.response,
                        sessionId: sessionId,
                        sources: chatSources
                    )
                    modelContext.insert(assistantMessage)
                    try? modelContext.save()

                    relatedArticles = response.relatedArticles
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    // Create and save error message to SwiftData
                    let errorMessage = PersistedChatMessage(
                        role: "assistant",
                        message: "I'm sorry, I encountered an error. Please try again.",
                        sessionId: sessionId,
                        sources: nil
                    )
                    modelContext.insert(errorMessage)
                    try? modelContext.save()

                    isLoading = false
                }
            }
        }
    }

    private func clearChat() {
        // Delete all messages from SwiftData
        for message in persistedMessages {
            modelContext.delete(message)
        }
        try? modelContext.save()

        // Clear related articles
        relatedArticles = []

        // Reset session ID to start fresh
        UserDefaults.standard.removeObject(forKey: "chatSessionId")

        HapticManager.shared.success()
    }

    private func prepareLocalAnalyses() -> [[String: Any]] {
        // Get the most recent 5 analyses from local device storage
        let recentMetrics = Array(skinMetrics.prefix(5))

        return recentMetrics.map { metric in
            [
                "timestamp": Int(metric.timestamp.timeIntervalSince1970),
                "prediction": [
                    "condition": determinePrimaryCondition(metric),
                    "confidence": metric.overallHealth / 100.0,
                    "all_conditions": [
                        "acne": metric.acneLevel / 100.0,
                        "dryness": metric.drynessLevel / 100.0,
                        "dark_circles": metric.darkCircleLevel / 100.0,
                        "pigmentation": metric.pigmentationLevel / 100.0
                    ]
                ],
                "enhanced_analysis": [
                    "summary": metric.analysisNotes
                ]
            ]
        }
    }

    private func determinePrimaryCondition(_ metric: SkinMetric) -> String {
        // Determine the primary skin condition based on the highest metric
        let conditions = [
            ("Acne", metric.acneLevel),
            ("Dryness", metric.drynessLevel),
            ("Dark Circles", metric.darkCircleLevel),
            ("Pigmentation", metric.pigmentationLevel)
        ]

        let primaryCondition = conditions.max(by: { $0.1 < $1.1 })
        return primaryCondition?.0 ?? "Normal"
    }
}

// MARK: - Chat Bubble View

struct ChatBubbleView: View {
    let message: PersistedChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == "user" {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 6) {
                Text(message.message)
                    .font(.body)
                    .foregroundColor(message.role == "user" ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        message.role == "user"
                        ? Color.yellow
                        : Color(.systemGray5)
                    )
                    .cornerRadius(20)

                if let sources = message.sources, !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sources")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ForEach(sources) { source in
                            Text("• \(source.source)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
                }
            }

            if message.role == "assistant" {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Quick Question Button

struct QuickQuestionButton: View {
    let question: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                
                Text(question)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.yellow.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }
}

// MARK: - Keyboard Observer

private final class KeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboard(notification:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboard(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleKeyboard(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let frame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return
        }

        let keyboardVisible = frame.origin.y < UIScreen.main.bounds.height

        DispatchQueue.main.async {
            self.height = keyboardVisible ? frame.height : 0
        }
    }
}
