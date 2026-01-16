import SwiftUI
import AVFoundation

/// Generic flip card component with smooth 3D rotation animation
/// Perfect for recipe cards that show content on front and social features on back
struct FlipCard<Front: View, Back: View>: View {
    // MARK: - Properties

    @Binding var isFlipped: Bool
    let front: () -> Front
    let back: () -> Back

    @State private var rotation: Double = 0
    @State private var backOpacity: Double = 0

    // Animation config
    private let flipDuration: Double = 0.6
    private let flipAxis: (x: CGFloat, y: CGFloat, z: CGFloat) = (0, 1, 0) // Y-axis rotation

    // MARK: - Initialization

    init(
        isFlipped: Binding<Bool>,
        @ViewBuilder front: @escaping () -> Front,
        @ViewBuilder back: @escaping () -> Back
    ) {
        self._isFlipped = isFlipped
        self.front = front
        self.back = back
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Front side
            front()
                .opacity(backOpacity < 0.5 ? 1 : 0)
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: flipAxis,
                    perspective: 0.5
                )

            // Back side
            back()
                .opacity(backOpacity >= 0.5 ? 1 : 0)
                .rotation3DEffect(
                    .degrees(rotation + 180),
                    axis: flipAxis,
                    perspective: 0.5
                )
        }
        .onChange(of: isFlipped) { oldValue, newValue in
            withAnimation(.easeInOut(duration: flipDuration)) {
                if newValue {
                    // Flip to back
                    rotation = 180
                    backOpacity = 1
                } else {
                    // Flip to front
                    rotation = 0
                    backOpacity = 0
                }
            }

            // Haptic feedback (if enabled)
            let hapticsEnabled = UserDefaults.standard.object(forKey: "cardFlipHapticsEnabled") as? Bool ?? true
            if hapticsEnabled {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }

            // Sound effect (if enabled)
            let soundEnabled = UserDefaults.standard.object(forKey: "cardFlipSoundEnabled") as? Bool ?? true
            if soundEnabled {
                playFlipSound()
            }

            // TODO: Add VoiceOver announcement once AccessibilityAnnouncementService is added to Xcode project
            // Task { @MainActor in
            //     AccessibilityAnnouncementService.shared.announceCardFlipped(showingBack: newValue)
            // }
        }
        .onAppear {
            // Initialize to correct state
            if isFlipped {
                rotation = 180
                backOpacity = 1
            }
        }
    }

    // MARK: - Sound Effect

    private func playFlipSound() {
        // Use a subtle system sound for card flip
        // SystemSoundID 1104 is a light "pop" sound that works well for card flips
        AudioServicesPlaySystemSound(1104)
    }
}

// MARK: - Convenience Initializers

extension FlipCard {
    /// Simplified initializer with state management
    init(
        isFlipped: Bool,
        onFlip: @escaping (Bool) -> Void,
        @ViewBuilder front: @escaping () -> Front,
        @ViewBuilder back: @escaping () -> Back
    ) where Front == AnyView, Back == AnyView {
        self.init(
            isFlipped: .constant(isFlipped),
            front: front,
            back: back
        )
    }
}

// MARK: - Preview

