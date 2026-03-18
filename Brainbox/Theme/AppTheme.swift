import SwiftUI

// MARK: - Static Design Tokens (non-color)

enum AppTheme {
    static let radiusSmall: CGFloat = 6
    static let radiusMedium: CGFloat = 10
    static let radiusLarge: CGFloat = 16
    static let radiusXL: CGFloat = 20

    static let categories: [CategoryPill] = [
        CategoryPill(
            icon: "wand.and.stars",
            label: "Create",
            suggestions: [
                SuggestionPrompt(icon: "paintbrush.pointed", text: "Write a short story about a time traveler"),
                SuggestionPrompt(icon: "music.note", text: "Compose a poem about the ocean at night"),
                SuggestionPrompt(icon: "doc.text", text: "Draft a professional email to request a meeting"),
                SuggestionPrompt(icon: "lightbulb", text: "Brainstorm 10 creative startup ideas for 2026"),
            ]
        ),
        CategoryPill(
            icon: "safari",
            label: "Explore",
            suggestions: [
                SuggestionPrompt(icon: "globe", text: "What are the most fascinating unsolved mysteries in science?"),
                SuggestionPrompt(icon: "mountain.2", text: "Tell me about the deepest parts of the ocean"),
                SuggestionPrompt(icon: "sparkles", text: "How does quantum computing actually work?"),
                SuggestionPrompt(icon: "leaf", text: "What are the most unusual ecosystems on Earth?"),
            ]
        ),
        CategoryPill(
            icon: "chevron.left.forwardslash.chevron.right",
            label: "Code",
            suggestions: [
                SuggestionPrompt(icon: "swift", text: "Explain the difference between structs and classes in Swift"),
                SuggestionPrompt(icon: "terminal", text: "Write a Python script to automate file organization"),
                SuggestionPrompt(icon: "ladybug", text: "Help me debug a race condition in my async code"),
                SuggestionPrompt(icon: "cpu", text: "What are the best practices for REST API design?"),
            ]
        ),
        CategoryPill(
            icon: "book",
            label: "Learn",
            suggestions: [
                SuggestionPrompt(icon: "brain.head.profile", text: "Explain machine learning like I'm a beginner"),
                SuggestionPrompt(icon: "atom", text: "How does relativity affect GPS satellites?"),
                SuggestionPrompt(icon: "chart.line.uptrend.xyaxis", text: "Teach me the fundamentals of investing"),
                SuggestionPrompt(icon: "puzzlepiece", text: "What are the most important logical fallacies to know?"),
            ]
        ),
    ]

    /// Large pool of default suggestions — a random subset is picked each time
    static let suggestionPool: [SuggestionPrompt] = [
        SuggestionPrompt(icon: "sparkles", text: "How does AI work?"),
        SuggestionPrompt(icon: "globe", text: "Are black holes real?"),
        SuggestionPrompt(icon: "textformat.abc", text: "How many Rs are in the word \"strawberry\"?"),
        SuggestionPrompt(icon: "heart", text: "What is the meaning of life?"),
        SuggestionPrompt(icon: "bolt", text: "What causes lightning?"),
        SuggestionPrompt(icon: "moon.stars", text: "Why do we dream?"),
        SuggestionPrompt(icon: "leaf", text: "How do trees communicate with each other?"),
        SuggestionPrompt(icon: "drop", text: "Why is the ocean salty?"),
        SuggestionPrompt(icon: "brain.head.profile", text: "How does memory work in the human brain?"),
        SuggestionPrompt(icon: "flame", text: "What is the hottest temperature ever recorded?"),
        SuggestionPrompt(icon: "atom", text: "What is dark matter?"),
        SuggestionPrompt(icon: "airplane", text: "How do airplanes stay in the sky?"),
        SuggestionPrompt(icon: "ant", text: "How strong are ants compared to their size?"),
        SuggestionPrompt(icon: "waveform", text: "Can sound travel through space?"),
        SuggestionPrompt(icon: "clock", text: "Why does time feel like it speeds up as we age?"),
        SuggestionPrompt(icon: "mountain.2", text: "What's at the bottom of the Mariana Trench?"),
        SuggestionPrompt(icon: "sun.max", text: "How long will our Sun last?"),
        SuggestionPrompt(icon: "fossil.shell", text: "What caused the dinosaurs to go extinct?"),
        SuggestionPrompt(icon: "eye", text: "Why is the sky blue?"),
        SuggestionPrompt(icon: "puzzlepiece", text: "What is the Fermi Paradox?"),
        SuggestionPrompt(icon: "chart.line.uptrend.xyaxis", text: "How does compound interest work?"),
        SuggestionPrompt(icon: "questionmark.circle", text: "What happens inside a black hole?"),
        SuggestionPrompt(icon: "hare", text: "What is the fastest animal on Earth?"),
        SuggestionPrompt(icon: "snowflake", text: "Why are no two snowflakes alike?"),
    ]

    static func randomSuggestions(count: Int = 4) -> [SuggestionPrompt] {
        Array(suggestionPool.shuffled().prefix(count))
    }
}

struct SuggestionPrompt: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

struct CategoryPill: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    var suggestions: [SuggestionPrompt] = []
}
