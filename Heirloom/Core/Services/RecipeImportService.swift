import Foundation
import SwiftSoup

/// Service for importing recipes from URLs
class RecipeImportService {
    init() {}

    /// Import a recipe from a URL
    func importRecipe(from urlString: String) async throws -> ImportedRecipe {
        // Clean up URL (trim whitespace, remove invisible characters)
        let cleanedURL = urlString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{200B}", with: "") // Zero-width space
            .replacingOccurrences(of: "\u{FEFF}", with: "") // Byte order mark

        Log.info("Starting recipe import", category: .network, metadata: ["url": cleanedURL])

        // Validate URL
        guard let url = URL(string: cleanedURL) else {
            Log.error("Invalid URL for import", category: .network, metadata: ["url": cleanedURL])
            throw ImportError.invalidURL
        }

        // Detect site
        let site = detectSite(from: url)
        Log.info("Detected recipe site", category: .network, metadata: ["site": site.rawValue])

        // Fetch HTML
        Log.debug("Fetching HTML from URL", category: .network)
        let html = try await fetchHTML(from: url)
        Log.debug("Fetched HTML content", category: .network, metadata: ["sizeBytes": html.count])

        // Check for site-specific issues
        try checkSiteSpecificIssues(html: html, site: site)

        // Parse recipe data
        Log.debug("Parsing recipe data", category: .network)
        let recipe = try parseRecipe(from: html, sourceURL: urlString, site: site)
        Log.info("Successfully parsed recipe", category: .network, metadata: ["title": recipe.title])
        return recipe
    }

    // MARK: - Site Detection

    enum RecipeSite: String {
        case nytCooking = "NYT Cooking"
        case foodNetwork = "Food Network"
        case bonAppetit = "Bon Appétit"
        case allRecipes = "AllRecipes"
        case seriousEats = "Serious Eats"
        case unknown = "Unknown"
    }

    private func detectSite(from url: URL) -> RecipeSite {
        guard let host = url.host() else { return .unknown }

        let lowercasedHost = host.lowercased()

        if lowercasedHost.contains("nytimes.com") {
            return .nytCooking
        } else if lowercasedHost.contains("foodnetwork.com") {
            return .foodNetwork
        } else if lowercasedHost.contains("bonappetit.com") {
            return .bonAppetit
        } else if lowercasedHost.contains("allrecipes.com") {
            return .allRecipes
        } else if lowercasedHost.contains("seriouseats.com") {
            return .seriousEats
        }

        return .unknown
    }

    private func checkSiteSpecificIssues(html: String, site: RecipeSite) throws {
        switch site {
        case .nytCooking:
            // Check for NYT paywall
            if html.contains("nytcooking-paywall") || html.contains("paywall-bar") {
                Log.warning("NYT paywall detected", category: .network)
                throw ImportError.paywallDetected
            }
        default:
            break
        }
    }

    // MARK: - Private Methods

    private func fetchHTML(from url: URL) async throws -> String {
        // Configure request with proper headers to avoid being blocked
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            Log.error("Invalid HTTP response type", category: .network)
            throw ImportError.networkError
        }

        Log.debug("Received HTTP response", category: .network, metadata: ["statusCode": httpResponse.statusCode])

        guard (200...299).contains(httpResponse.statusCode) else {
            Log.error("HTTP error", category: .network, metadata: ["statusCode": httpResponse.statusCode])
            throw ImportError.networkError
        }

        guard let html = String(data: data, encoding: .utf8) else {
            Log.error("Failed to decode HTML response", category: .network)
            throw ImportError.invalidHTML
        }