#Preview("Flip Card - Recipe Example") {
    struct PreviewWrapper: View {
        @State private var isFlipped = false

        var body: some View {
            VStack(spacing: 20) {
                FlipCard(isFlipped: $isFlipped) {
                    // Front: Recipe card
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(HeirloomColors.cream)
                            .shadow(radius: 10)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Grandma's Cookies")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Ingredients")
                                .font(HeirloomFonts.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("• 2 cups flour")
                                Text("• 1 cup sugar")
                                Text("• 2 eggs")
                                Text("• 1 tsp vanilla")
                            }
                            .font(HeirloomFonts.subheadline)

                            Spacer()

                            HStack {
                                Image(systemName: "book.closed.fill")
                                Text("Family Recipe")
                            }
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                        }
                        .padding(24)
                    }
                    .frame(width: 300, height: 400)
                } back: {
                    // Back: Social features
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(HeirloomColors.amber)
                            .shadow(radius: 10)

                        VStack(alignment: .leading, spacing: 16) {
                            Text("From Grandma Rose")
                                .font(.title3)
                                .fontWeight(.semibold)

                            Divider()

                            Text("Note to Friends")
                                .font(HeirloomFonts.title3)

                            Text("\"The secret is not to overmix! My grandmother made these every Sunday.\"")
                                .font(HeirloomFonts.subheadline)
                                .italic()

                            Divider()

                            Text("Top Comments")
                                .font(HeirloomFonts.title3)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                    Text("Doubled the vanilla - perfect!")
                                        .font(HeirloomFonts.caption1)
                                }

                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                    Text("Works great with gluten-free flour")
                                        .font(HeirloomFonts.caption1)
                                }
                            }

                            Spacer()
                        }
                        .padding(24)
                    }
                    .frame(width: 300, height: 400)
                }

                // Flip button
                Button(action: {
                    isFlipped.toggle()
                }) {
                    Label(isFlipped ? "Show Front" : "Show Back", systemImage: "arrow.triangle.2.circlepath")
                        .font(HeirloomFonts.title3)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding()
        }
    }

    return PreviewWrapper()
}

// MARK: - Recipe-Specific Flip Card

/// Pre-configured flip card specifically for recipes
struct RecipeFlipCard: View {
    let recipe: Recipe
    @Binding var isFlipped: Bool

    var body: some View {
        FlipCard(isFlipped: $isFlipped) {
            RecipeCardFrontView(recipe: recipe)
        } back: {
            RecipeCardBackView(recipe: recipe)
        }
    }
}

// MARK: - Recipe Card Front View

private struct RecipeCardFrontView: View {
    let recipe: Recipe

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Layer
                cardBackground

