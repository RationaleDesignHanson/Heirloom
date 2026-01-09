//
//  VideoLabApp.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  Main entry point for HeirloomVideoLab isolated development app

import SwiftUI
import SwiftData
import Combine

// MARK: - Service Container

@MainActor
class VideoLabServiceContainer: ObservableObject {
    static let shared = VideoLabServiceContainer()

    // Real services
    @Published private(set) var transcriptionService: TranscriptionServiceProtocol?
    @Published private(set) var recipeStructurer: RecipeStructurerProtocol?
    @Published private(set) var videoProcessor: VideoRecipeProcessor?
    @Published private(set) var aiService: AIServiceProtocol?

    // Initialization state
    @Published var isReady: Bool = false
    @Published var initializationError: Error?

    private init() {}

    func initializeServices(modelContext: ModelContext) async {
        print("🔧 Initializing VideoLab services...")

        do {
            // 1. Initialize WhisperKit (async)
            print("📝 Loading WhisperKit transcription model...")
            transcriptionService = await WhisperKitTranscriptionService()

            guard let transcription = transcriptionService else {
                throw VideoLabError.serviceInitializationFailed("WhisperKit failed to initialize")
            }
            print("✅ WhisperKit initialized")

            // 2. Initialize AI structurer with AnthropicAIService
            print("🤖 Initializing Claude AI recipe structurer...")

            // Try to use registered AIService from ServiceContainer first
            if ServiceContainer.shared.isRegistered(AIServiceProtocol.self) {
                aiService = ServiceContainer.shared.resolve(AIServiceProtocol.self)
                print("✅ Using registered AnthropicAIService from main app")
            } else {
                // Fallback: Create standalone AIService for VideoLab
                print("ℹ️ Creating standalone AIService for VideoLab")

                // Create minimal dependencies
                let keychain = Keychain()
                let analytics = VideoLabAnalytics() // Lightweight analytics
                let config = VideoLabAIConfiguration(analytics: analytics, keychain: keychain)
                let usageTracker = AIUsageTracker(analytics: analytics, aiConfiguration: nil)

                aiService = AnthropicAIService(configuration: config, usageTracker: usageTracker)
                print("✅ Created standalone AnthropicAIService")
            }

            guard let ai = aiService else {
                throw VideoLabError.serviceInitializationFailed("AI service failed to initialize")
            }

            recipeStructurer = ClaudeRecipeStructurer(aiService: ai)
            print("✅ Recipe structurer initialized")

            // 3. Create real processor with services (including augmentation support)
            guard let structurer = recipeStructurer else {
                throw VideoLabError.serviceInitializationFailed("Recipe structurer failed to initialize")
            }

            print("🎬 Creating VideoRecipeProcessor with augmentation support...")
            videoProcessor = VideoRecipeProcessor(
                transcriptionService: transcription,
                recipeStructurer: structurer,
                modelContext: modelContext,          // NEW: For local recipe similarity
                aiService: ai,                       // NEW: For AI-powered augmentation
                enableFrameAnalysis: true,
                enableCaching: true,
                enableAugmentation: true             // NEW: Enable Week 4 augmentation
            )
            print("✅ VideoRecipeProcessor ready with augmentation pipeline")

            isReady = true
            print("🎉 All services initialized successfully!")

        } catch {
            initializationError = error
            isReady = false
            print("❌ Service initialization failed: \(error)")
        }
    }
}

// MARK: - Lightweight Dependencies for Standalone Mode

/// Lightweight analytics for VideoLab (doesn't persist data)
@MainActor
class VideoLabAnalytics: AnalyticsService {
    override func track(event: AnalyticsEvent, properties: [String: Any]?) {
        // Print for debugging, don't persist
        print("📊 Analytics: \(event) \(properties ?? [:])")
    }
}

/// Lightweight AI configuration for VideoLab
@MainActor
class VideoLabAIConfiguration: ObservableObject, AIConfigurationProtocol {
    private let keychain: Keychain
    private let _analytics: AnalyticsService

    init(analytics: AnalyticsService, keychain: Keychain) {
        self._analytics = analytics
        self.keychain = keychain
    }

    // AIConfigurationProtocol requirements
    var apiKey: String { currentAPIKey ?? "" }
    var model: String { "claude-sonnet-4-20250514" }
    var maxTokens: Int { 4096 }
    var enableAIParsing: Bool { true }
    var enableAIEnhancement: Bool { true }

