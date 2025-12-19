import SwiftUI
import SwiftData

struct CardPersonalizationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var recipe: Recipe

    @State private var selectedTab: PersonalizationTab = .background
    @State private var showingRecipeStickerPicker = false
    @State private var showingRecipeAnnotationEditor = false
    @State private var selectedRecipeSticker: RecipeSticker?
    @State private var selectedRecipeAnnotation: RecipeAnnotation?
    @State private var isCardFlipped = false
    @State private var showCardBackEditor = false

    enum PersonalizationTab {
        case background
        case stickers
        case annotations
        case loveMarks
        case cardBack
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview Card
                previewCard
                    .frame(height: 400)
                    .padding()

                Divider()

                // Tab Selector
                tabSelector

                Divider()

                // Editor Content
                ScrollView {
                    editorContent
                        .padding()
                }
            }
            .navigationTitle("Personalize Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingRecipeStickerPicker) {
                RecipeStickerPickerView(recipe: recipe)
            }
            .sheet(isPresented: $showingRecipeAnnotationEditor) {
                RecipeAnnotationEditorView(recipe: recipe, annotation: selectedRecipeAnnotation)
            }
            .sheet(isPresented: $showCardBackEditor) {
                CardBackEditorView(recipe: recipe)
            }
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        Group {
            if selectedTab == .cardBack {
                // Show FlipCard with animation
                FlipCard(isFlipped: $isCardFlipped) {
                    cardFrontView
                } back: {
                    cardBackView
                }
                .frame(maxWidth: CGFloat.infinity)
                .aspectRatio(3/4, contentMode: ContentMode.fit)
            } else {
                // Show static front view for other tabs
                cardFrontView
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3/4, contentMode: .fit)
            }
        }
    }

    private var cardFrontView: some View {
        ZStack {
            // Background
            cardBackground

            // Recipe Image (simplified)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 150)
                .overlay {
                    Text(recipe.title)
                        .font(.title3)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)

            // RecipeStickers
            if let stickers = recipe.stickers {
                ForEach(stickers, id: \.id) { sticker in
                    stickerView(sticker)
                        .onTapGesture {
                            selectedRecipeSticker = sticker
                        }
                }
            }

            // RecipeAnnotations
            if let annotations = recipe.annotations {
                ForEach(annotations, id: \.id) { annotation in
                    annotationView(annotation)
                        .onTapGesture {
                            selectedRecipeAnnotation = annotation
                            showingRecipeAnnotationEditor = true
                        }
                }
            }

            // Love Marks
            if let cardStyle = recipe.cardStyle {
                loveMarksOverlay(cardStyle)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    private var cardBackView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Recipe title
                Text(recipe.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(HeirloomColors.charcoal)

                // Attribution
                if let cardBack = recipe.cardBack, cardBack.visibleSections.contains(.attribution), cardBack.showAttribution {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: recipe.sourceType?.iconName ?? "book.closed.fill")
                            Text(recipe.sourceDisplayName)
                                .font(.subheadline)
                        }
                        .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Divider()
                }

                // Note to friends
                if let cardBack = recipe.cardBack, cardBack.visibleSections.contains(.noteToFriends), let note = cardBack.noteToFriends {
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
                if let cardBack = recipe.cardBack, cardBack.visibleSections.contains(.userRating), let rating = cardBack.userRating {
                    HStack {
                        Text("My Rating:")
                            .font(.subheadline)
                            .foregroundStyle(HeirloomColors.secondaryText)
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                        }
                    }

                    Divider()
                }

                // Personal tips
                if let cardBack = recipe.cardBack, cardBack.visibleSections.contains(.userTips), !cardBack.personalTips.isEmpty {
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

                // Pinned comments preview
                if let cardBack = recipe.cardBack, cardBack.visibleSections.contains(.pinnedComments), !cardBack.pinnedCommentIDs.isEmpty {
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

                                    if let author = comment.authorName {
                                        Text("— \(author)")
                                            .font(.caption)
                                            .foregroundStyle(HeirloomColors.secondaryText)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(recipe.cardBack?.backgroundStyle.color ?? HeirloomColors.cream)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    private var cardBackground: some View {
        Group {
            if let cardStyle = recipe.cardStyle {
                switch cardStyle.backgroundType {
                case .default, .solid:
                    Color(hex: cardStyle.backgroundColorHex ?? RecipeCardStyle.predefinedBackgroundColors[0])
                case .gradient:
                    LinearGradient(
                        colors: [
                            Color(hex: cardStyle.backgroundColorHex ?? "#FFF9E6"),
                            Color(hex: cardStyle.backgroundColorHex ?? "#FFE5D9").opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .pattern, .texture:
                    Color(hex: cardStyle.backgroundColorHex ?? "#FEFDFB")
                }
            } else {
                HeirloomColors.cream
            }
        }
    }

    private func stickerView(_ sticker: RecipeSticker) -> some View {
        Image(systemName: sticker.stickerName)
            .font(.system(size: 40 * sticker.scale))
            .foregroundStyle(Color(hex: sticker.colorHex ?? "#FF6B6B"))
            .opacity(sticker.opacity)
            .rotationEffect(.degrees(sticker.rotation))
            .position(
                x: CGFloat(sticker.positionX) * UIScreen.main.bounds.width * 0.9,
                y: CGFloat(sticker.positionY) * 400
            )
    }

    private func annotationView(_ annotation: RecipeAnnotation) -> some View {
        Text(annotation.text)
            .font(annotation.style.font)
            .foregroundStyle(Color(hex: annotation.colorHex))
            .padding(8)
            .background(
                annotation.style == .stickyNote ?
                AnyView(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: annotation.colorHex))
                ) :
                AnyView(Color.clear)
            )
            .rotationEffect(.degrees(annotation.rotation))
            .position(
                x: CGFloat(annotation.positionX) * UIScreen.main.bounds.width * 0.9,
                y: CGFloat(annotation.positionY) * 400
            )
    }

    private func loveMarksOverlay(_ cardStyle: RecipeCardStyle) -> some View {
        ZStack {
            // Coffee Stain
            if cardStyle.coffeeStainEnabled, let position = cardStyle.coffeeStainPosition {
                Circle()
                    .fill(Color.brown.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .position(coffeeStainPosition(position))
            }

            // Worn Edges
            if cardStyle.wornEdgesIntensity > 0 {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        Color.brown.opacity(cardStyle.wornEdgesIntensity * 0.3),
                        lineWidth: 2
                    )
            }
        }
    }

    private func coffeeStainPosition(_ position: RecipeCardStyle.CoffeeStainPosition) -> CGPoint {
        let width = UIScreen.main.bounds.width * 0.9
        let height: CGFloat = 400

        switch position {
        case .topLeft:
            return CGPoint(x: width * 0.2, y: height * 0.15)
        case .topRight:
            return CGPoint(x: width * 0.8, y: height * 0.15)
        case .bottomLeft:
            return CGPoint(x: width * 0.2, y: height * 0.85)
        case .bottomRight:
            return CGPoint(x: width * 0.8, y: height * 0.85)
        case .center:
            return CGPoint(x: width * 0.5, y: height * 0.5)
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                tabButton(tab: .background, icon: "photo.fill", title: "Background")
                tabButton(tab: .stickers, icon: "star.fill", title: "Stickers")
                tabButton(tab: .annotations, icon: "note.text", title: "Notes")
                tabButton(tab: .loveMarks, icon: "heart.fill", title: "Love Marks")
                tabButton(tab: .cardBack, icon: "rectangle.portrait.on.rectangle.portrait", title: "Card Back")
            }
        }
        .background(Color.gray.opacity(0.1))
    }

    private func tabButton(tab: PersonalizationTab, icon: String, title: String) -> some View {
        Button {
            withAnimation {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selectedTab == tab ? HeirloomColors.tomato.opacity(0.1) : Color.clear)
            .foregroundStyle(selectedTab == tab ? HeirloomColors.tomato : HeirloomColors.secondaryText)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Editor Content

    @ViewBuilder
    private var editorContent: some View {
        switch selectedTab {
        case .background:
            backgroundEditor
        case .stickers:
            stickersEditor
        case .annotations:
            annotationsEditor
        case .loveMarks:
            loveMarksEditor
        case .cardBack:
            cardBackEditor
        }
    }

    private var backgroundEditor: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
            Text("Background Color")
                .font(.body.bold())

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 60))],
                spacing: HeirloomSpacing.md
            ) {
                ForEach(RecipeCardStyle.predefinedBackgroundColors, id: \.self) { colorHex in
                    colorSwatch(colorHex)
                }
            }
        }
    }

    private func colorSwatch(_ colorHex: String) -> some View {
        let isSelected = recipe.cardStyle?.backgroundColorHex == colorHex

        return Button {
            selectBackgroundColor(colorHex)
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 60, height: 60)

                if isSelected {
                    Circle()
                        .strokeBorder(HeirloomColors.tomato, lineWidth: 3)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var stickersEditor: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Button {
                showingRecipeStickerPicker = true
            } label: {
                Label("Add RecipeSticker", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HeirloomColors.tomato)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }

            if let stickers = recipe.stickers, !stickers.isEmpty {
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Current RecipeStickers")
                        .font(.body.bold())

                    ForEach(stickers, id: \.id) { sticker in
                        HStack {
                            Image(systemName: sticker.stickerName)
                                .font(.title2)
                                .foregroundStyle(Color(hex: sticker.colorHex ?? "#FF6B6B"))

                            Text(sticker.stickerType.rawValue.capitalized)
                                .font(.body)

                            Spacer()

                            Button {
                                removeRecipeSticker(sticker)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("No stickers yet")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }

    private var annotationsEditor: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Button {
                selectedRecipeAnnotation = nil
                showingRecipeAnnotationEditor = true
            } label: {
                Label("Add Note", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HeirloomColors.tomato)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }

            if let annotations = recipe.annotations, !annotations.isEmpty {
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Current Notes")
                        .font(.body.bold())

                    ForEach(annotations, id: \.id) { annotation in
                        HStack {
                            Text(annotation.text)
                                .font(.body)
                                .lineLimit(2)

                            Spacer()

                            Button {
                                selectedRecipeAnnotation = annotation
                                showingRecipeAnnotationEditor = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(HeirloomColors.tomato)
                            }

                            Button {
                                removeRecipeAnnotation(annotation)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("No notes yet")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }

    private var loveMarksEditor: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
            // Coffee Stain
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                Toggle("Coffee Stain", isOn: Binding(
                    get: { recipe.cardStyle?.coffeeStainEnabled ?? false },
                    set: { enabled in
                        ensureRecipeCardStyle()
                        recipe.cardStyle?.coffeeStainEnabled = enabled
                        if enabled && recipe.cardStyle?.coffeeStainPosition == nil {
                            recipe.cardStyle?.coffeeStainPosition = .topRight
                        }
                    }
                ))
                .font(.body.bold())

                if recipe.cardStyle?.coffeeStainEnabled == true {
                    Picker("Position", selection: Binding(
                        get: { recipe.cardStyle?.coffeeStainPosition ?? .topRight },
                        set: { recipe.cardStyle?.coffeeStainPosition = $0 }
                    )) {
                        Text("Top Left").tag(RecipeCardStyle.CoffeeStainPosition.topLeft)
                        Text("Top Right").tag(RecipeCardStyle.CoffeeStainPosition.topRight)
                        Text("Bottom Left").tag(RecipeCardStyle.CoffeeStainPosition.bottomLeft)
                        Text("Bottom Right").tag(RecipeCardStyle.CoffeeStainPosition.bottomRight)
                        Text("Center").tag(RecipeCardStyle.CoffeeStainPosition.center)
                    }
                    .pickerStyle(.menu)
                }
            }

            // Worn Edges
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                Text("Worn Edges")
                    .font(.body.bold())

                Slider(
                    value: Binding(
                        get: { recipe.cardStyle?.wornEdgesIntensity ?? 0.0 },
                        set: { value in
                            ensureRecipeCardStyle()
                            recipe.cardStyle?.wornEdgesIntensity = value
                        }
                    ),
                    in: 0...1
                )
                .tint(HeirloomColors.tomato)

                Text("Intensity: \(Int((recipe.cardStyle?.wornEdgesIntensity ?? 0.0) * 100))%")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            // Auto Love Marks
            Toggle("Auto Love Marks", isOn: Binding(
                get: { recipe.cardStyle?.autoLoveMarks ?? false },
                set: { enabled in
                    ensureRecipeCardStyle()
                    recipe.cardStyle?.autoLoveMarks = enabled
                }
            ))
            .font(.body.bold())

            Text("Automatically add wear based on how many times you've cooked this recipe")
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    private var cardBackEditor: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
            // Flip button
            Button {
                withAnimation(.easeInOut(duration: 0.6)) {
                    isCardFlipped.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(isCardFlipped ? "Show Front" : "Show Back")
                        .font(.body.bold())
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(HeirloomColors.tomato)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }

            Divider()

            // Card Back Status
            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                Text("Card Back Content")
                    .font(.body.bold())

                if let cardBack = recipe.cardBack {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        if let note = cardBack.noteToFriends, !note.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Personal note added")
                                    .font(.body)
                            }
                        }

                        if !cardBack.personalTips.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("\(cardBack.personalTips.count) tips added")
                                    .font(.body)
                            }
                        }

                        if cardBack.userRating != nil {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Rating added")
                                    .font(.body)
                            }
                        }

                        if !cardBack.pinnedCommentIDs.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("\(cardBack.pinnedCommentIDs.count) comments pinned")
                                    .font(.body)
                            }
                        }
                    }
                } else {
                    Text("No content added yet")
                        .font(.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }

            Divider()

            // Edit Button
            Button {
                showCardBackEditor = true
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("Customize Card Back")
                        .font(.body.bold())
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(HeirloomColors.tomato.opacity(0.1))
                .foregroundStyle(HeirloomColors.tomato)
                .cornerRadius(12)
            }

            // Info text
            Text("The card back displays personal notes, tips, and selected comments for friends and family.")
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
                .padding(.top, HeirloomSpacing.sm)
        }
    }

    // MARK: - Actions

    private func ensureRecipeCardStyle() {
        if recipe.cardStyle == nil {
            let cardStyle = RecipeCardStyle()
            cardStyle.recipe = recipe
            recipe.cardStyle = cardStyle
            modelContext.insert(cardStyle)
        }
    }

    private func selectBackgroundColor(_ colorHex: String) {
        ensureRecipeCardStyle()
        recipe.cardStyle?.backgroundColorHex = colorHex
        recipe.cardStyle?.backgroundType = .solid
        recipe.cardStyle?.lastModified = Date()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func removeRecipeSticker(_ sticker: RecipeSticker) {
        modelContext.delete(sticker)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func removeRecipeAnnotation(_ annotation: RecipeAnnotation) {
        modelContext.delete(annotation)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func saveChanges() {
        do {
            try modelContext.save()

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            ToastManager.shared.success(title: "Card personalized!")

            dismiss()
        } catch {
            ToastManager.shared.error(
                title: "Failed to save",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Preview

#Preview {
    CardPersonalizationView(recipe: .example)
        .modelContainer(for: Recipe.self, inMemory: true)
        .toastContainer()
}