                // Content Layer
                VStack(spacing: 12) {
                    // Recipe Image or Title
                    recipeImageSection
                        .frame(height: geometry.size.height * 0.45)

                    // Recipe Title (if image exists)
                    if recipe.imageFileName != nil {
                        Text(recipe.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(HeirloomColors.primaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    Spacer()

                    // Source Attribution Badge
                    sourceAttribution
                        .padding(.bottom, 16)
                }
                .padding(.top, 20)

                // Stickers Layer (absolute positioning)
                if let stickers = recipe.stickers {
                    ForEach(stickers, id: \.id) { sticker in
                        stickerView(sticker, in: geometry.size)
                    }
                }

                // Annotations Layer (absolute positioning)
                if let annotations = recipe.annotations {
                    ForEach(annotations, id: \.id) { annotation in
                        annotationView(annotation, in: geometry.size)
                    }
                }

                // Love Marks Overlay (on top of everything)
                if let cardStyle = recipe.cardStyle {
                    loveMarksOverlay(cardStyle, in: geometry.size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        }
    }

    // MARK: - Background

    private var cardBackground: some View {
        Group {
            if let cardStyle = recipe.cardStyle {
                switch cardStyle.backgroundType {
                case .default, .solid:
                    Color(hex: cardStyle.backgroundColorHex ?? RecipeCardStyle.predefinedBackgroundColors[0])
                case .gradient:
                    LinearGradient(
                        colors: [
                            Color(hex: cardStyle.backgroundColorHex ?? "#FEFDFB"),
                            Color(hex: cardStyle.backgroundColorHex ?? "#FEFDFB").opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .pattern, .texture:
                    Color(hex: cardStyle.backgroundColorHex ?? RecipeCardStyle.predefinedBackgroundColors[0])
                        .overlay {
                            // Pattern/texture overlay (simplified for now)
                            Color.black.opacity(0.02)
                        }
                }
            } else {
                // Default cream background
                HeirloomColors.cream
            }
        }
    }

    // MARK: - Recipe Image

    private var recipeImageSection: some View {
        Group {
            if recipe.imageFileName != nil {
                // Actual recipe image using AsyncRecipeImage component
                AsyncRecipeImage(
                    imageFileName: recipe.imageFileName,
                    firebaseImageURL: recipe.firebaseImageURL,
                    placeholder: recipe.sourceType?.iconName ?? "fork.knife"
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Placeholder with title
                imagePlaceholder
            }
        }
        .padding(.horizontal, 16)
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.15))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 32))
                        .foregroundStyle(HeirloomColors.secondaryText)

                    if recipe.imageFileName == nil {
                        Text(recipe.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(HeirloomColors.primaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .lineLimit(3)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Source Attribution

    private var sourceAttribution: some View {
        HStack(spacing: 6) {
            Image(systemName: recipe.sourceType?.iconName ?? "square.and.pencil")
                .font(HeirloomFonts.caption1)
            Text(recipe.sourceDisplayName)
                .font(HeirloomFonts.caption1)
        }
        .foregroundStyle(HeirloomColors.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.8))
        )
    }

    // MARK: - Stickers

    private func stickerView(_ sticker: RecipeSticker, in size: CGSize) -> some View {
        Image(systemName: sticker.stickerName)
            .font(.system(size: 40 * sticker.scale))
            .foregroundStyle(Color(hex: sticker.colorHex ?? "#FF6B6B"))
            .opacity(sticker.opacity)
            .rotationEffect(.degrees(sticker.rotation))
            .position(
                x: CGFloat(sticker.positionX) * size.width,
                y: CGFloat(sticker.positionY) * size.height
            )
    }

    // MARK: - Annotations

    private func annotationView(_ annotation: RecipeAnnotation, in size: CGSize) -> some View {
        Text(annotation.text)
            .font(.system(size: 14))
            .foregroundStyle(Color(hex: annotation.colorHex))
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.yellow.opacity(0.3))
            )
            .rotationEffect(.degrees(annotation.rotation))
            .position(
                x: CGFloat(annotation.positionX) * size.width,
                y: CGFloat(annotation.positionY) * size.height
            )
    }

    // MARK: - Love Marks

    private func loveMarksOverlay(_ cardStyle: RecipeCardStyle, in size: CGSize) -> some View {
        ZStack {
            // Coffee Stain
            if cardStyle.coffeeStainEnabled, let position = cardStyle.coffeeStainPosition {
                Circle()
                    .fill(Color.brown.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .blur(radius: 8)
                    .position(coffeeStainPosition(position, in: size))
            }

            // Worn Edges
            if cardStyle.wornEdgesIntensity > 0 {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        Color.brown.opacity(cardStyle.wornEdgesIntensity * 0.3),
                        lineWidth: 2
                    )
            }
        }
    }

    private func coffeeStainPosition(_ position: RecipeCardStyle.CoffeeStainPosition, in size: CGSize) -> CGPoint {
        switch position {
        case .topLeft:
            return CGPoint(x: size.width * 0.2, y: size.height * 0.15)
        case .topRight:
            return CGPoint(x: size.width * 0.8, y: size.height * 0.15)
        case .bottomLeft:
            return CGPoint(x: size.width * 0.2, y: size.height * 0.85)
        case .bottomRight:
            return CGPoint(x: size.width * 0.8, y: size.height * 0.85)
        case .center:
            return CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        }
    }
}

private struct RecipeCardBackView: View {
    let recipe: Recipe

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Recipe Title
                Text(recipe.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(HeirloomColors.charcoal)

                // Attribution Section
                if let cardBack = recipe.cardBack,
                   cardBack.visibleSections.contains(.attribution),
                   cardBack.showAttribution {
                    attributionSection
                    Divider()
                }

                // Note to Friends Section
                if let cardBack = recipe.cardBack,
                   cardBack.visibleSections.contains(.noteToFriends),
                   let note = cardBack.noteToFriends, !note.isEmpty {
                    noteToFriendsSection(note)
                    Divider()
                }

                // User Rating Section
                if let cardBack = recipe.cardBack,
                   cardBack.visibleSections.contains(.userRating),
                   let rating = cardBack.userRating {
                    ratingSection(rating)
                    Divider()
                }

                // Personal Tips Section
                if let cardBack = recipe.cardBack,
                   cardBack.visibleSections.contains(.userTips),
                   !cardBack.personalTips.isEmpty {
                    tipsSection(cardBack.personalTips)
                    Divider()
                }

                // Pinned Comments Section
                if let cardBack = recipe.cardBack,
                   cardBack.visibleSections.contains(.pinnedComments),
                   !cardBack.pinnedCommentIDs.isEmpty {
                    pinnedCommentsSection(cardBack)
                }

                // Generational Lineage (if passed down)
                if recipe.passedDownBy != nil {
                    lineageSection
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    // MARK: - Background

    private var cardBackBackground: Color {
        if let cardBack = recipe.cardBack {
            switch cardBack.backgroundStyle {
            case .cream:
                return HeirloomColors.cream
            case .vintage:
                return HeirloomColors.amber
            case .lined:
                return HeirloomColors.cream
            case .grid:
                return Color(hex: "#F8F3E8")
            case .photo:
                return HeirloomColors.cream.opacity(0.9)
            case .solid:
                return Color(hex: cardBack.textColor).opacity(0.05)
            }
        }
        return HeirloomColors.cream
    }

    // MARK: - Sections

    private var attributionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: sourceIcon)
                    .font(HeirloomFonts.subheadline)
                Text(sourceText)
                    .font(HeirloomFonts.subheadline)
            }
            .foregroundStyle(HeirloomColors.secondaryText)

            if let customAttribution = recipe.cardBack?.customAttributionText {
                Text(customAttribution)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .italic()
            }
        }
    }

