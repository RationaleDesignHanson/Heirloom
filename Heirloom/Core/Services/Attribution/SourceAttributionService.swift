//
//  SourceAttributionService.swift
//  Heirloom
//
//  Core service for the Source Attribution Registry.
//  Manages local KnownSource entries and Firebase source_catalog sync.
//

import Foundation
import SwiftData
import FirebaseFirestore

// MARK: - Attribution Stats

struct AttributionStats {
    let totalSources: Int
    let sourcesByKind: [SourceKind: Int]
    let orphanRecipeCount: Int
    let syncedToFirebaseCount: Int
    let averageConfidence: Double
}

// MARK: - SourceAttributionService

@MainActor
class SourceAttributionService {

    private let modelContext: ModelContext
    private let firebaseConfig: FirebaseConfiguration

    init(modelContext: ModelContext, firebaseConfig: FirebaseConfiguration) {
        self.modelContext = modelContext
        self.firebaseConfig = firebaseConfig
    }

    // MARK: - Registration (called during imports)

    /// Register a source, merging with existing if found.
    /// Flow: check local → check Firebase catalog → create new
    @discardableResult
    func registerSource(
        name: String,
        kind: SourceKind,
        domain: String? = nil,
        platform: SocialPlatform? = nil,
        platformUsername: String? = nil,
        discoveryMethod: String,
        recipe: Recipe
    ) -> KnownSource {
        // Skip empty names
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            let source = KnownSource(name: "Unknown", kind: .unknown, discoveryMethod: discoveryMethod, confidence: 0.1)
            modelContext.insert(source)
            recipe.knownSource = source
            return source
        }

        // 1. Check local cache first
        if let existing = findMatchingSource(name: trimmedName, domain: domain, platformUsername: platformUsername) {
            existing.recordSeen()
            recipe.knownSource = existing
            Log.info("♻️ Reused existing KnownSource", category: .general, metadata: [
                "name": existing.name,
                "kind": existing.sourceKind,
                "importCount": "\(existing.importCount)",
                "recipeTitle": recipe.title
            ])
            // Merge aliases if name differs from stored name
            if KnownSource.normalize(trimmedName) == existing.normalizedName && trimmedName != existing.name {
                var currentAliases = existing.aliases ?? []
                if !currentAliases.contains(trimmedName) {
                    currentAliases.append(trimmedName)
                    existing.aliases = currentAliases
                }
            }
            // Contribute to shared catalog if high enough confidence
            if existing.confidence >= 0.7 && existing.importCount >= 2 && existing.kind != .person {
                Task { await self.contributeToSharedCatalog(existing) }
            }
            return existing
        }

        // 2. Create new local KnownSource
        let source = KnownSource(
            name: trimmedName,
            kind: kind,
            domain: domain,
            platform: platform,
            platformUsername: platformUsername,
            discoveryMethod: discoveryMethod,
            confidence: initialConfidence(for: kind, method: discoveryMethod)
        )
        modelContext.insert(source)
        recipe.knownSource = source
        Log.info("✨ Created NEW KnownSource", category: .general, metadata: [
            "name": trimmedName,
            "kind": kind.rawValue,
            "domain": domain ?? "nil",
            "platform": platform?.rawValue ?? "nil",
            "confidence": "\(source.confidence)",
            "discoveryMethod": discoveryMethod,
            "recipeTitle": recipe.title
        ])

        // 3. Check Firebase catalog in background (enrich local data if found)
        if kind != .person {
            Task {
                await self.enrichFromCatalog(source)
            }
        }

