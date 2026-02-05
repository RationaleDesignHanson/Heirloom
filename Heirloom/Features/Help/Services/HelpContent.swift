import Foundation

/// FAQ item for frequently asked questions
struct FAQItem: Identifiable, Codable {
    let id: String
    let question: String
    let answer: String
    let section: HelpSection

    init(question: String, answer: String, section: HelpSection) {
        self.id = UUID().uuidString
        self.question = question
        self.answer = answer
        self.section = section
    }

    enum CodingKeys: String, CodingKey {
        case id, question, answer, section
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.question = try container.decode(String.self, forKey: .question)
        self.answer = try container.decode(String.self, forKey: .answer)
        let sectionKey = try container.decode(String.self, forKey: .section)
        self.section = HelpSection(fromKey: sectionKey)
    }
}

/// JSON container for FAQ items
struct FAQContainer: Codable {
    let items: [FAQItemJSON]
}

struct FAQItemJSON: Codable {
    let question: String
    let answer: String
    let section: String

    func toFAQItem() -> FAQItem {
        FAQItem(question: question, answer: answer, section: HelpSection(fromKey: section))
    }
}

/// Central repository for all help articles and FAQ content
/// Content is loaded from JSON resource files for easier maintenance
final class HelpContent {

    // MARK: - Singleton

    static let shared = HelpContent()

    // MARK: - Cached Content

    private var _allArticles: [HelpArticle]?
    private var _articlesBySection: [HelpSection: [HelpArticle]]?
    private var _faqItems: [FAQItem]?

    // MARK: - All Articles

    /// All help articles organized by section
    var allArticles: [HelpArticle] {
        if let cached = _allArticles {
            return cached
        }
        let articles = loadAllArticles()
        _allArticles = articles
        return articles
    }

    /// Articles grouped by section
    var articlesBySection: [HelpSection: [HelpArticle]] {
        if let cached = _articlesBySection {
            return cached
        }
        var grouped: [HelpSection: [HelpArticle]] = [:]
        for article in allArticles {
            grouped[article.section, default: []].append(article)
        }
        _articlesBySection = grouped
        return grouped
    }

    // MARK: - Section Accessors

    var gettingStartedArticles: [HelpArticle] {
        articlesBySection[.gettingStarted] ?? []
    }

    var recipeArticles: [HelpArticle] {
        articlesBySection[.recipes] ?? []
    }

    var shoppingListArticles: [HelpArticle] {
        articlesBySection[.shoppingLists] ?? []
    }

    var cardPersonalizationArticles: [HelpArticle] {
        articlesBySection[.cardPersonalization] ?? []
    }

    var advancedFeaturesArticles: [HelpArticle] {
        articlesBySection[.advancedFeatures] ?? []
    }

    var troubleshootingArticles: [HelpArticle] {
        articlesBySection[.troubleshooting] ?? []
    }

    /// Get articles for a specific section
    func articles(for section: HelpSection) -> [HelpArticle] {
        articlesBySection[section] ?? []
    }

    // MARK: - FAQ

    /// All FAQ items
    var faqItems: [FAQItem] {
        if let cached = _faqItems {
            return cached
        }
        let items = loadFAQItems()
        _faqItems = items
        return items
    }

    /// Search FAQ items
    func searchFAQ(_ query: String) -> [FAQItem] {
        guard !query.isEmpty else { return faqItems }
        let lowercaseQuery = query.lowercased()
        return faqItems.filter {
            $0.question.lowercased().contains(lowercaseQuery) ||
            $0.answer.lowercased().contains(lowercaseQuery)
        }
    }

    // MARK: - Loading

    /// Load all articles from JSON resource files
    private func loadAllArticles() -> [HelpArticle] {
        var articles: [HelpArticle] = []

        let sectionFiles: [(String, HelpSection)] = [
            ("help-getting-started", .gettingStarted),
            ("help-recipes", .recipes),
            ("help-shopping-lists", .shoppingLists),
            ("help-card-personalization", .cardPersonalization),
            ("help-advanced-features", .advancedFeatures),
            ("help-troubleshooting", .troubleshooting)
        ]

        for (filename, section) in sectionFiles {
            let sectionArticles = loadArticles(from: filename, section: section)
            articles.append(contentsOf: sectionArticles)
        }

        Log.info("Loaded help articles from JSON", category: .general, metadata: ["count": articles.count])
        return articles
    }

    /// Load FAQ items from JSON file
    private func loadFAQItems() -> [FAQItem] {
        guard let url = Bundle.main.url(forResource: "help-faq", withExtension: "json") else {
            Log.warning("FAQ content file not found", category: .general)
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let container = try JSONDecoder().decode(FAQContainer.self, from: data)
            let items = container.items.map { $0.toFAQItem() }
            Log.info("Loaded FAQ items from JSON", category: .general, metadata: ["count": items.count])
            return items
        } catch {
            Log.error("Failed to load FAQ content", category: .general, metadata: [
                "error": error.localizedDescription
            ])
            return []
        }
    }

    /// Load articles from a specific JSON file
    private func loadArticles(from filename: String, section: HelpSection) -> [HelpArticle] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            Log.warning("Help content file not found", category: .general, metadata: ["filename": filename])
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let container = try JSONDecoder().decode(HelpArticleContainer.self, from: data)
            return container.articles.map { $0.toHelpArticle(section: section) }
        } catch {
            Log.error("Failed to load help content", category: .general, metadata: [
                "filename": filename,
                "error": error.localizedDescription
            ])
            return []
        }
    }

    // MARK: - Search

    /// Search articles by query
    func search(_ query: String) -> [HelpArticle] {
        guard !query.isEmpty else { return [] }
        return allArticles.filter { $0.matches(query) }
    }

    /// Get article by ID
    func article(withId id: String) -> HelpArticle? {
        allArticles.first { $0.id == id }
    }

    /// Get related articles for an article
    func relatedArticles(for article: HelpArticle) -> [HelpArticle] {
        article.relatedArticles.compactMap { self.article(withId: $0) }
    }

    // MARK: - Cache Management

    /// Clear cached content (useful for testing or forcing reload)
    func clearCache() {
        _allArticles = nil
        _articlesBySection = nil
        _faqItems = nil
    }
}