    private func noteToFriendsSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A Note from Me")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.charcoal)

            Text(note)
                .font(HeirloomFonts.subheadline)
                .foregroundStyle(HeirloomColors.primaryText)
                .italic()
        }
    }

    private func ratingSection(_ rating: Int) -> some View {
        HStack(spacing: 8) {
            Text("My Rating:")
                .font(HeirloomFonts.subheadline)
                .foregroundStyle(HeirloomColors.secondaryText)

            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .foregroundStyle(.yellow)
                        .font(HeirloomFonts.caption1)
                }
            }
        }
    }

    private func tipsSection(_ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Tips")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.charcoal)

            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(HeirloomFonts.caption1)
                    Text(tip)
                        .font(HeirloomFonts.subheadline)
                        .foregroundStyle(HeirloomColors.primaryText)
                }
            }
        }
    }

    private func pinnedCommentsSection(_ cardBack: RecipeCardBack) -> some View {
        let pinnedComments = recipe.comments?
            .filter { cardBack.pinnedCommentIDs.contains($0.id) }
            .prefix(cardBack.maxCommentsToDisplay) ?? []

        return Group {
            if !pinnedComments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Highlighted Comments")
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.charcoal)

                    ForEach(Array(pinnedComments)) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.text)
                                .font(HeirloomFonts.subheadline)
                                .foregroundStyle(HeirloomColors.primaryText)

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

    private var lineageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(HeirloomColors.tomato)
                Image(systemName: "arrow.right")
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .font(HeirloomFonts.caption1)
                Image(systemName: "person.fill")
                    .foregroundStyle(HeirloomColors.tomato)
            }
            .font(HeirloomFonts.subheadline)

            Text("Passed down with love")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .italic()
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var sourceIcon: String {
        recipe.sourceType?.iconName ?? "square.and.pencil"
    }

    private var sourceText: String {
        recipe.sourceDisplayName
    }
}