        return html
    }

    private func parseRecipe(from html: String, sourceURL: String, site: RecipeSite) throws -> ImportedRecipe {
        let doc = try SwiftSoup.parse(html)

        // Try schema.org JSON-LD first (most reliable)
        Log.debug("Looking for JSON-LD recipe data", category: .network)
        if let recipe = try? parseJSONLD(from: doc) {
            Log.info("Found JSON-LD recipe data", category: .network)
            var result = recipe
            result.sourceURL = sourceURL
            return result
        }
        Log.debug("No JSON-LD recipe data found", category: .network)

        // Try site-specific parsers
        Log.debug("Trying site-specific parser", category: .network, metadata: ["site": site.rawValue])
        if let recipe = try? parseSiteSpecific(from: doc, site: site) {
            Log.info("Site-specific parser succeeded", category: .network)
            var result = recipe
            result.sourceURL = sourceURL
            return result
        }
        Log.debug("Site-specific parser failed", category: .network)

        // Fallback to microdata/HTML parsing
        Log.debug("Trying microdata fallback", category: .network)
        if let recipe = try? parseMicrodata(from: doc) {
            Log.info("Found microdata recipe data", category: .network)
            var result = recipe
            result.sourceURL = sourceURL
            return result
        }
        Log.warning("No microdata recipe data found", category: .network)

        throw ImportError.noRecipeFound
    }

    // MARK: - Site-Specific Parsers

    private func parseSiteSpecific(from doc: Document, site: RecipeSite) throws -> ImportedRecipe {
        switch site {
        case .foodNetwork:
            return try parseFoodNetwork(from: doc)
        case .bonAppetit:
            return try parseBonAppetit(from: doc)
        default:
            throw ImportError.noRecipeFound
        }
    }

    private func parseFoodNetwork(from doc: Document) throws -> ImportedRecipe {
        // Food Network sometimes has non-standard JSON-LD
        // Try alternate selectors
        var recipe = ImportedRecipe()

        // Title - try multiple selectors
        if let title = try? doc.select("h1.o-AssetTitle__a-HeadlineText").first()?.text() {
            recipe.title = title.decodingHTMLEntities()
        }

        // Ingredients - Food Network uses specific classes
        let ingredientElements = try doc.select("div.o-Ingredients__a-Ingredient")
        recipe.ingredients = ingredientElements.compactMap { try? $0.text() }

        // Instructions - look for step-by-step
        let instructionElements = try doc.select("li.o-Method__m-Step")
        recipe.instructions = instructionElements.compactMap { try? $0.text() }

        // Only return if we have minimum viable data
        guard !recipe.title.isEmpty && !recipe.ingredients.isEmpty else {
            throw ImportError.noRecipeFound
        }

        return recipe
    }

    private func parseBonAppetit(from doc: Document) throws -> ImportedRecipe {
        // Bon Appétit uses React-based rendering, JSON-LD should work
        // This is a fallback for edge cases
        var recipe = ImportedRecipe()

        // Title
        if let title = try? doc.select("h1[data-testid=ContentHeaderHed]").first()?.text() {
            recipe.title = title.decodingHTMLEntities()
        }

        // Ingredients - Bon Appétit uses data-testid
        let ingredientElements = try doc.select("div[data-testid=IngredientList] p")
        recipe.ingredients = ingredientElements.compactMap { try? $0.text() }

        // Instructions
        let instructionElements = try doc.select("div[data-testid=InstructionsWrapper] li")
        recipe.instructions = instructionElements.compactMap { try? $0.text() }

        guard !recipe.title.isEmpty && !recipe.ingredients.isEmpty else {
            throw ImportError.noRecipeFound
        }

        return recipe
    }

    // MARK: - JSON-LD Parsing (Schema.org)

    private func parseJSONLD(from doc: Document) throws -> ImportedRecipe {
        // Find script tags with type="application/ld+json"
        let scripts = try doc.select("script[type=application/ld+json]")

        Log.debug("Found JSON-LD script tags", category: .network, metadata: ["count": scripts.count])

        for (index, script) in scripts.enumerated() {
            let jsonText = try script.html()
            guard let jsonData = jsonText.data(using: .utf8) else {
                Log.debug("Failed to get data from script tag", category: .network, metadata: ["scriptIndex": index])
                continue
            }

            Log.debug("Parsing JSON-LD script", category: .network, metadata: ["scriptIndex": index])
            if let recipe = try? parseRecipeJSON(from: jsonData) {
                Log.info("Found recipe in JSON-LD script", category: .network, metadata: ["scriptIndex": index])
                return recipe
            } else {
                Log.debug("No recipe data in script", category: .network, metadata: ["scriptIndex": index])
            }
        }

        throw ImportError.noRecipeFound
    }

    private func parseRecipeJSON(from data: Data) throws -> ImportedRecipe {
        let jsonObject = try JSONSerialization.jsonObject(with: data)

        // Handle array of JSON-LD objects (e.g., [Recipe, BreadcrumbList, Organization])
        if let jsonArray = jsonObject as? [[String: Any]] {
            Log.debug("Found JSON array in JSON-LD", category: .network, metadata: ["itemCount": jsonArray.count])
            for item in jsonArray {
                if isRecipeType(item) {
                    Log.info("Found Recipe in JSON array", category: .network)
                    return parseRecipeDict(item)
                }
            }
        }

        // Handle single JSON-LD object
        if let json = jsonObject as? [String: Any] {
            // Handle @graph array (some sites use this)
            if let graph = json["@graph"] as? [[String: Any]] {
                Log.debug("Found @graph in JSON-LD", category: .network, metadata: ["itemCount": graph.count])
                for item in graph {
                    if isRecipeType(item) {
                        Log.info("Found Recipe in @graph", category: .network)
                        return parseRecipeDict(item)
                    }
                }
            }

            // Handle direct Recipe object
            if isRecipeType(json) {
                Log.info("Found direct Recipe object", category: .network)
                return parseRecipeDict(json)
            }
        }

        Log.debug("JSON structure doesn't contain Recipe", category: .network)
        throw ImportError.noRecipeFound
    }

    private func isRecipeType(_ dict: [String: Any]) -> Bool {
        // @type can be a String or Array of Strings
        if let typeString = dict["@type"] as? String {
            return typeString == "Recipe"
        }
        if let typeArray = dict["@type"] as? [String] {
            return typeArray.contains("Recipe")
        }
        return false
    }

    private func parseRecipeDict(_ dict: [String: Any]) -> ImportedRecipe {
        var recipe = ImportedRecipe()

        // Title
        recipe.title = (dict["name"] as? String ?? "").decodingHTMLEntities()

        // Image
        if let imageData = dict["image"] {
            if let imageString = imageData as? String {
                recipe.imageURL = imageString
            } else if let imageDict = imageData as? [String: Any],
                      let url = imageDict["url"] as? String {
                recipe.imageURL = url
            } else if let imageArray = imageData as? [Any],
                      let firstImage = imageArray.first {
                if let url = firstImage as? String {
                    recipe.imageURL = url
                } else if let dict = firstImage as? [String: Any],
                          let url = dict["url"] as? String {
                    recipe.imageURL = url
                }
            }
        }

        // Description
        recipe.description = dict["description"] as? String

        // Servings
        if let yield = dict["recipeYield"] {
            if let yieldInt = yield as? Int {
                recipe.servings = "\(yieldInt) servings"
            } else if let yieldString = yield as? String {
                recipe.servings = yieldString
            } else if let yieldArray = yield as? [Any],
                      let first = yieldArray.first as? String {
                recipe.servings = first
            }
        }

        // Prep Time
        if let prepTime = dict["prepTime"] as? String {
            recipe.prepTime = formatDuration(prepTime)
        }

        // Cook Time
        if let cookTime = dict["cookTime"] as? String {
            recipe.cookTime = formatDuration(cookTime)
        }

        // Total Time (fallback if prep/cook not available)
        if let totalTime = dict["totalTime"] as? String,
           recipe.prepTime == nil && recipe.cookTime == nil {
            recipe.cookTime = formatDuration(totalTime)
        }

        // Ingredients
        if let ingredients = dict["recipeIngredient"] as? [String] {
            recipe.ingredients = ingredients
        } else if let ingredients = dict["ingredients"] as? [String] {
            recipe.ingredients = ingredients
        }

        // Instructions
        if let instructions = dict["recipeInstructions"] {
            recipe.instructions = parseInstructions(instructions)
        }

        return recipe
    }

    private func parseInstructions(_ data: Any) -> [String] {
        var steps: [String] = []

        if let instructionsString = data as? String {
            // Single string, split by newlines or periods
            steps = instructionsString
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else if let instructionsArray = data as? [Any] {
            for item in instructionsArray {
                if let stepString = item as? String {
                    steps.append(stepString)
                } else if let stepDict = item as? [String: Any] {
                    // HowToStep format
                    if let text = stepDict["text"] as? String {
                        steps.append(text)
                    }
                }
            }
        }

        // Filter out comment-like text
        return steps.filter { looksLikeInstruction($0) }
    }

    /// Check if text looks like a recipe instruction (not a user comment)
    private func looksLikeInstruction(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        // Exclude comment patterns (first-person narratives, reviews)
        let commentPatterns = [
            "i love", "i loved", "i tried", "i made", "i recommend",
            "we love", "we loved", "we tried", "my favorite",
            "these are amazing", "these were amazing", "this is delicious",
            "thank you for", "thank you so much",
            "can't wait to", "just made this", "turned out great",
            "so good", "very delicious", "will make again",
            "my family loved", "my kids loved", "my husband loved"
        ]

        for pattern in commentPatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }

        // Prefer imperative mood (typical recipe instructions)
        let instructionPrefixes = [
            "preheat", "heat", "warm", "cool",
            "mix", "combine", "blend", "stir", "whisk", "beat", "fold",
            "add", "pour", "place", "put", "set", "arrange",
            "bake", "cook", "roast", "grill", "fry", "sauté", "boil", "simmer",
            "chill", "refrigerate", "freeze", "rest", "let sit",
            "remove", "transfer", "drain", "strain",
            "cut", "chop", "slice", "dice", "mince",
            "season", "sprinkle", "garnish", "top",
            "in a bowl", "in a pan", "in a pot", "in a skillet"
        ]

        for prefix in instructionPrefixes {
            if lowercased.hasPrefix(prefix) {
                return true
            }
        }

        // Also check for time/temperature measurements
        let hasTimeOrTemp = lowercased.range(of: #"(\d+\s*(minute|hour|degree|°f|°c))"#, options: .regularExpression) != nil

        return hasTimeOrTemp
    }

    // MARK: - Microdata Parsing (Fallback)

    private func parseMicrodata(from doc: Document) throws -> ImportedRecipe {
        var recipe = ImportedRecipe()

        // Try to find recipe container
        guard let container = try? doc.select("[itemtype*=Recipe]").first() else {
            throw ImportError.noRecipeFound
        }

        // Title
        if let titleElement = try? container.select("[itemprop=name]").first() {
            recipe.title = try titleElement.text().decodingHTMLEntities()
        }

        // Image
        if let imgElement = try? container.select("[itemprop=image]").first() {
            recipe.imageURL = try? imgElement.attr("src")
        }

        // Ingredients
        let ingredientElements = try container.select("[itemprop=recipeIngredient]")
        recipe.ingredients = ingredientElements.compactMap { try? $0.text() }

        // Instructions
        let instructionElements = try container.select("[itemprop=recipeInstructions]")
        if let instructionsText = try? instructionElements.first()?.text() {
            recipe.instructions = instructionsText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        return recipe
    }

    // MARK: - Utilities

    private func formatDuration(_ isoDuration: String) -> String {
        // Parse ISO 8601 duration (e.g., "PT30M" = 30 minutes)
        let duration = isoDuration.replacingOccurrences(of: "PT", with: "")

        var result = ""

        // Hours
        if let hoursRange = duration.range(of: #"(\d+)H"#, options: .regularExpression) {
            let hours = String(duration[hoursRange]).replacingOccurrences(of: "H", with: "")
            result += "\(hours)h "
        }

        // Minutes
        if let minutesRange = duration.range(of: #"(\d+)M"#, options: .regularExpression) {
            let minutes = String(duration[minutesRange]).replacingOccurrences(of: "M", with: "")
            result += "\(minutes)m"
        }

        return result.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Imported Recipe Model

struct ImportedRecipe {
    var title: String = ""
    var description: String?
    var imageURL: String?
    var sourceURL: String = ""
    var author: String?
    var servings: String?
    var prepTime: String?
    var cookTime: String?
    var ingredients: [String] = []
    var instructions: [String] = []

    var isValid: Bool {
        !title.isEmpty && !ingredients.isEmpty && !instructions.isEmpty
    }
}

// MARK: - String Extension for HTML Entity Decoding

extension String {
    /// Decode HTML entities like &#39; (apostrophe), &quot;, &amp;, etc.
    func decodingHTMLEntities() -> String {
        guard let data = self.data(using: .utf8) else { return self }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return self
        }

        return attributedString.string
    }
}

// MARK: - Import Errors

enum ImportError: LocalizedError {
    case invalidURL
    case networkError
    case invalidHTML
    case noRecipeFound
    case parsingFailed
    case paywallDetected

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL. Please enter a valid recipe URL."
        case .networkError:
            return "Failed to fetch recipe. Please check your internet connection."
        case .invalidHTML:
            return "Unable to read recipe page. The website may be unavailable."
        case .noRecipeFound:
            return "No recipe found on this page. Make sure the URL points to a recipe."
        case .parsingFailed:
            return "Failed to parse recipe data. This website may not be supported."
        case .paywallDetected:
            return "This recipe is behind a paywall. Please log in on the website and try again."
        }
    }
}
