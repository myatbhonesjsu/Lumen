//
//  EnhancedLearningHubView.swift
//  Lumen
//
//  AI-powered Learning Hub with chatbot and personalized recommendations
//

import SwiftUI
import Combine

struct EnhancedLearningHubView: View {
    @Binding var selectedMainTab: Int
    @Binding var requestedTab: LearningTab?
    @State private var selectedTab: LearningTab = .chat
    let tabBarHeight: CGFloat

    init(selectedMainTab: Binding<Int>, tabBarHeight: CGFloat, requestedTab: Binding<LearningTab?>) {
        self._selectedMainTab = selectedMainTab
        self.tabBarHeight = tabBarHeight
        self._requestedTab = requestedTab
    }

    enum LearningTab: String, CaseIterable {
        case chat = "Chat"
        case recommendations = "For You"
        case articles = "Articles"

        var icon: String {
            switch self {
            case .chat: return "message.fill"
            case .recommendations: return "star.fill"
            case .articles: return "book.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Tab Bar
                HStack(spacing: 0) {
                    ForEach(LearningTab.allCases, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                            }
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                    .font(.title3)

                                Text(tab.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(selectedTab == tab ? .yellow : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1),
                    alignment: .bottom
                )

                // Content
                ZStack {
                    if selectedTab == .chat {
                        CleanChatView(tabBarHeight: tabBarHeight)
                            .transition(.opacity)
                    } else if selectedTab == .recommendations {
                        LearningRecommendationsView()
                            .transition(.opacity)
                    } else if selectedTab == .articles {
                        ArticlesLibraryView()
                            .transition(.opacity)
                    }
                }
            }
            .navigationTitle("Learning Hub")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: requestedTab) { oldValue, newValue in
                // Update selected tab when requested tab changes
                if let newTab = newValue {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = newTab
                    }
                }
            }
        }
        .accessibilityIdentifier("learn.screen")
    }
}

// MARK: - Chatbot View

struct ChatbotView: View {
    let tabBarHeight: CGFloat
    @StateObject private var keyboardObserver = KeyboardObserver()
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var sessionId = UUID().uuidString
    @State private var relatedArticles: [ArticleRecommendation] = []
    @State private var selectedArticle: ArticleRecommendation?
    @FocusState private var isInputFocused: Bool

    @State private var suggestions: [String] = []
    @State private var suggestionTask: Task<Void, Never>? = nil
    private let baseInputPadding: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let safeBottom = proxy.safeAreaInsets.bottom
            let keyboardHeight = keyboardObserver.height
            let keyboardVisible = keyboardHeight > 0
            let keyboardOverlap = max(0, keyboardHeight - safeBottom)
            let containerBottomPadding = keyboardVisible ? keyboardOverlap : safeBottom + tabBarHeight
            let suggestionVisible = keyboardVisible && !suggestions.isEmpty
            let suggestionBlockHeight: CGFloat = suggestionVisible ? 72 : 0
            let scrollBottomPadding = containerBottomPadding + suggestionBlockHeight + baseInputPadding + 60

