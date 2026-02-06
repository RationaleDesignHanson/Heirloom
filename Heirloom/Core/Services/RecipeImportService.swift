import Foundation
import SwiftSoup

/// Service for importing recipes from URLs
class RecipeImportService {
    private let session: URLSession

    init() {
        // Configure URLSession with connectivity handling
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true  // Wait for network instead of failing immediately
        self.session = URLSession(configuration: config)
    }

    /// Import a recipe from a URL
    func importRecipe(from urlString: String) async throws -> ImportedRecipe {
        // Clean up URL (trim whitespace, remove invisible characters)
        let cleanedURL = urlString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{200B}", with: "") // Zero-width space
            .replacingOccurrences(of: "\u{FEFF}", with: "") // Byte order mark

        Log.info("Starting recipe import", category: .network, metadata: ["url": cleanedURL])

        // TODO: Phase B - Add PendingURLImportManager for interrupted import resume

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
        case smittenKitchen = "Smitten Kitchen"
        case wpRecipeMaker = "WP Recipe Maker"  // Generic WPRM plugin support
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
        } else if lowercasedHost.contains("smittenkitchen.com") {
            return .smittenKitchen
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

        let (data, response) = try await session.data(for: request)

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

        // First, strip comment sections to improve all parsers
        stripCommentSections(from: doc)

        // Try schema.org JSON-LD first (most reliable)
        Log.debug("Looking for JSON-LD recipe data", category: .network)
        if var recipe = try? parseJSONLD(from: doc) {
            Log.info("Found JSON-LD recipe data", category: .network)
            recipe.sourceURL = sourceURL

            // If JSON-LD has no image, try to supplement from site-specific parser
            if recipe.imageURL == nil || recipe.imageURL?.isEmpty == true {
                Log.debug("JSON-LD has no image, trying site-specific image extraction", category: .network)
                if let supplementalImage = try? extractImageFromSite(doc: doc, site: site) {
                    recipe.imageURL = supplementalImage
                    Log.info("Supplemented JSON-LD with site-specific image", category: .network, metadata: ["imageURL": supplementalImage])
                }
            }

            return recipe
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

        // Try WP Recipe Maker plugin (common on WordPress food blogs)
        Log.debug("Trying WP Recipe Maker parser", category: .network)
        if let recipe = try? parseWPRecipeMaker(from: doc) {
            Log.info("WP Recipe Maker parser succeeded", category: .network)
            var result = recipe
            result.sourceURL = sourceURL
            return result
        }
        Log.debug("No WP Recipe Maker data found", category: .network)

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

    /// Strip comment sections from HTML to prevent them from being parsed as recipe content
    private func stripCommentSections(from doc: Document) {
        // Common comment section selectors
        let commentSelectors = [
            "#comments",
            "#respond",
            ".comments-area",
            ".comment-section",
            ".wp-comments",
            "#jp-relatedposts",
            ".sharedaddy",
            ".social-share",
            ".post-navigation",
            "footer"
        ]

        for selector in commentSelectors {
            do {
                let elements = try doc.select(selector)
                for element in elements {
                    try element.remove()
                }
            } catch {
                // Ignore selector errors
            }
        }

        Log.debug("Stripped comment sections from HTML", category: .network)
    }

    // MARK: - Site-Specific Image Extraction

    /// Extract just the image URL from site-specific selectors (for supplementing JSON-LD)
    private func extractImageFromSite(doc: Document, site: RecipeSite) throws -> String? {
        Log.debug("Extracting image for site", category: .network, metadata: ["site": site.rawValue])

        switch site {
        case .smittenKitchen:
            // Try WP Recipe Maker image first
            if let imgElement = try? doc.select(".wprm-recipe-image img").first() {
                if let src = extractImageSrc(from: imgElement) {
                    Log.debug("Found WPRM image", category: .network, metadata: ["src": src])
                    return src
                }
            }
            // IMPORTANT: Only look within .entry-content to avoid sidebar/header promo images
            // Try WordPress block image within entry-content
            if let imgElement = try? doc.select(".entry-content .wp-block-image img, .entry-content figure.wp-block-image img").first() {
                if let src = extractImageSrc(from: imgElement) {
                    Log.debug("Found wp-block-image in entry-content", category: .network, metadata: ["src": src])
                    return src
                }
            }
            // Try images with wp-image class within entry-content
            if let imgElement = try? doc.select(".entry-content img[class*='wp-image-']").first() {
                if let src = extractImageSrc(from: imgElement) {
                    Log.debug("Found wp-image class in entry-content", category: .network, metadata: ["src": src])
                    return src
                }
            }
            // Smitten Kitchen fallback - first large image from entry-content
            if let imgElement = try? doc.select(".entry-content img[class*='size-full'], .entry-content img[class*='size-large']").first() {
                if let src = extractImageSrc(from: imgElement) {
                    Log.debug("Found entry-content large image", category: .network, metadata: ["src": src])
                    return src
                }
            }
            // Final fallback - first non-icon image in entry-content
            if let imgElements = try? doc.select(".entry-content img") {
                for imgElement in imgElements {
                    if let src = extractImageSrc(from: imgElement) {
                        let lowercaseSrc = src.lowercased()
                        if !lowercaseSrc.contains("emoji") &&
                           !lowercaseSrc.contains("icon") &&
                           !lowercaseSrc.contains("pixel") &&
                           !lowercaseSrc.contains("avatar") {
                            Log.debug("Found entry-content fallback image", category: .network, metadata: ["src": src])
                            return src
                        }
                    }
                }
            }
        default:
            // For other sites, try common selectors
            if let imgElement = try? doc.select(".recipe-image img, .hero-image img, .post-image img, article img").first() {
                if let src = extractImageSrc(from: imgElement) {
                    return src
                }
            }
        }
        Log.debug("No image found for site", category: .network, metadata: ["site": site.rawValue])
        return nil
    }

    /// Extract image URL from element, checking multiple attributes (src, data-src, data-lazy-src, srcset)
    private func extractImageSrc(from element: Element) -> String? {
        // Try standard src first
        if let src = try? element.attr("src"), !src.isEmpty, !src.contains("data:image") {
            return src
        }
        // Try data-src (lazy loading)
        if let dataSrc = try? element.attr("data-src"), !dataSrc.isEmpty {
            return dataSrc
        }
        // Try data-lazy-src (another lazy loading pattern)
        if let lazyDataSrc = try? element.attr("data-lazy-src"), !lazyDataSrc.isEmpty {
            return lazyDataSrc
        }
        // Try srcset and get the first/largest image
        if let srcset = try? element.attr("srcset"), !srcset.isEmpty {
            // srcset format: "url1 300w, url2 600w, url3 1200w"
            // Get the last (usually largest) image
            let sources = srcset.components(separatedBy: ",")
            if let lastSource = sources.last?.trimmingCharacters(in: .whitespaces) {
                let urlPart = lastSource.components(separatedBy: " ").first
                if let url = urlPart, !url.isEmpty {
                    return url
                }
            }
        }
        return nil
    }

    // MARK: - Site-Specific Parsers

    private func parseSiteSpecific(from doc: Document, site: RecipeSite) throws -> ImportedRecipe {
        switch site {
        case .foodNetwork:
            return try parseFoodNetwork(from: doc)
        case .bonAppetit:
            return try parseBonAppetit(from: doc)
        case .smittenKitchen:
            return try parseSmittenKitchen(from: doc)
        case .wpRecipeMaker:
            return try parseWPRecipeMaker(from: doc)
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

    private func parseSmittenKitchen(from doc: Document) throws -> ImportedRecipe {
        // Smitten Kitchen uses WP Recipe Maker on newer posts, but older posts
        // have recipes embedded in .entry-content prose
        var recipe = ImportedRecipe()

        // Try WP Recipe Maker first (newer posts)
        if let wprmRecipe = try? parseWPRecipeMaker(from: doc) {
            return wprmRecipe
        }

        // Title from post title
        if let title = try? doc.select(".entry-title, h1.title, h2.title").first()?.text() {
            recipe.title = title.decodingHTMLEntities()
        }

        // Image extraction - IMPORTANT: Only look within .entry-content to avoid sidebar/header images
        // Try WordPress block image within entry-content
        if let imgElement = try? doc.select(".entry-content .wp-block-image img, .entry-content figure.wp-block-image img").first() {
            recipe.imageURL = extractImageSrc(from: imgElement)
            if recipe.imageURL != nil {
                Log.debug("Found Smitten Kitchen wp-block-image in entry-content", category: .network, metadata: ["url": recipe.imageURL ?? ""])
            }
        }
        // Try images with wp-image class within entry-content
        if recipe.imageURL == nil {
            if let imgElement = try? doc.select(".entry-content img[class*='wp-image-']").first() {
                recipe.imageURL = extractImageSrc(from: imgElement)
                if recipe.imageURL != nil {
                    Log.debug("Found Smitten Kitchen wp-image class in entry-content", category: .network, metadata: ["url": recipe.imageURL ?? ""])
                }
            }
        }
        // Try large images in entry-content
        if recipe.imageURL == nil {
            if let imgElement = try? doc.select(".entry-content img[class*='size-full'], .entry-content img[class*='size-large']").first() {
                recipe.imageURL = extractImageSrc(from: imgElement)
                if recipe.imageURL != nil {
                    Log.debug("Found Smitten Kitchen entry-content large image", category: .network, metadata: ["url": recipe.imageURL ?? ""])
                }
            }
        }
        // Fallback to first image in entry-content (skip small icons by checking URL doesn't contain emoji/icon patterns)
        if recipe.imageURL == nil {
            let imgElements = try? doc.select(".entry-content img")
            if let elements = imgElements {
                for imgElement in elements {
                    if let src = extractImageSrc(from: imgElement) {
                        // Skip emoji, icons, and tracking pixels
                        let lowercaseSrc = src.lowercased()
                        if !lowercaseSrc.contains("emoji") &&
                           !lowercaseSrc.contains("icon") &&
                           !lowercaseSrc.contains("pixel") &&
                           !lowercaseSrc.contains("tracking") &&
                           !lowercaseSrc.contains("avatar") &&
                           !lowercaseSrc.contains("gravatar") {
                            recipe.imageURL = src
                            Log.debug("Found Smitten Kitchen fallback image in entry-content", category: .network, metadata: ["url": src])
                            break
                        }
                    }
                }
            }
        }

        // Log if no image found after all attempts
        if recipe.imageURL == nil {
            Log.warning("No image found for Smitten Kitchen recipe", category: .network)
        }

        // Fallback: Parse from entry-content for older posts
        // Smitten Kitchen older posts have recipes at the END of the post,
        // often preceded by a bold recipe title and followed by print buttons
        guard let entryContent = try? doc.select(".entry-content").first() else {
            throw ImportError.noRecipeFound
        }

        // Strategy: Find the recipe section by looking for:
        // 1. Bold text that matches the post title (recipe header)
        // 2. Print/Save buttons (sk-recipe-btn class)
        // 3. Ingredient lists (ul/li starting with measurements)

        // Track where the recipe section starts
        var recipeStartIndex = -1

        // Get all child elements of entry-content
        let allElements = try entryContent.getAllElements()

        // Find where the recipe section starts (look for bold text matching title)
        for (index, element) in allElements.enumerated() {
            let tagName = element.tagName()
            if tagName == "strong" || tagName == "b" {
                let text = try element.text().lowercased()
                let titleLower = recipe.title.lowercased()
                // Check if this bold text contains the recipe title or is a recipe header
                if text.contains(titleLower.prefix(15)) || text.contains("cookie") ||
                   text.contains("recipe") || text.contains("yield") {
                    recipeStartIndex = index
                    break
                }
            }
        }

        // If no recipe header found, try to find the section by looking for
        // the first list that has ingredient-like items
        if recipeStartIndex < 0 {
            let lists = try entryContent.select("ul")
            for list in lists {
                let items = try list.select("li")
                if items.size() > 3 {
                    // Check if items look like ingredients
                    var ingredientCount = 0
                    for item in items {
                        let text = try item.text()
                        if text.range(of: #"^[\d½⅓⅔¼¾⅛⅜⅝⅞]"#, options: .regularExpression) != nil ||
                           text.lowercased().contains("cup") || text.lowercased().contains("tablespoon") ||
                           text.lowercased().contains("teaspoon") || text.lowercased().contains("ounce") {
                            ingredientCount += 1
                        }
                    }
                    if ingredientCount >= 3 {
                        // This list contains ingredients
                        for item in items {
                            let text = try item.text().trimmingCharacters(in: .whitespacesAndNewlines)
                            if !text.isEmpty {
                                recipe.ingredients.append(text)
                            }
                        }
                        break
                    }
                }
            }
        }

        // If we still have no ingredients, scan paragraphs for measurement lines
        if recipe.ingredients.isEmpty {
            let paragraphs = try entryContent.select("p")
            var foundRecipeSection = false

            for paragraph in paragraphs {
                // Get raw HTML to detect <br> tags
                let html = try paragraph.html()
                let text = try paragraph.text().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }

                // Look for recipe section markers
                let isBold = (try? paragraph.select("strong, b").first()) != nil
                if isBold && text.count < 60 {
                    let lowercased = text.lowercased()
                    if lowercased.contains(recipe.title.lowercased().prefix(10)) ||
                       lowercased.contains("cookie") || lowercased.contains("yield") ||
                       lowercased.contains("dough") || lowercased.contains("crust") ||
                       lowercased.contains("pie") {
                        foundRecipeSection = true
                        continue
                    }
                }

                // Check if this paragraph contains multiple ingredient lines (br-separated)
                // This handles Smitten Kitchen's format where ingredients are one paragraph with <br> between lines
                let hasBrTags = html.contains("<br>") || html.contains("<br/>") || html.contains("<br />")
                let hasMeasurements = text.range(of: #"[\d½⅓⅔¼¾⅛⅜⅝⅞].*\s+(cup|tablespoon|teaspoon|tbsp|tsp|ounce|oz|gram|g|lb|pound)"#, options: [.regularExpression, .caseInsensitive]) != nil

                if hasBrTags && hasMeasurements {
                    // Split by <br> tags and process each line
                    let lines = html
                        .replacingOccurrences(of: "<br>", with: "\n")
                        .replacingOccurrences(of: "<br/>", with: "\n")
                        .replacingOccurrences(of: "<br />", with: "\n")
                        .components(separatedBy: "\n")

                    for line in lines {
                        // Strip HTML tags from each line
                        let cleanLine = line.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleanLine.isEmpty && cleanLine.count > 3 && cleanLine.count < 200 {
                            // Check if this line looks like an ingredient
                            if cleanLine.range(of: #"^[\d½⅓⅔¼¾⅛⅜⅝⅞]"#, options: .regularExpression) != nil ||
                               cleanLine.lowercased().contains("cup") ||
                               cleanLine.lowercased().contains("tablespoon") ||
                               cleanLine.lowercased().contains("teaspoon") ||
                               cleanLine.lowercased().contains("ounce") ||
                               cleanLine.lowercased().contains("gram") {
                                recipe.ingredients.append(cleanLine)
                            }
                        }
                    }

                    if !recipe.ingredients.isEmpty {
                        Log.debug("Found br-separated ingredients", category: .network, metadata: ["count": recipe.ingredients.count])
                        break
                    }
                }

                // Once in recipe section, collect ingredients from separate paragraphs
                if foundRecipeSection {
                    if text.range(of: #"^[\d½⅓⅔¼¾⅛⅜⅝⅞]"#, options: .regularExpression) != nil {
                        recipe.ingredients.append(text)
                    }
                }
            }
        }

        // Now get instructions - they come AFTER the ingredients
        // Smitten Kitchen uses bold headers like "Gather your ingredients:", "Make your mix:"
        // followed by prose paragraphs describing each step

        // First, look for bold-header style instructions (common in Smitten Kitchen)
        let allParagraphs = try entryContent.select("p")
        var boldHeaderInstructions: [(header: String, content: String)] = []

        for paragraph in allParagraphs {
            let text = try paragraph.text().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty && text.count > 20 else { continue }

            // Check for bold header at start of paragraph
            if let boldElement = try? paragraph.select("strong, b").first() {
                let boldText = try boldElement.text().trimmingCharacters(in: .whitespacesAndNewlines)
                let lowercaseBold = boldText.lowercased()

                // Check if this is a step header (often ends with ":" and contains action word)
                let isStepHeader = (boldText.hasSuffix(":") || boldText.hasSuffix(".")) &&
                    (lowercaseBold.contains("gather") || lowercaseBold.contains("make") ||
                     lowercaseBold.contains("roll") || lowercaseBold.contains("glue") ||
                     lowercaseBold.contains("pack") || lowercaseBold.contains("chill") ||
                     lowercaseBold.contains("store") || lowercaseBold.contains("mix") ||
                     lowercaseBold.contains("bake") || lowercaseBold.contains("prep") ||
                     lowercaseBold.contains("combine") || lowercaseBold.contains("fold") ||
                     lowercaseBold.contains("step") || lowercaseBold.contains("assemble") ||
                     lowercaseBold.contains("finish") || lowercaseBold.contains("serve"))

                if isStepHeader {
                    boldHeaderInstructions.append((header: boldText, content: text))
                }
            }
        }

        // If we found bold-header instructions, use them
        if boldHeaderInstructions.count >= 2 {
            recipe.instructions = boldHeaderInstructions.map { $0.content }
            Log.debug("Found bold-header style instructions", category: .network, metadata: ["count": recipe.instructions.count])
        }

        // Fallback to paragraph-scanning if no bold-header instructions found
        if recipe.instructions.isEmpty {
            let paragraphs = try entryContent.select("p")
            var instructionStarted = false

            for paragraph in paragraphs {
                let text = try paragraph.text().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty && text.count < 1500 else { continue }

                // Skip very short paragraphs
                guard text.count > 20 else { continue }

                // Check if this looks like an instruction start
                let lowercased = text.lowercased()

                // Strong indicators of actual cooking instructions
                let isOvenInstruction = lowercased.contains("heat oven") || lowercased.contains("preheat")
                let hasTemperature = lowercased.range(of: #"\d{3}\s*degree"#, options: .regularExpression) != nil
                let hasBakingTime = lowercased.range(of: #"(bake|cook)\s+(for\s+)?\d+"#, options: .regularExpression) != nil
                let startsWithCookingVerb = lowercased.hasPrefix("heat") || lowercased.hasPrefix("bake") ||
                                            lowercased.hasPrefix("mix") || lowercased.hasPrefix("combine") ||
                                            lowercased.hasPrefix("place") || lowercased.hasPrefix("add") ||
                                            lowercased.hasPrefix("stir") || lowercased.hasPrefix("pour") ||
                                            lowercased.hasPrefix("line") || lowercased.hasPrefix("in a") ||
                                            lowercased.hasPrefix("transfer") || lowercased.hasPrefix("scoop") ||
                                            lowercased.hasPrefix("roll") || lowercased.hasPrefix("drop") ||
                                            lowercased.hasPrefix("let") || lowercased.hasPrefix("remove") ||
                                            lowercased.hasPrefix("both methods") || lowercased.hasPrefix("to make")

            // Skip if it's PRIMARILY personal narrative (not mixed with cooking instructions)
            // Only skip if it has narrative markers AND lacks cooking content
            let hasNarrativeMarkers = lowercased.contains("ago:") ||
                                      lowercased.contains("months ago") || lowercased.contains("years ago")
            let hasCookingTerms = lowercased.contains("dough") || lowercased.contains("bake") ||
                                  lowercased.contains("oven") || lowercased.contains("sheet") ||
                                  lowercased.contains("scoop") || lowercased.contains("roll") ||
                                  lowercased.contains("transfer") || lowercased.contains("cookie") ||
                                  lowercased.contains("minute") || lowercased.contains("cool")
            let isPersonalNarrative = hasNarrativeMarkers && !hasCookingTerms

            if isPersonalNarrative {
                continue
            }

            if isOvenInstruction || hasTemperature || hasBakingTime {
                instructionStarted = true
            }

            // Cooking content check for starting or validating instructions
            let hasCookingContent = lowercased.contains("minute") || lowercased.contains("oven") ||
                                   lowercased.contains("bake") || lowercased.contains("cool") ||
                                   lowercased.contains("dough") || lowercased.contains("cookie") ||
                                   lowercased.contains("sheet") || lowercased.contains("pan") ||
                                   lowercased.contains("bowl") || lowercased.contains("mixer") ||
                                   lowercased.contains("flour") || lowercased.contains("sugar") ||
                                   lowercased.contains("butter") || lowercased.contains("egg") ||
                                   lowercased.contains("sprinkle") || lowercased.contains("scoop") ||
                                   lowercased.contains("transfer") || lowercased.contains("roll") ||
                                   lowercased.contains("inch") || lowercased.contains("rack") ||
                                   lowercased.contains("batch") || lowercased.contains("ball") ||
                                   lowercased.contains("flatten") || lowercased.contains("chill") ||
                                   lowercased.contains("refrigerat") || lowercased.contains("room temperature") ||
                                   hasTemperature || hasBakingTime

            if instructionStarted || startsWithCookingVerb || hasBakingTime {
                // Once we've started collecting instructions, be more permissive
                // Accept paragraphs that have cooking content OR if we've already started and
                // the paragraph doesn't look like a comment/footer
                let looksLikeFooter = lowercased.contains("print this recipe") ||
                                     lowercased.contains("rate this recipe") ||
                                     lowercased.contains("filed under") ||
                                     lowercased.contains("tagged with") ||
                                     lowercased.contains("comments") ||
                                     lowercased.contains("leave a reply")

                if hasCookingContent || startsWithCookingVerb {
                    recipe.instructions.append(text)
                    instructionStarted = true
                } else if instructionStarted && !looksLikeFooter && text.count > 30 {
                    // Continue collecting if we're in instruction mode and it doesn't look like footer
                    recipe.instructions.append(text)
                }
            }
            }
        }

        // Validate we got something useful
        guard !recipe.title.isEmpty && (!recipe.ingredients.isEmpty || !recipe.instructions.isEmpty) else {
            throw ImportError.noRecipeFound
        }

        Log.info("Parsed Smitten Kitchen recipe (fallback)", category: .network, metadata: [
            "title": recipe.title,
            "ingredientCount": recipe.ingredients.count,
            "instructionCount": recipe.instructions.count
        ])

        return recipe
    }

    private func parseWPRecipeMaker(from doc: Document) throws -> ImportedRecipe {
        // WP Recipe Maker (WPRM) uses consistent class naming
        var recipe = ImportedRecipe()

        // Find recipe container
        guard let container = try? doc.select(".wprm-recipe, [class*=wprm-recipe]").first() else {
            throw ImportError.noRecipeFound
        }

        // Title
        if let title = try? container.select(".wprm-recipe-name").first()?.text() {
            recipe.title = title.decodingHTMLEntities()
        } else if let title = try? doc.select(".entry-title, h1").first()?.text() {
            // Fall back to post title
            recipe.title = title.decodingHTMLEntities()
        }

        // Image
        if let imgElement = try? container.select(".wprm-recipe-image img").first() {
            recipe.imageURL = try? imgElement.attr("src")
        }

        // Servings
        if let servings = try? container.select(".wprm-recipe-servings").first()?.text() {
            recipe.servings = servings
        }

        // Prep time
        if let prepTime = try? container.select(".wprm-recipe-prep-time-container").first()?.text() {
            recipe.prepTime = prepTime
        }

        // Cook time
        if let cookTime = try? container.select(".wprm-recipe-cook-time-container").first()?.text() {
            recipe.cookTime = cookTime
        }

        // Ingredients - WPRM uses grouped or flat ingredient lists
        let ingredientElements = try container.select(".wprm-recipe-ingredient")
        if !ingredientElements.isEmpty() {
            recipe.ingredients = ingredientElements.compactMap { element -> String? in
                // Combine amount, unit, and name
                var parts: [String] = []

                if let amount = try? element.select(".wprm-recipe-ingredient-amount").text(),
                   !amount.isEmpty {
                    parts.append(amount)
                }
                if let unit = try? element.select(".wprm-recipe-ingredient-unit").text(),
                   !unit.isEmpty {
                    parts.append(unit)
                }
                if let name = try? element.select(".wprm-recipe-ingredient-name").text(),
                   !name.isEmpty {
                    parts.append(name)
                }
                if let notes = try? element.select(".wprm-recipe-ingredient-notes").text(),
                   !notes.isEmpty {
                    parts.append("(\(notes))")
                }

                let result = parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                return result.isEmpty ? nil : result
            }
        }

        // Instructions
        let instructionElements = try container.select(".wprm-recipe-instruction")
        if !instructionElements.isEmpty() {
            recipe.instructions = instructionElements.compactMap { element -> String? in
                // Get instruction text, ignoring images
                if let text = try? element.select(".wprm-recipe-instruction-text").text() {
                    return text.trimmingCharacters(in: .whitespaces)
                }
                return try? element.text().trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }
        }

        // Description/summary
        if let summary = try? container.select(".wprm-recipe-summary").first()?.text() {
            recipe.description = summary
        }

        // Validate
        guard !recipe.title.isEmpty && !recipe.ingredients.isEmpty else {
            throw ImportError.noRecipeFound
        }

        Log.info("Parsed WP Recipe Maker recipe", category: .network, metadata: [
            "title": recipe.title,
            "ingredientCount": recipe.ingredients.count,
            "instructionCount": recipe.instructions.count
        ])

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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip very short text
        guard trimmed.count > 15 else { return false }

        // Exclude comment patterns (first-person narratives, reviews)
        let commentPatterns = [
            "i love", "i loved", "i tried", "i made", "i recommend",
            "we love", "we loved", "we tried", "my favorite",
            "these are amazing", "these were amazing", "this is delicious",
            "thank you for", "thank you so much", "thanks for",
            "can't wait to", "just made this", "turned out great",
            "so good", "very delicious", "will make again",
            "my family loved", "my kids loved", "my husband loved",
            "this recipe", "great recipe", "wonderful recipe",
            "i always", "i never", "growing up", "when i was"
        ]

        for pattern in commentPatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }

        // Imperative verbs that indicate cooking instructions
        let instructionVerbs = [
            "preheat", "heat", "warm", "cool", "chill",
            "mix", "combine", "blend", "stir", "whisk", "beat", "fold", "cream",
            "add", "pour", "place", "put", "set", "arrange", "spread", "layer",
            "bake", "cook", "roast", "grill", "fry", "sauté", "boil", "simmer", "broil",
            "refrigerate", "freeze", "rest", "let sit", "let stand", "allow",
            "remove", "transfer", "drain", "strain", "sift", "pulse",
            "cut", "chop", "slice", "dice", "mince", "julienne", "grate", "zest",
            "season", "sprinkle", "garnish", "top", "drizzle", "brush",
            "roll", "shape", "form", "flatten", "press", "scoop",
            "cover", "wrap", "line", "grease", "butter", "coat",
            "bring", "reduce", "thicken", "melt", "dissolve",
            "toss", "flip", "turn", "rotate"
        ]

        // Check if text starts with an instruction verb
        for verb in instructionVerbs {
            if lowercased.hasPrefix(verb) {
                return true
            }
        }

        // Check if text contains instruction verbs (more permissive)
        // This catches sentences like "In a bowl, combine..." or "Using a mixer, beat..."
        for verb in instructionVerbs {
            // Check for verb at word boundary
            if lowercased.contains(" \(verb) ") || lowercased.contains(" \(verb),") ||
               lowercased.contains(" \(verb).") || lowercased.contains(".\(verb) ") {
                return true
            }
        }

        // Check for time/temperature measurements (strong indicator)
        let hasTimeOrTemp = lowercased.range(of: #"\d+\s*(minute|hour|second|degree|°f|°c|fahrenheit|celsius)"#, options: .regularExpression) != nil
        if hasTimeOrTemp {
            return true
        }

        // Check for oven temperatures
        let hasOvenTemp = lowercased.range(of: #"\d{3}\s*°"#, options: .regularExpression) != nil
        if hasOvenTemp {
            return true
        }

        // Check for common instruction contexts
        let instructionContexts = [
            "in a bowl", "in a pan", "in a pot", "in a skillet", "in a mixer",
            "on a baking", "on a sheet", "onto a", "into the",
            "using a", "with a", "until", "for about", "for approximately"
        ]

        for context in instructionContexts {
            if lowercased.contains(context) {
                return true
            }
        }

        return false
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
