import SwiftUI
import SwiftData

/// Editor for customizing the back of a recipe card with social features
struct CardBackEditorView: View {
    let recipe: Recipe

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var noteToFriends: String = ""
    @State private var personalTips: [String] = []
    @State private var userRating: Int? = nil
    @State private var userTags: [String] = []
    @State private var newTag: String = ""

    @State private var showAttribution: Bool = true
    @State private var maxCommentsToDisplay: Int = 3
    @State private var pinnedCommentIDs: Set<UUID> = []

    @State private var backgroundStyle: CardBackgroundStyle = .cream
    @State private var layoutStyle: CardBackLayout = .standard
    @State private var visibleSections: Set<CardBackSection> = [
        .attribution, .noteToFriends, .pinnedComments, .userTips
    ]

    @State private var newTipText: String = ""
    @State private var showingCommentPicker = false
    @State private var showingPreview = false

    // MARK: - Initialization

    init(recipe: Recipe) {
        self.recipe = recipe
    }

    var body: some View {
        NavigationStack {
            Form {
                // Preview section
                Section {
                    Button {
                        showingPreview = true
                    } label: {
                        HStack {
                            Image(systemName: "eye.fill")
                            Text("Preview Card Back")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Preview")
                }

                // Personal message section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Share your thoughts about this recipe with friends and family")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $noteToFriends)
                            .frame(minHeight: 100)
                            .overlay(alignment: .topLeading) {
                                if noteToFriends.isEmpty {
                                    Text("e.g., \"This recipe was passed down from my grandmother. The secret is to not overmix the batter!\"")
                                        .foregroundStyle(.secondary)
                                        .font(.body)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                    }

                    Toggle("Show on card back", isOn: visibleSectionBinding(.noteToFriends))
                } header: {
                    Text("Note to Friends")
                } footer: {
                    Text("This message will appear on the back of your recipe card")
                }

                // Personal tips section
                Section {
                    ForEach(Array(personalTips.enumerated()), id: \.offset) { index, tip in
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)

                            Text(tip)
                                .font(.subheadline)

                            Spacer()

                            Button {
                                removeTip(at: index)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    HStack {
                        TextField("Add a personal tip...", text: $newTipText)
                            .onSubmit {
                                addTip()
                            }

                        Button {
                            addTip()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .disabled(newTipText.isEmpty)
                    }

                    Toggle("Show on card back", isOn: visibleSectionBinding(.userTips))
                } header: {
                    Text("Your Tips (\(personalTips.count))")
                } footer: {
                    Text("Share helpful tips you've learned while making this recipe")
                }

                // Rating section
                Section {
                    HStack {
                        Text("Your Rating")
                        Spacer()
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                userRating = star
                            } label: {
                                Image(systemName: star <= (userRating ?? 0) ? "star.fill" : "star")
                                    .foregroundStyle(star <= (userRating ?? 0) ? .yellow : .gray)
                                    .font(.title3)
                            }
                        }
                    }

                    if userRating != nil {
                        Button("Clear Rating") {
                            userRating = nil
                        }
                        .foregroundStyle(.red)
                    }
                } header: {
                    Text("Rating")
                }

                // Tags section
                Section {
                    if !userTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(userTags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag)
                                            .font(.caption)
                                        Button {
                                            removeTag(tag)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption2)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.2))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    HStack {
                        TextField("Add a tag...", text: $newTag)
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                addTag()
                            }

                        Button {
                            addTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .disabled(newTag.isEmpty)
                    }
                } header: {
                    Text("Tags")
                } footer: {
                    Text("Add tags to help organize and search your recipes")
                }

                // Pinned comments section
                Section {
                    HStack {
                        Text("Pinned Comments")
                        Spacer()
                        Text("\(pinnedCommentIDs.count) selected")
                            .foregroundStyle(.secondary)
                        Button {
                            showingCommentPicker = true
                        } label: {
                            Text("Select")
                                .font(.subheadline)
                        }
                    }

                    Stepper("Display up to \(maxCommentsToDisplay)", value: $maxCommentsToDisplay, in: 1...10)

                    Toggle("Show on card back", isOn: visibleSectionBinding(.pinnedComments))
                } header: {
                    Text("Comments")
                } footer: {
                    Text("Select which comments to highlight on the back of your card")
                }

                // Attribution section
                Section {
                    Toggle("Show recipe attribution", isOn: $showAttribution)

                    if showAttribution {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: recipe.sourceType?.iconName ?? "book.closed.fill")
                                    .foregroundStyle(.secondary)
                                Text(recipe.sourceDisplayName)
                                    .font(.subheadline)
                            }

                            if let story = recipe.sourceStory {
                                Text(story)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Toggle("Show on card back", isOn: visibleSectionBinding(.attribution))
                } header: {
                    Text("Attribution")
                } footer: {
                    Text("Credit the source of this recipe")
                }

                // Style customization
                Section {
                    Picker("Background Style", selection: $backgroundStyle) {
                        ForEach(CardBackgroundStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }

                    Picker("Layout Style", selection: $layoutStyle) {
                        ForEach(CardBackLayout.allCases, id: \.self) { layout in
                            Text(layout.displayName).tag(layout)
                        }
                    }
                } header: {
                    Text("Card Style")
                } footer: {
                    Text("Customize the appearance of your card back")
                }

                // Visible sections
                Section {
                    ForEach(CardBackSection.allCases, id: \.self) { section in
                        Toggle(isOn: visibleSectionBinding(section)) {
                            HStack {
                                Image(systemName: section.iconName)
                                Text(section.displayName)
                            }
                        }
                    }
                } header: {
                    Text("Visible Sections")
                } footer: {
                    Text("Choose which sections to display on the card back")
                }
            }
            .navigationTitle("Customize Card Back")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveCardBack()
                    }
                }
            }
            .sheet(isPresented: $showingCommentPicker) {
                commentPickerSheet
            }
            .sheet(isPresented: $showingPreview) {
                cardBackPreview
            }
            .onAppear {
                loadCardBack()
            }
        }
    }

    // MARK: - Subviews

    private var commentPickerSheet: some View {
        NavigationStack {
            List {
                if let comments = recipe.comments?.filter({ !$0.isHidden }), !comments.isEmpty {
                    ForEach(comments) { comment in
                        Button {
                            toggleCommentPin(comment)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(comment.text)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                        .foregroundStyle(.primary)

                                    HStack(spacing: 8) {
                                        HStack(spacing: 2) {
                                            Image(systemName: "arrow.up.circle.fill")
                                                .font(.caption2)
                                            Text("\(comment.upvotes)")
                                                .font(.caption2)
                                        }
                                        .foregroundStyle(.green)

                                        if let sentiment = comment.sentimentScore {
                                            HStack(spacing: 2) {
                                                Image(systemName: sentimentIcon(sentiment))
                                                    .font(.caption2)
                                                Text(String(format: "%.0f%%", abs(sentiment) * 100))
                                                    .font(.caption2)
                                            }
                                            .foregroundStyle(sentimentColor(sentiment))
                                        }

                                        Text(comment.commentType.displayName)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if pinnedCommentIDs.contains(comment.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Comments Yet",
                        systemImage: "bubble.left",
                        description: Text("Add comments to your recipe to pin them to the card back")
                    )
                }
            }
            .navigationTitle("Select Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingCommentPicker = false
                    }
                }
            }
        }
    }

    private var cardBackPreview: some View {
        NavigationStack {
            ScrollView {
                RecipeCardBackContentView(
                    recipe: recipe,
                    cardBack: previewCardBack
                )
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingPreview = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func visibleSectionBinding(_ section: CardBackSection) -> Binding<Bool> {
        Binding(
            get: { visibleSections.contains(section) },
            set: { isVisible in
                if isVisible {
                    visibleSections.insert(section)
                } else {
                    visibleSections.remove(section)
                }
            }
        )
    }

    private func sentimentIcon(_ score: Double) -> String {
        if score > 0.5 { return "face.smiling" }
        if score > 0.2 { return "hand.thumbsup.fill" }
        if score < -0.5 { return "exclamationmark.triangle.fill" }
        if score < -0.2 { return "hand.thumbsdown.fill" }
        return "minus.circle"
    }

    private func sentimentColor(_ score: Double) -> Color {
        if score > 0.2 { return .green }
        if score < -0.2 { return .red }
        return .secondary
    }

    // MARK: - Data Management

    private func loadCardBack() {
        guard let cardBack = recipe.cardBack else {
            // Initialize with defaults
            return
        }

        noteToFriends = cardBack.noteToFriends ?? ""
        personalTips = cardBack.personalTips
        userRating = cardBack.userRating
        userTags = cardBack.userTags
        showAttribution = cardBack.showAttribution
        maxCommentsToDisplay = cardBack.maxCommentsToDisplay
        pinnedCommentIDs = Set(cardBack.pinnedCommentIDs)
        backgroundStyle = cardBack.backgroundStyle
        layoutStyle = cardBack.layoutStyle
        visibleSections = Set(cardBack.visibleSections)
    }

    private func saveCardBack() {
        do {
            if let existingCardBack = recipe.cardBack {
                // Update existing
                existingCardBack.noteToFriends = noteToFriends.isEmpty ? nil : noteToFriends
                existingCardBack.personalTips = personalTips
                existingCardBack.userRating = userRating
                existingCardBack.userTags = userTags
                existingCardBack.showAttribution = showAttribution
                existingCardBack.maxCommentsToDisplay = maxCommentsToDisplay
                existingCardBack.pinnedCommentIDs = Array(pinnedCommentIDs)
                existingCardBack.backgroundStyle = backgroundStyle
                existingCardBack.layoutStyle = layoutStyle
                existingCardBack.visibleSections = Array(visibleSections)
            } else {
                // Create new
                let newCardBack = RecipeCardBack(recipe: recipe)
                newCardBack.noteToFriends = noteToFriends.isEmpty ? nil : noteToFriends
                newCardBack.personalTips = personalTips
                newCardBack.userRating = userRating
                newCardBack.userTags = userTags
                newCardBack.showAttribution = showAttribution
                newCardBack.maxCommentsToDisplay = maxCommentsToDisplay
                newCardBack.pinnedCommentIDs = Array(pinnedCommentIDs)
                newCardBack.backgroundStyle = backgroundStyle
                newCardBack.layoutStyle = layoutStyle
                newCardBack.visibleSections = Array(visibleSections)
                modelContext.insert(newCardBack)
                recipe.cardBack = newCardBack
            }

            try modelContext.save()

            // Sync card back to Firebase if active
            if BackendConfig.shared.isFirebaseActive {
                Task {
                    do {
                        if let cardBack = recipe.cardBack {
                            try await FirebaseSyncService.shared.uploadCardBack(cardBack, recipeId: recipe.id)
                            print("✅ Card back synced to Firebase")
                        }
                    } catch {
                        print("⚠️ Failed to sync card back to Firebase: \(error.localizedDescription)")
                    }
                }
            }

            dismiss()
        } catch {
            print("Failed to save card back: \(error)")
        }
    }

    private var previewCardBack: RecipeCardBack {
        let preview = RecipeCardBack(recipe: recipe)
        preview.noteToFriends = noteToFriends.isEmpty ? nil : noteToFriends
        preview.personalTips = personalTips
        preview.userRating = userRating
        preview.userTags = userTags
        preview.showAttribution = showAttribution
        preview.maxCommentsToDisplay = maxCommentsToDisplay
        preview.pinnedCommentIDs = Array(pinnedCommentIDs)
        preview.backgroundStyle = backgroundStyle
        preview.layoutStyle = layoutStyle
        preview.visibleSections = Array(visibleSections)
        return preview
    }

    // MARK: - Actions

    private func addTip() {
        guard !newTipText.isEmpty else { return }
        personalTips.append(newTipText)
        newTipText = ""
    }

    private func removeTip(at index: Int) {
        personalTips.remove(at: index)
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !userTags.contains(trimmed) else { return }
        userTags.append(trimmed)
        newTag = ""
    }

    private func removeTag(_ tag: String) {
        userTags.removeAll { $0 == tag }
    }

    private func toggleCommentPin(_ comment: RecipeComment) {
        if pinnedCommentIDs.contains(comment.id) {
            pinnedCommentIDs.remove(comment.id)
        } else {
            pinnedCommentIDs.insert(comment.id)
        }
    }
}

// MARK: - Card Back Content View

/// View that renders the actual card back content
private struct RecipeCardBackContentView: View {
    let recipe: Recipe
    let cardBack: RecipeCardBack

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Recipe title
            Text(recipe.title)
                .font(.title2)
                .fontWeight(.bold)

            // Attribution
            if cardBack.visibleSections.contains(.attribution) && cardBack.showAttribution {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: recipe.sourceType?.iconName ?? "book.closed.fill")
                        Text(recipe.sourceDisplayName)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)

                    if let story = recipe.sourceStory {
                        Text(story)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }

                Divider()
            }

            // Note to friends
            if cardBack.visibleSections.contains(.noteToFriends), let note = cardBack.noteToFriends {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A Note from Me")
                        .font(.headline)

                    Text(note)
                        .font(.subheadline)
                        .italic()
                }

                Divider()
            }

            // User rating
            if cardBack.visibleSections.contains(.userRating), let rating = cardBack.userRating {
                HStack {
                    Text("My Rating:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }

                Divider()
            }

            // Personal tips
            if cardBack.visibleSections.contains(.userTips) && !cardBack.personalTips.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("My Tips")
                        .font(.headline)

                    ForEach(cardBack.personalTips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text(tip)
                                .font(.subheadline)
                        }
                    }
                }

                Divider()
            }

            // Pinned comments
            if cardBack.visibleSections.contains(.pinnedComments) && !cardBack.pinnedCommentIDs.isEmpty {
                let pinnedComments = recipe.comments?
                    .filter { cardBack.pinnedCommentIDs.contains($0.id) }
                    .prefix(cardBack.maxCommentsToDisplay) ?? []

                if !pinnedComments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Highlighted Comments")
                            .font(.headline)

                        ForEach(Array(pinnedComments)) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(comment.text)
                                    .font(.subheadline)

                                HStack {
                                    if let author = comment.authorName {
                                        Text("— \(author)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if comment.upvotes > 0 {
                                        HStack(spacing: 2) {
                                            Image(systemName: "arrow.up.circle.fill")
                                            Text("\(comment.upvotes)")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBack.backgroundStyle.color)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 10)
    }
}

// MARK: - CardBackgroundStyle Extension

extension CardBackgroundStyle {
    var color: Color {
        switch self {
        case .cream: return HeirloomColors.cream
        case .vintage: return HeirloomColors.amber
        case .lined: return HeirloomColors.cream
        case .grid: return HeirloomColors.cream
        case .photo: return HeirloomColors.cream
        case .solid: return HeirloomColors.warmGray
        }
    }

    var displayName: String {
        switch self {
        case .cream: return "Cream"
        case .vintage: return "Vintage"
        case .lined: return "Lined"
        case .grid: return "Grid"
        case .photo: return "Photo"
        case .solid: return "Solid"
        }
    }
}

// MARK: - CardBackLayout Extension

extension CardBackLayout {
    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .minimal: return "Minimal"
        case .detailed: return "Detailed"
        case .vintage: return "Vintage"
        }
    }
}

