import SwiftUI
import SwiftData

struct CardPersonalizationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var milestoneManager: MilestoneManager { ServiceContainer.shared.resolve(MilestoneManager.self) }

    @Bindable var recipe: Recipe

    @State private var selectedTab: PersonalizationTab = .background
    @State private var showingRecipeStickerPicker = false
    @State private var showingRecipeAnnotationEditor = false
    @State private var selectedRecipeSticker: RecipeSticker?
    @State private var selectedRecipeAnnotation: RecipeAnnotation?
    @State private var isCardFlipped = false
    @State private var showCardBackEditor = false

    // Session-based editing
    @State private var editingSession: CardEditingSession?
    @State private var hasUnsavedChanges = false

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

                // Bottom Action Bar (for Style tabs only)
                if selectedTab == .background || selectedTab == .loveMarks {
                    Divider()
                    actionBar
                }
            }
            .navigationTitle("Personalize Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityLabel("Close")
                    .accessibilityHint("Close personalization")
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
            .onAppear {
                // Initialize editing session on first appearance
                if editingSession == nil {
                    editingSession = CardEditingSession(from: recipe.cardStyle)
                }
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
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 150)
                .overlay {
                    Text(recipe.title)
                        .font(HeirloomFonts.title3)
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
            if let session = editingSession {
                loveMarksOverlay(session)
            }
        }
        .background(HeirloomColors.cardBackground)
        .cornerRadius(16)
        .heirloomShadow(HeirloomShadows.card)
    }

    private var cardBackView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                // Recipe title
                Text(recipe.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(HeirloomColors.charcoal)

                // Attribution
                if let cardBack = recipe.cardBack, cardBack.visibleSections.contains(.attribution), cardBack.showAttribution {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        HStack {
                            Image(systemName: recipe.sourceType?.iconName ?? "book.closed.fill")
                            Text(recipe.sourceDisplayName)
                                .font(HeirloomFonts.subheadline)
                        }
                        .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Divider()
                }

                // Note to friends
                if let cardBack = recipe.cardBack, cardBack.visibleSections.contains(.noteToFriends), let note = cardBack.noteToFriends {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        Text("A Note from Me")
                            .font(HeirloomFonts.title3)

                        Text(note)
                            .font(HeirloomFonts.subheadline)
                            .italic()
                    }

                    Divider()
                }

                // User rating
                if let cardBack = recipe.cardBack, cardBack.visibleSections.contains(.userRating), let rating = cardBack.userRating {
                    HStack {
                        Text("My Rating:")
                            .font(HeirloomFonts.subheadline)
                            .foregroundStyle(HeirloomColors.secondaryText)
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundStyle(.yellow)
                                .font(HeirloomFonts.caption1)
                        }
                    }

                    Divider()
                }

                // Personal tips
                if let cardBack = recipe.cardBack, cardBack.visibleSections.contains(.userTips), !cardBack.personalTips.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("My Tips")
                            .font(HeirloomFonts.title3)

                        ForEach(cardBack.personalTips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                    .font(HeirloomFonts.caption1)
                                Text(tip)
                                    .font(HeirloomFonts.subheadline)
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
                                .font(HeirloomFonts.title3)

                            ForEach(Array(pinnedComments)) { comment in
                                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                                    Text(comment.text)
                                        .font(HeirloomFonts.subheadline)

                                    if let author = comment.authorName {
                                        Text("— \(author)")
                                            .font(HeirloomFonts.caption1)
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
        .heirloomShadow(HeirloomShadows.card)
    }

    private var cardBackground: some View {
        Group {
            if let session = editingSession {
                switch session.backgroundType {
                case .default, .solid:
                    Color(hex: session.backgroundColorHex ?? RecipeCardStyle.predefinedBackgroundColors[0])
                case .gradient:
                    LinearGradient(
                        colors: [
                            Color(hex: session.backgroundColorHex ?? "#FFF9E6"),
                            Color(hex: session.backgroundColorHex ?? "#FFE5D9").opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .pattern, .texture:
                    Color(hex: session.backgroundColorHex ?? "#FEFDFB")
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
            .padding(HeirloomSpacing.sm)
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

    private func loveMarksOverlay(_ session: CardEditingSession) -> some View {
        ZStack {
            // Coffee Stain
            if session.coffeeStainEnabled, let position = session.coffeeStainPosition {
                Circle()
                    .fill(Color.brown.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .position(coffeeStainPosition(position))
            }

            // Worn Edges
            if session.wornEdgesIntensity > 0 {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        Color.brown.opacity(session.wornEdgesIntensity * 0.3),
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

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Reset Button
            Button {
                resetChanges()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HeirloomSpacing.md)
                .background(HeirloomColors.secondaryText.opacity(0.1))
                .foregroundStyle(HeirloomColors.secondaryText)
                .cornerRadius(12)
            }
            .disabled(editingSession?.hasChanges == false)
            .opacity((editingSession?.hasChanges ?? false) ? 1.0 : 0.5)
            .accessibilityLabel("Reset Changes")
            .accessibilityHint("Revert to original card style")

            // Save Changes Button
            Button {
                saveChanges()
            } label: {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Update Card")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HeirloomSpacing.md)
                .background(HeirloomColors.tomato)
                .foregroundStyle(HeirloomColors.buttonTextLight)
                .cornerRadius(12)
            }
            .disabled(editingSession?.hasChanges == false)
            .opacity((editingSession?.hasChanges ?? false) ? 1.0 : 0.5)
            .accessibilityLabel("Update Card")
            .accessibilityHint("Save changes to card style")
        }
        .padding(.horizontal)
        .padding(.vertical, HeirloomSpacing.sm)
        .background(Color(.systemBackground))
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
            VStack(spacing: HeirloomSpacing.xs) {
                Image(systemName: icon)
                    .font(HeirloomFonts.title3)
                Text(title)
                    .font(HeirloomFonts.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selectedTab == tab ? HeirloomColors.tomato.opacity(0.1) : Color.clear)
            .foregroundStyle(selectedTab == tab ? HeirloomColors.tomato : HeirloomColors.secondaryText)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Opens \(title.lowercased()) customization options")
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
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
                .font(HeirloomFonts.bodyBold)

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
        let isSelected = editingSession?.backgroundColorHex == colorHex

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
        .accessibilityLabel("Background color \(colorHex)\(isSelected ? ", Selected" : "")")
        .accessibilityHint("Sets card background to this color")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Add Sticker")
            .accessibilityHint("Opens sticker picker to add decorations to your card")

            if let stickers = recipe.stickers, !stickers.isEmpty {
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Current RecipeStickers")
                        .font(HeirloomFonts.bodyBold)

                    ForEach(stickers, id: \.id) { sticker in
                        HStack {
                            Image(systemName: sticker.stickerName)
                                .font(.title2)
                                .foregroundStyle(Color(hex: sticker.colorHex ?? "#FF6B6B"))

                            Text(sticker.stickerType.rawValue.capitalized)
                                .font(HeirloomFonts.body)

                            Spacer()

                            Button {
                                removeRecipeSticker(sticker)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .accessibilityLabel("Delete \(sticker.stickerType.rawValue) sticker")
                            .accessibilityHint("Removes this sticker from the card")
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .accessibilityElement(children: .contain)
                    }
                }
            } else {
                Text("No stickers yet")
                    .font(HeirloomFonts.caption1)
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
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Add Note")
            .accessibilityHint("Opens editor to add a handwritten note to your card")

            if let annotations = recipe.annotations, !annotations.isEmpty {
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Current Notes")
                        .font(HeirloomFonts.bodyBold)

                    ForEach(annotations, id: \.id) { annotation in
                        HStack {
                            Text(annotation.text)
                                .font(HeirloomFonts.body)
                                .lineLimit(2)

                            Spacer()

                            Button {
                                selectedRecipeAnnotation = annotation
                                showingRecipeAnnotationEditor = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(HeirloomColors.tomato)
                            }
                            .accessibilityLabel("Edit note")
                            .accessibilityHint("Opens editor to modify this note")

                            Button {
                                removeRecipeAnnotation(annotation)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .accessibilityLabel("Delete note")
                            .accessibilityHint("Removes this note from the card")
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .accessibilityElement(children: .contain)
                    }
                }
            } else {
                Text("No notes yet")
                    .font(HeirloomFonts.caption1)
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
                    get: { editingSession?.coffeeStainEnabled ?? false },
                    set: { enabled in
                        editingSession?.coffeeStainEnabled = enabled
                        if enabled && editingSession?.coffeeStainPosition == nil {
                            editingSession?.coffeeStainPosition = .topRight
                        }
                    }
                ))
                .font(HeirloomFonts.bodyBold)
                .accessibilityLabel("Coffee Stain")
                .accessibilityHint("Adds a decorative coffee stain mark to your card")

                if editingSession?.coffeeStainEnabled == true {
                    Picker("Position", selection: Binding(
                        get: { editingSession?.coffeeStainPosition ?? .topRight },
                        set: { editingSession?.coffeeStainPosition = $0 }
                    )) {
                        Text("Top Left").tag(RecipeCardStyle.CoffeeStainPosition.topLeft)
                        Text("Top Right").tag(RecipeCardStyle.CoffeeStainPosition.topRight)
                        Text("Bottom Left").tag(RecipeCardStyle.CoffeeStainPosition.bottomLeft)
                        Text("Bottom Right").tag(RecipeCardStyle.CoffeeStainPosition.bottomRight)
                        Text("Center").tag(RecipeCardStyle.CoffeeStainPosition.center)
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Coffee Stain Position")
                    .accessibilityHint("Select where the coffee stain appears on the card")
                }
            }

            // Worn Edges
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                Text("Worn Edges")
                    .font(HeirloomFonts.bodyBold)

                Slider(
                    value: Binding(
                        get: { editingSession?.wornEdgesIntensity ?? 0.0 },
                        set: { value in
                            editingSession?.wornEdgesIntensity = value
                        }
                    ),
                    in: 0...1
                )
                .tint(HeirloomColors.tomato)
                .accessibilityLabel("Worn Edges Intensity")
                .accessibilityValue("\(Int((editingSession?.wornEdgesIntensity ?? 0.0) * 100)) percent")
                .accessibilityHint("Adjust how worn and aged the card edges appear")

                Text("Intensity: \(Int((editingSession?.wornEdgesIntensity ?? 0.0) * 100))%")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            // Auto Love Marks
            Toggle("Auto Love Marks", isOn: Binding(
                get: { editingSession?.autoLoveMarks ?? false },
                set: { enabled in
                    editingSession?.autoLoveMarks = enabled
                }
            ))
            .font(HeirloomFonts.bodyBold)
            .accessibilityLabel("Auto Love Marks")
            .accessibilityHint("Automatically add wear and tear based on how many times you've cooked this recipe")

            Text("Automatically add wear based on how many times you've cooked this recipe")
                .font(HeirloomFonts.caption1)
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
                        .font(HeirloomFonts.bodyBold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(HeirloomColors.tomato)
                .foregroundStyle(HeirloomColors.buttonTextLight)
                .cornerRadius(12)
            }
            .accessibilityLabel(isCardFlipped ? "Show Front" : "Show Back")
            .accessibilityHint("Flips the card to view the \(isCardFlipped ? "front" : "back") side")

            Divider()

            // Card Back Status
            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                Text("Card Back Content")
                    .font(HeirloomFonts.bodyBold)

                if let cardBack = recipe.cardBack {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        if let note = cardBack.noteToFriends, !note.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Personal note added")
                                    .font(HeirloomFonts.body)
                            }
                        }

                        if !cardBack.personalTips.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("\(cardBack.personalTips.count) tips added")
                                    .font(HeirloomFonts.body)
                            }
                        }

                        if cardBack.userRating != nil {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Rating added")
                                    .font(HeirloomFonts.body)
                            }
                        }

                        if !cardBack.pinnedCommentIDs.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("\(cardBack.pinnedCommentIDs.count) comments pinned")
                                    .font(HeirloomFonts.body)
                            }
                        }
                    }
                } else {
                    Text("No content added yet")
                        .font(HeirloomFonts.body)
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
                        .font(HeirloomFonts.bodyBold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(HeirloomColors.tomato.opacity(0.1))
                .foregroundStyle(HeirloomColors.tomato)
                .cornerRadius(12)
            }
            .accessibilityLabel("Customize Card Back")
            .accessibilityHint("Opens editor to add notes, tips, ratings, and comments to share")

            // Info text
            Text("The card back displays personal notes, tips, and selected comments for friends and family.")
                .font(HeirloomFonts.caption1)
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
        editingSession?.backgroundColorHex = colorHex
        editingSession?.backgroundType = .solid

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func resetChanges() {
        editingSession?.reset()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        toastManager.info(title: "Changes reset")
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
        guard let session = editingSession else { return }

        // Ensure cardStyle exists
        ensureRecipeCardStyle()

        // Apply editing session changes to the recipe's cardStyle
        if let cardStyle = recipe.cardStyle {
            session.applyToCardStyle(cardStyle)
        }

        do {
            try modelContext.save()

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            toastManager.success(title: "Card updated!")

            // TODO: Re-enable milestone celebrations after redesign
            // Check card personalization milestone
            // milestoneManager.checkFirstCardPersonalization()

            dismiss()
        } catch {
            toastManager.error(
                title: "Failed to save changes",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Card Editing Session

/// Session-based editing model that captures original state and tracks changes
struct CardEditingSession {
    // Original snapshot (for Reset functionality)
    let originalBackgroundColorHex: String?
    let originalBackgroundType: RecipeCardStyle.BackgroundType
    let originalCoffeeStainEnabled: Bool
    let originalCoffeeStainPosition: RecipeCardStyle.CoffeeStainPosition?
    let originalWornEdgesIntensity: Double
    let originalAutoLoveMarks: Bool

    // Working copy (current edits)
    var backgroundColorHex: String?
    var backgroundType: RecipeCardStyle.BackgroundType
    var coffeeStainEnabled: Bool
    var coffeeStainPosition: RecipeCardStyle.CoffeeStainPosition?
    var wornEdgesIntensity: Double
    var autoLoveMarks: Bool

    init(from cardStyle: RecipeCardStyle?) {
        // Capture original state
        self.originalBackgroundColorHex = cardStyle?.backgroundColorHex ?? RecipeCardStyle.predefinedBackgroundColors[0]
        self.originalBackgroundType = cardStyle?.backgroundType ?? .solid
        self.originalCoffeeStainEnabled = cardStyle?.coffeeStainEnabled ?? false
        self.originalCoffeeStainPosition = cardStyle?.coffeeStainPosition
        self.originalWornEdgesIntensity = cardStyle?.wornEdgesIntensity ?? 0.0
        self.originalAutoLoveMarks = cardStyle?.autoLoveMarks ?? false

        // Initialize working copy with original values
        self.backgroundColorHex = originalBackgroundColorHex
        self.backgroundType = originalBackgroundType
        self.coffeeStainEnabled = originalCoffeeStainEnabled
        self.coffeeStainPosition = originalCoffeeStainPosition
        self.wornEdgesIntensity = originalWornEdgesIntensity
        self.autoLoveMarks = originalAutoLoveMarks
    }

    var hasChanges: Bool {
        return backgroundColorHex != originalBackgroundColorHex ||
               backgroundType != originalBackgroundType ||
               coffeeStainEnabled != originalCoffeeStainEnabled ||
               coffeeStainPosition != originalCoffeeStainPosition ||
               wornEdgesIntensity != originalWornEdgesIntensity ||
               autoLoveMarks != originalAutoLoveMarks
    }

    mutating func reset() {
        backgroundColorHex = originalBackgroundColorHex
        backgroundType = originalBackgroundType
        coffeeStainEnabled = originalCoffeeStainEnabled
        coffeeStainPosition = originalCoffeeStainPosition
        wornEdgesIntensity = originalWornEdgesIntensity
        autoLoveMarks = originalAutoLoveMarks
    }

    func applyToCardStyle(_ cardStyle: RecipeCardStyle) {
        cardStyle.backgroundColorHex = backgroundColorHex
        cardStyle.backgroundType = backgroundType
        cardStyle.coffeeStainEnabled = coffeeStainEnabled
        cardStyle.coffeeStainPosition = coffeeStainPosition
        cardStyle.wornEdgesIntensity = wornEdgesIntensity
        cardStyle.autoLoveMarks = autoLoveMarks
        cardStyle.lastModified = Date()
    }
}

// MARK: - Preview

#Preview {
    CardPersonalizationView(recipe: .example)
        .modelContainer(for: Recipe.self, inMemory: true)
        .toastContainer()
}
