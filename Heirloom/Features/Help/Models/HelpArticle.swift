import Foundation

/// JSON container for loading help articles from resource files
struct HelpArticleContainer: Codable {
    let section: String
    let articles: [HelpArticleJSON]
}

/// JSON-decodable version of HelpArticle
struct HelpArticleJSON: Codable {
    let id: String
    let title: String
    let content: String
    let keywords: [String]
    let relatedArticles: [String]
    let icon: String

    func toHelpArticle(section: HelpSection) -> HelpArticle {
        HelpArticle(
            id: id,
            title: title,
            content: content,
            section: section,
            keywords: keywords,
            relatedArticles: relatedArticles,
            icon: icon
        )
    }
}

/// Represents a help article with content and metadata
struct HelpArticle: Identifiable, Hashable {
    let id: String
    let title: String
    let content: String
    let section: HelpSection
    let keywords: [String]
    let relatedArticles: [String] // Article IDs
    let icon: String // SF Symbol name

    init(
        id: String,
        title: String,
        content: String,
        section: HelpSection,
        keywords: [String] = [],
        relatedArticles: [String] = [],
        icon: String = "doc.text"
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.section = section
        self.keywords = keywords
        self.relatedArticles = relatedArticles
        self.icon = icon
    }

    /// Check if article matches search query
    func matches(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()

        // Check title
        if title.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Check content
        if content.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Check keywords
        if keywords.contains(where: { $0.lowercased().contains(lowercaseQuery) }) {
            return true
        }

        return false
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: HelpArticle, rhs: HelpArticle) -> Bool {
        lhs.id == rhs.id
    }
}

/// Help section categories
enum HelpSection: String, CaseIterable, Identifiable, Codable {
    case gettingStarted = "Getting Started"
    case recipes = "Recipes"
    case shoppingLists = "Shopping Lists"
    case cardPersonalization = "Card Personalization"
    case advancedFeatures = "Advanced Features"
    case troubleshooting = "Troubleshooting"

    var id: String { rawValue }

    /// Initialize from JSON key (camelCase)
    init(fromKey key: String) {
        switch key {
        case "gettingStarted": self = .gettingStarted
        case "recipes": self = .recipes
        case "shoppingLists": self = .shoppingLists
        case "cardPersonalization": self = .cardPersonalization
        case "advancedFeatures": self = .advancedFeatures
        case "troubleshooting": self = .troubleshooting
        default: self = .gettingStarted
        }
    }

    var icon: String {
        switch self {
        case .gettingStarted:
            return "hand.wave.fill"
        case .recipes:
            return "book.closed.fill"
        case .shoppingLists:
            return "cart.fill"
        case .cardPersonalization:
            return "paintbrush.fill"
        case .advancedFeatures:
            return "gearshape.2.fill"
        case .troubleshooting:
            return "wrench.and.screwdriver.fill"
        }
    }

    var description: String {
        switch self {
        case .gettingStarted:
            return "Learn the basics of using Heirloom"
        case .recipes:
            return "Adding, editing, and organizing recipes"
        case .shoppingLists:
            return "Creating and managing shopping lists"
        case .cardPersonalization:
            return "Styling your recipe cards"
        case .advancedFeatures:
            return "Scaling, collections, and sync"
        case .troubleshooting:
            return "Common issues and solutions"
        }
    }
}