// MARK: - CardBackSection Extension

extension CardBackSection {
    var displayName: String {
        switch self {
        case .attribution: return "Attribution"
        case .noteToFriends: return "Note to Friends"
        case .pinnedComments: return "Pinned Comments"
        case .userTips: return "Tips"
        case .userRating: return "Rating"
        case .userTags: return "Tags"
        case .cookingHistory: return "Cooking History"
        }
    }

    var iconName: String {
        switch self {
        case .attribution: return "person.fill"
        case .noteToFriends: return "quote.bubble.fill"
        case .pinnedComments: return "pin.fill"
        case .userTips: return "lightbulb.fill"
        case .userRating: return "star.fill"
        case .userTags: return "tag.fill"
        case .cookingHistory: return "clock.fill"
        }
    }
}

// MARK: - Preview

#Preview("Card Back Editor") {
    CardBackEditorView(recipe: {
        let recipe = Recipe.example

        // Add some sample comments
        let comment1 = RecipeComment(
            text: "These cookies are amazing! Best recipe ever.",
            authorName: "Sarah M.",
            source: .scraped,
            commentType: .review
        )
        comment1.upvotes = 24
        comment1.sentimentScore = 0.9

        let comment2 = RecipeComment(
            text: "Pro tip: chill the dough for 30 minutes.",
            authorName: "Chef Mike",
            source: .user,
            commentType: .tip
        )
        comment2.upvotes = 18

        recipe.comments = [comment1, comment2]

        return recipe
    }())
    .modelContainer(for: Recipe.self, inMemory: true)
}