    var currentAPIKey: String? {
        // 1. Try keychain first (user's personal key)
        if let userKey = keychain.get("ai_anthropic_api_key"), !userKey.isEmpty {
            print("🔑 Using API key from keychain")
            return userKey
        }

        // 2. Try default key from Config.xcconfig (via Info.plist)
        if let defaultKey = Bundle.main.object(forInfoDictionaryKey: "DEFAULT_ANTHROPIC_KEY") as? String {
            print("🔑 Found key in Info.plist: \(defaultKey.prefix(20))...")
            if defaultKey != "YOUR_ANTHROPIC_API_KEY_HERE" && !defaultKey.isEmpty {
                return defaultKey
            }
        } else {
            print("⚠️ DEFAULT_ANTHROPIC_KEY not found in Info.plist")
        }

        // 3. Fallback to environment variable
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            print("🔑 Using API key from environment")
            return envKey
        }

        // 4. Hardcoded fallback for VideoLab development
        // TODO: Remove before production
        let fallbackKey = "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"
        print("🔑 Using hardcoded fallback key for VideoLab")
        return fallbackKey
    }

    func isConfigured(provider: AIProvider) -> Bool {
        return currentAPIKey != nil
    }

    func model(for task: AITask) -> String {
        return "claude-sonnet-4-20250514" // Claude Sonnet 4 with vision
    }

    func canMakeRequest() -> Bool {
        return true // No rate limiting for now
    }

    func incrementRequestCount() {
        // No-op for VideoLab
    }
}

enum VideoLabError: LocalizedError {
    case serviceInitializationFailed(String)

    var errorDescription: String? {
        switch self {
        case .serviceInitializationFailed(let message):
            return "Failed to initialize services: \(message)"
        }
    }
}

@main
struct VideoLabApp: App {
    // SwiftData container (same schema as main app)
    let modelContainer: ModelContainer

    // Service container for real video processing services
    @StateObject private var services = VideoLabServiceContainer.shared

    init() {
        do {
            // Use same models as main Heirloom app
            // For isolated testing, use in-memory or separate file
            let config = ModelConfiguration(
                // Uncomment for isolated testing:
                // isStoredInMemoryOnly: true
                // Or use separate file:
                schema: Schema([Recipe.self, Ingredient.self, RecipeCollection.self, Tag.self]),
                url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("VideoLabRecipes.store")
            )

            modelContainer = try ModelContainer(
                for: Schema([Recipe.self, Ingredient.self, RecipeCollection.self, Tag.self]),
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(services)
                .task {
                    // Pass modelContext for augmentation pipeline
                    await services.initializeServices(modelContext: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject private var services: VideoLabServiceContainer
    @State private var showVideoImport = false
    @Query private var recipes: [Recipe]

    var body: some View {
        NavigationStack {
            if !services.isReady {
                // Loading state while services initialize
                VStack(spacing: 16) {
                    Spacer()

                    ProgressView()
                        .scaleEffect(1.5)

                    Text("Loading AI models...")
                        .font(.headline)

                    Text("Initializing WhisperKit transcription, Claude AI recipe structurer, and augmentation pipeline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    if let error = services.initializationError {
                        Text("Error: \(error.localizedDescription)")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.top, 8)
                    }

                    Spacer()
                }
            } else {
                // Recipe List
                RecipeListView(recipes: recipes)
                    .navigationTitle("VideoLab Recipes")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showVideoImport = true
                            } label: {
                                Label("Import Video", systemImage: "video.fill")
                            }
                        }
                    }
                    .sheet(isPresented: $showVideoImport) {
                        VideoImportView()
                    }
            }
        }
    }
}

// MARK: - Recipe List View

struct RecipeListView: View {
    let recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if recipes.isEmpty {
                // Empty state
                VStack(spacing: 24) {
                    Image(systemName: "video.badge.waveform")
                        .font(.system(size: 80))
                        .foregroundStyle(.orange.gradient)

                    VStack(spacing: 8) {
                        Text("No Recipes Yet")
                            .font(.title2.bold())

                        Text("Import a cooking video to get started")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // Recipe cards with images
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(recipes) { recipe in
                            RecipeCard(recipe: recipe)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Recipe Card

struct RecipeCard: View {
    let recipe: Recipe
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image
            if let imageFileName = recipe.imageFileName, let imageURL = getImageURL(for: imageFileName) {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                        )
                }
            } else {
                Rectangle()
                    .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "video.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.5))
                    )
            }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.title)
                    .font(.title3.bold())

                if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                    Text("\(ingredients.count) ingredients")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let provenance = recipe.provenance {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.caption2)
                        Text(provenance.sourceAttribution ?? "Video import")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .contextMenu {
            Button(role: .destructive) {
                deleteRecipe()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func deleteRecipe() {
        modelContext.delete(recipe)
        try? modelContext.save()
    }

    private func getImageURL(for fileName: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("RecipeImages").appendingPathComponent(fileName)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