            ZStack(alignment: .bottom) {
                ScrollViewReader { proxyReader in
                    ScrollView {
                        VStack(spacing: 16) {
                            if messages.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.yellow)

                                    VStack(spacing: 8) {
                                        Text("Your AI Skincare Assistant")
                                            .font(.title2)
                                            .fontWeight(.bold)

                                        Text("Ask me anything about skincare, and I'll provide personalized advice based on your analysis history")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }

                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Try asking:")
                                            .font(.headline)
                                            .padding(.horizontal)

                                        ForEach(sampleQuestions, id: \.self) { question in
                                            SampleQuestionButton(question: question) {
                                                inputText = question
                                                sendMessage()
                                            }
                                        }
                                    }
                                    .padding(.top, 20)
                                }
                                .padding(.top, 48)
                            } else {
                                LazyVStack(spacing: 16) {
                                    ForEach(messages) { message in
                                        MessageBubble(message: message)
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
                                        .padding()
                                    }

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
                                        .padding(.top, 8)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, scrollBottomPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture { isInputFocused = false }
                        .onChange(of: messages.count) { _, _ in
                            if let lastMessage = messages.last {
                                withAnimation {
                                    proxyReader.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .background(Color(.systemBackground))
                }

                VStack(spacing: 0) {
                    Divider()

                    if suggestionVisible {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button(action: {
                                        inputText = suggestion
                                        isInputFocused = true
                                    }) {
                                        Text(suggestion)
                                            .font(.footnote)
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .background(Color(.systemBackground))

                        Divider().opacity(0.2)
                    }

                    HStack(spacing: 12) {
                        TextField("Ask about skincare...", text: $inputText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                            .lineLimit(1...4)
                            .submitLabel(.send)
                            .focused($isInputFocused)
                            .onSubmit { sendMessage() }

                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .yellow)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, baseInputPadding)
                }
                .background(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, y: -2)
                .padding(.bottom, containerBottomPadding)
            }
            .contentShape(Rectangle())
            .onTapGesture { isInputFocused = false }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .sheet(item: $selectedArticle) { article in
                ArticleWebView(article: article)
            }
        }
        .onChange(of: inputText) { _, newValue in
            scheduleSuggestionsFetch(for: newValue)
        }
        .onChange(of: keyboardObserver.height) { _, newValue in
            if newValue == 0 {
                suggestions = []
                suggestionTask?.cancel()
            }
        }
        .onDisappear {
            suggestionTask?.cancel()
        }
    }

    private var sampleQuestions: [String] {
        [
            "What's the best routine for my skin?",
            "How can I reduce my dark circles?",
            "Should I use retinol?",
            "What causes acne breakouts?"
        ]
    }

    private func scheduleSuggestionsFetch(for text: String) {
        suggestionTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 2 {
            suggestions = []
            return
        }

        suggestionTask = Task { [trimmed] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }

            do {
                let fetched = try await LearningHubService.shared.fetchAutocompleteSuggestions(prefix: trimmed)
                if Task.isCancelled { return }
                await MainActor.run {
                    if fetched.isEmpty {
                        suggestions = fallbackSuggestions(for: trimmed)
                    } else {
                        suggestions = fetched
                    }
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    suggestions = fallbackSuggestions(for: trimmed)
                }
            }
        }
    }

    private func fallbackSuggestions(for query: String) -> [String] {
        let pool = sampleQuestions
        let lowered = query.lowercased()
        let filtered = pool.filter { $0.lowercased().contains(lowered) }
        if filtered.isEmpty {
            return Array(pool.prefix(6))
        }
        return Array(filtered.prefix(6))
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        isInputFocused = false
        suggestions = []
        suggestionTask?.cancel()

        let userMessage = ChatMessage(
            role: "user",
            message: trimmed
        )

        messages.append(userMessage)
        inputText = ""
        isLoading = true

        Task {
            do {
                let response = try await LearningHubService.shared.sendMessage(
                    message: userMessage.message,
                    sessionId: sessionId
                )

                await MainActor.run {
                    let assistantMessage = ChatMessage(
                        role: "assistant",
                        message: response.response,
                        sources: response.sources
                    )
                    messages.append(assistantMessage)
                    relatedArticles = response.relatedArticles
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(
                        role: "assistant",
                        message: "I'm sorry, I encountered an error. Please try again."
                    )
                    messages.append(errorMessage)
                    isLoading = false
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 8) {
                Text(message.message)
                    .font(.body)
                    .foregroundColor(message.role == "user" ? .white : .primary)
                    .padding(12)
                    .background(message.role == "user" ? Color.yellow : Color(.systemGray6))
                    .cornerRadius(16)

                if let sources = message.sources, !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sources:")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ForEach(sources.indices, id: \.self) { index in
                            Text("• \(sources[index].source)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: 280, alignment: message.role == "user" ? .trailing : .leading)

            if message.role == "assistant" {
                Spacer()
            }
        }
    }
}

struct SampleQuestionButton: View {
    let question: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)

                Text(question)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

// MARK: - Recommendations View

struct LearningRecommendationsView: View {
    @State private var recommendations: PersonalizedRecommendations?
    @State private var isLoading = true
    @State private var selectedArticle: ArticleRecommendation?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)

                        Text("Personalized For You")
                            .font(.title3)
                            .fontWeight(.bold)
                    }

                    if let recs = recommendations {
                        Text("Based on your \(recs.totalAnalyses) skin analyses")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if !recs.basedOnConditions.isEmpty {
                            HStack {
                                Text("Focus areas:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                ForEach(recs.basedOnConditions, id: \.self) { condition in
                                    Text(condition.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.yellow.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal)
                .padding(.top)

                // Recommendations
                if isLoading {
                    ProgressView()
                        .tint(.yellow)
                        .padding()
                } else if let recs = recommendations {
                    LazyVStack(spacing: 16) {
                        ForEach(recs.recommendations) { article in
                            LearningArticleCard(article: article)
                                .onTapGesture {
                                    selectedArticle = article
                                }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        Text("No recommendations yet")
                            .font(.headline)

                        Text("Complete a skin analysis to get personalized article recommendations")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                }

                Spacer(minLength: 100)
            }
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await loadRecommendations()
        }
        .refreshable {
            await loadRecommendations()
        }
        .sheet(item: $selectedArticle) { article in
            ArticleWebView(article: article)
        }
    }

    private func loadRecommendations() async {
        isLoading = true
        do {
            recommendations = try await LearningHubService.shared.getPersonalizedRecommendations()
        } catch {
            let nsError = error as NSError
            if !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) {
                print("Error loading recommendations: \(error)")
            }
        }
        isLoading = false
    }
}

struct LearningArticleCard: View {
    let article: ArticleRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category badge
            HStack {
                Text(article.category)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(6)

                Spacer()

                if let matchScore = article.matchScore {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("\(matchScore) matches")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
            }

            Text(article.title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(article.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)

            HStack {
                Label(article.source, systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundColor(.blue)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct CompactArticleCard: View {
    let article: ArticleRecommendation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.title3)
                .foregroundColor(.yellow)
                .frame(width: 40, height: 40)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(article.source)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Articles Library View

struct ArticlesLibraryView: View {
    @State private var articles: [ArticleRecommendation] = []
    @State private var isLoading = true
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    @State private var selectedArticle: ArticleRecommendation?

    let categories = ["All", "Basics", "Ingredients", "Routines", "Conditions"]

    var filteredArticles: [ArticleRecommendation] {
        var filtered = articles

        if let category = selectedCategory, category != "All" {
            filtered = filtered.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.summary.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search articles...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding()

            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            selectedCategory = category == "All" ? nil : category
                        }) {
                            Text(category)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(
                                    (selectedCategory == category || (selectedCategory == nil && category == "All"))
                                    ? .white : .primary
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    (selectedCategory == category || (selectedCategory == nil && category == "All"))
                                    ? Color.yellow : Color(.systemGray6)
                                )
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)

            // Articles List
            if isLoading {
                ProgressView()
                    .tint(.yellow)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredArticles) { article in
                            LearningArticleCard(article: article)
                                .onTapGesture {
                                    selectedArticle = article
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await loadArticles()
        }
        .sheet(item: $selectedArticle) { article in
            ArticleWebView(article: article)
        }
    }

    private func loadArticles() async {
        isLoading = true
        do {
            articles = try await LearningHubService.shared.getArticles()
        } catch {
            print("Error loading articles: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Article Web View

struct ArticleWebView: View {
    @Environment(\.dismiss) private var dismiss
    let article: ArticleRecommendation

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(article.category)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.yellow)

                        Text(article.title)
                            .font(.title)
                            .fontWeight(.bold)

                        HStack {
                            Label(article.source, systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.blue)

                            Spacer()
                        }
                    }
                    .padding()

                    Divider()

                    // Summary
                    Text(article.summary)
                        .font(.body)
                        .padding()

                    // Open in Browser Button
                    Link(destination: URL(string: article.url)!) {
                        HStack {
                            Image(systemName: "safari")
                            Text("Read Full Article")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.yellow)
                        .cornerRadius(12)
                        .padding()
                    }

                    Spacer()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

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

#Preview {
    EnhancedLearningHubView(
        selectedMainTab: .constant(3),
        tabBarHeight: 80,
        requestedTab: .constant(nil)
    )
}