        return source
    }

    // MARK: - Lookup

    /// Find matching source locally by name, domain, or platform username
    func findMatchingSource(
        name: String?,
        domain: String?,
        platformUsername: String?
    ) -> KnownSource? {
        // Priority 1: Exact normalized name match
        if let name = name {
            let normalized = KnownSource.normalize(name)
            if !normalized.isEmpty, let match = fetchByNormalizedName(normalized) {
                return match
            }
        }

        // Priority 2: Domain match (URL sources)
        if let domain = domain, !domain.isEmpty {
            if let match = fetchByDomain(domain) {
                return match
            }
        }

        // Priority 3: Platform username match
        if let username = platformUsername, !username.isEmpty {
            if let match = fetchByPlatformUsername(username) {
                return match
            }
        }

        // Priority 4: Alias check
        if let name = name {
            let normalized = KnownSource.normalize(name)
            if !normalized.isEmpty, let match = fetchByAlias(normalized) {
                return match
            }
        }

        return nil
    }

    // MARK: - Firebase Catalog

    /// Enrich a local source with data from Firebase catalog (if available)
    func enrichFromCatalog(_ source: KnownSource) async {
        guard source.kind != .person else { return }

        do {
            let catalogRef = firebaseConfig.db.collection("source_catalog")

            // Query by normalized name + kind
            let snapshot = try await catalogRef
                .whereField("normalizedName", isEqualTo: source.normalizedName)
                .whereField("sourceKind", isEqualTo: source.sourceKind)
                .limit(to: 1)
                .getDocuments()

            guard let doc = snapshot.documents.first else { return }
            let data = doc.data()

            // Enrich local source with catalog data
            if let aliases = data["aliases"] as? [String], !aliases.isEmpty {
                var current = source.aliases ?? []
                for alias in aliases where !current.contains(alias) {
                    current.append(alias)
                }
                source.aliases = current
            }

            if source.domain == nil, let catalogDomain = data["domain"] as? String {
                source.domain = catalogDomain
            }

            if source.platformUsername == nil, let username = data["platformUsername"] as? String {
                source.platformUsername = username
            }

            if source.platform == nil, let platform = data["platform"] as? String {
                source.platform = platform
            }

            // Boost confidence from catalog validation
            let catalogConfidence = data["confidence"] as? Double ?? 0.5
            source.confidence = max(source.confidence, catalogConfidence)
            source.firebaseCatalogId = doc.documentID

            Log.debug("Enriched local source from catalog", category: .firebase, metadata: [
                "name": source.name,
                "catalogId": doc.documentID
            ])
        } catch {
            // Non-critical — catalog is an optimization, not a requirement
            Log.debug("Failed to check source catalog (non-critical)", category: .firebase, metadata: [
                "name": source.name,
                "error": error.localizedDescription
            ])
        }
    }

    /// Contribute a high-confidence local source to the shared catalog.
    /// Only contributes if confidence >= 0.7 and not .person kind.
    func contributeToSharedCatalog(_ source: KnownSource) async {
        guard source.kind != .person else { return }
        guard source.confidence >= 0.7 else { return }
        guard !source.isSyncedToFirebase else { return }

        do {
            let catalogRef = firebaseConfig.db.collection("source_catalog")

            // Check if already exists in catalog
            let snapshot = try await catalogRef
                .whereField("normalizedName", isEqualTo: source.normalizedName)
                .whereField("sourceKind", isEqualTo: source.sourceKind)
                .limit(to: 1)
                .getDocuments()

            if let existingDoc = snapshot.documents.first {
                // Update existing catalog entry
                try await existingDoc.reference.updateData([
                    "globalImportCount": FieldValue.increment(Int64(1)),
                    "contributorCount": FieldValue.increment(Int64(1)),
                    "lastSeenAt": Timestamp(date: Date()),
                    "confidence": max(source.confidence, existingDoc.data()["confidence"] as? Double ?? 0.5)
                ])
                source.firebaseCatalogId = existingDoc.documentID
            } else {
                // Create new catalog entry
                let data = FirebaseRecordConverter.convertSourceCatalogToFirestoreData(source)
                let docRef = try await catalogRef.addDocument(data: data)
                source.firebaseCatalogId = docRef.documentID
            }

            source.isSyncedToFirebase = true

            Log.debug("Contributed source to catalog", category: .firebase, metadata: [
                "name": source.name,
                "kind": source.sourceKind
            ])
        } catch {
            Log.debug("Failed to contribute to catalog (non-critical)", category: .firebase, metadata: [
                "name": source.name,
                "error": error.localizedDescription
            ])
        }
    }

    // MARK: - Quality & Gaps

    /// Find recipes without any known source attribution
    func getOrphanRecipes() -> [Recipe] {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { recipe in
                recipe.knownSource == nil
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Get attribution stats
    func getStats() -> AttributionStats {
        let allSources = (try? modelContext.fetch(FetchDescriptor<KnownSource>())) ?? []

        var byKind: [SourceKind: Int] = [:]
        var totalConfidence = 0.0
        var syncedCount = 0

        for source in allSources {
            let kind = source.kind
            byKind[kind, default: 0] += 1
            totalConfidence += source.confidence
            if source.isSyncedToFirebase { syncedCount += 1 }
        }

        let orphans = getOrphanRecipes()

        return AttributionStats(
            totalSources: allSources.count,
            sourcesByKind: byKind,
            orphanRecipeCount: orphans.count,
            syncedToFirebaseCount: syncedCount,
            averageConfidence: allSources.isEmpty ? 0 : totalConfidence / Double(allSources.count)
        )
    }

    /// Debug: dump full graph state to console
    func dumpStats() {
        let stats = getStats()
        let orphans = getOrphanRecipes()
        let top = topSources(limit: 20)
        let allSources = (try? modelContext.fetch(FetchDescriptor<KnownSource>())) ?? []

        Log.info("📊 ===== SOURCE ATTRIBUTION GRAPH DUMP =====", category: .general)
        Log.info("📊 Total KnownSources: \(stats.totalSources)", category: .general)
        Log.info("📊 Orphan recipes (no source): \(stats.orphanRecipeCount)", category: .general)
        Log.info("📊 Synced to Firebase: \(stats.syncedToFirebaseCount)", category: .general)
        Log.info("📊 Avg confidence: \(String(format: "%.2f", stats.averageConfidence))", category: .general)

        Log.info("📊 --- Sources by Kind ---", category: .general)
        for (kind, count) in stats.sourcesByKind.sorted(by: { $0.value > $1.value }) {
            Log.info("📊   \(kind.rawValue): \(count)", category: .general)
        }

        Log.info("📊 --- Top Sources ---", category: .general)
        for (source, count) in top {
            Log.info("📊   \(source.name) (\(source.sourceKind)) — \(count) recipes, importCount=\(source.importCount), confidence=\(String(format: "%.2f", source.confidence))", category: .general)
        }

        Log.info("📊 --- All Sources Detail ---", category: .general)
        for source in allSources {
            let recipeNames = (source.recipes ?? []).compactMap { $0.title }.joined(separator: ", ")
            Log.info("📊   [\(source.sourceKind)] \(source.name) | recipes=\(source.recipes?.count ?? 0) [\(recipeNames)] | domain=\(source.domain ?? "nil") | platform=\(source.platform ?? "nil") | username=\(source.platformUsername ?? "nil") | confidence=\(String(format: "%.2f", source.confidence)) | importCount=\(source.importCount)", category: .general)
        }

        if !orphans.isEmpty {
            Log.info("📊 --- Orphan Recipes ---", category: .general)
            for recipe in orphans {
                Log.info("📊   \(recipe.title) | sourceType=\(recipe.sourceType?.rawValue ?? "nil") | sourceURL=\(recipe.sourceURL ?? "nil")", category: .general)
            }
        }

        Log.info("📊 ===== END GRAPH DUMP =====", category: .general)
    }

    /// Backfill attribution for orphan recipes using their existing source fields.
    /// Returns the number of recipes that got attributed.
    @discardableResult
    func backfillAttribution() -> Int {
        let orphans = getOrphanRecipes()
        var count = 0

        for recipe in orphans {
            if attributeRecipeFromFields(recipe) {
                count += 1
            }
        }

        if count > 0 {
            try? modelContext.save()
        }

        return count
    }

    // MARK: - Private Helpers

    /// Derive source attribution from a recipe's existing fields
    @discardableResult
    private func attributeRecipeFromFields(_ recipe: Recipe) -> Bool {
        // Video imports with social creator
        if recipe.sourceType == .video,
           let attribution = recipe.provenance?.sourceAttribution,
           !attribution.isEmpty {
            let creatorName = attribution.components(separatedBy: " - ").first?
                .trimmingCharacters(in: .whitespaces) ?? attribution

            var platform: SocialPlatform? = nil
            if let url = recipe.provenance?.sourceURL {
                platform = detectPlatform(from: url)
            }

            registerSource(
                name: creatorName,
                kind: .socialCreator,
                platform: platform,
                platformUsername: creatorName,
                discoveryMethod: "migration",
                recipe: recipe
            )
            return true
        }

        // URL imports
        if recipe.sourceType == .url, let urlString = recipe.sourceURL {
            let domain = KnownSource.extractDomain(from: urlString)
            let name = domain ?? "Unknown Website"
            registerSource(
                name: name,
                kind: .website,
                domain: domain,
                discoveryMethod: "migration",
                recipe: recipe
            )
            return true
        }

        // Cookbook/scan imports
        if recipe.sourceType == .cookbook || recipe.sourceType == .scan {
            if let author = recipe.sourceBookAuthor, !author.isEmpty {
                registerSource(
                    name: author,
                    kind: .cookbook,
                    discoveryMethod: "migration",
                    recipe: recipe
                )
                return true
            }
            if let title = recipe.sourceBookTitle, !title.isEmpty {
                registerSource(
                    name: title,
                    kind: .cookbook,
                    discoveryMethod: "migration",
                    recipe: recipe
                )
                return true
            }
        }

        // Family/person sources
        if recipe.sourceType == .family, let person = recipe.sourcePerson, !person.isEmpty {
            registerSource(
                name: person,
                kind: .person,
                discoveryMethod: "migration",
                recipe: recipe
            )
            return true
        }

        // AI-generated
        if recipe.sourceType == .generated || recipe.aiGenerated {
            registerSource(
                name: "AI Generated",
                kind: .aiGenerated,
                discoveryMethod: "migration",
                recipe: recipe
            )
            return true
        }

        // Theme/heritage
        if recipe.sourceType == .heritage, let themeId = recipe.sourceThemeId {
            let name = recipe.collections?.first(where: { $0.sourceTheme?.firebaseId == themeId })?.name ?? "Theme Collection"
            registerSource(
                name: name,
                kind: .publication,
                discoveryMethod: "migration",
                recipe: recipe
            )
            return true
        }

        return false
    }

    /// Determine initial confidence based on source kind and discovery method
    private func initialConfidence(for kind: SourceKind, method: String) -> Double {
        switch method {
        case "url_metadata": return 0.8    // URL metadata is reliable
        case "pdf_vision": return 0.6      // Vision OCR can be noisy
        case "pdf_metadata": return 0.7    // PDF metadata is decent
        case "video_watermark": return 0.7 // Watermark extraction is good
        case "user_manual": return 0.9     // User explicitly entered
        case "migration": return 0.5       // Existing data, unknown quality
        case "scan_ocr": return 0.5        // Camera OCR can be noisy
        default: return 0.5
        }
    }

    /// Detect social platform from URL
    private func detectPlatform(from urlString: String) -> SocialPlatform? {
        let lower = urlString.lowercased()
        if lower.contains("tiktok.com") { return .tiktok }
        if lower.contains("instagram.com") { return .instagram }
        if lower.contains("youtube.com") || lower.contains("youtu.be") { return .youtube }
        if lower.contains("facebook.com") { return .facebook }
        if lower.contains("pinterest.com") { return .pinterest }
        return nil
    }

    // MARK: - Cross-Recipe Source Queries

    /// Find all recipes from the same KnownSource
    func recipesFromSameSource(as recipe: Recipe) -> [Recipe] {
        guard let source = recipe.knownSource else { return [] }
        return (source.recipes ?? []).filter { $0.id != recipe.id }
    }

    /// Find common substitutions across recipes from the same source
    /// Returns (originalIngredient, substituteIngredient, count) tuples
    func commonSubstitutions(for source: KnownSource) -> [(original: String, substitute: String, count: Int)] {
        let recipes = source.recipes ?? []
        var substitutionCounts: [String: Int] = [:]

        for recipe in recipes {
            guard let ingredients = recipe.ingredients else { continue }
            for ingredient in ingredients {
                guard let subs = ingredient.substitutions else { continue }
                for sub in subs {
                    let key = "\(sub.originalIngredient.lowercased())→\(sub.substituteIngredient.lowercased())"
                    substitutionCounts[key, default: 0] += 1
                }
            }
        }

        return substitutionCounts.compactMap { key, count in
            let parts = key.split(separator: "→", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return (original: String(parts[0]), substitute: String(parts[1]), count: count)
        }
        .sorted { $0.count > $1.count }
    }

    /// Find sources with the most recipes (top contributors to the recipe box)
    func topSources(limit: Int = 10) -> [(source: KnownSource, recipeCount: Int)] {
        let allSources = (try? modelContext.fetch(FetchDescriptor<KnownSource>())) ?? []
        return allSources
            .map { ($0, $0.recipes?.count ?? 0) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0 }
    }

    /// Find recipes that share a source catalog entry (cross-user linkage potential)
    func recipesByCatalogId(_ catalogId: String) -> [Recipe] {
        let descriptor = FetchDescriptor<KnownSource>(
            predicate: #Predicate<KnownSource> { source in
                source.firebaseCatalogId == catalogId
            }
        )
        guard let sources = try? modelContext.fetch(descriptor) else { return [] }
        return sources.flatMap { $0.recipes ?? [] }
    }

    // MARK: - SwiftData Queries

    private func fetchByNormalizedName(_ normalized: String) -> KnownSource? {
        let descriptor = FetchDescriptor<KnownSource>(
            predicate: #Predicate<KnownSource> { source in
                source.normalizedName == normalized
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchByDomain(_ domain: String) -> KnownSource? {
        let descriptor = FetchDescriptor<KnownSource>(
            predicate: #Predicate<KnownSource> { source in
                source.domain == domain
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchByPlatformUsername(_ username: String) -> KnownSource? {
        let normalizedUsername = username.lowercased().replacingOccurrences(of: "@", with: "")
        let descriptor = FetchDescriptor<KnownSource>(
            predicate: #Predicate<KnownSource> { source in
                source.platformUsername != nil
            }
        )
        return try? modelContext.fetch(descriptor).first(where: {
            $0.platformUsername?.lowercased().replacingOccurrences(of: "@", with: "") == normalizedUsername
        })
    }

    private func fetchByAlias(_ normalizedName: String) -> KnownSource? {
        // SwiftData doesn't support array contains in predicates well,
        // so fetch all and filter in memory (sources are a small dataset)
        let descriptor = FetchDescriptor<KnownSource>(
            predicate: #Predicate<KnownSource> { source in
                source.aliases != nil
            }
        )
        return try? modelContext.fetch(descriptor).first(where: { source in
            source.aliases?.contains(where: { KnownSource.normalize($0) == normalizedName }) ?? false
        })
    }
}
