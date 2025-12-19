import SwiftUI

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
        }
        .onAppear {
            // Initialize to correct state
            if isFlipped {
                rotation = 180
                backOpacity = 1
            }
        }
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
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("• 2 cups flour")
                                Text("• 1 cup sugar")
                                Text("• 2 eggs")
                                Text("• 1 tsp vanilla")
                            }
                            .font(.subheadline)

                            Spacer()

                            HStack {
                                Image(systemName: "book.closed.fill")
                                Text("Family Recipe")
                            }
                            .font(.caption)
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
                                .font(.headline)

                            Text("\"The secret is not to overmix! My grandmother made these every Sunday.\"")
                                .font(.subheadline)
                                .italic()

                            Divider()

                            Text("Top Comments")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                    Text("Doubled the vanilla - perfect!")
                                        .font(.caption)
                                }

                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                    Text("Works great with gluten-free flour")
                                        .font(.caption)
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
                        .font(.headline)
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

// MARK: - Placeholder Views (to be implemented)

private struct RecipeCardFrontView: View {
    let recipe: Recipe

    var body: some View {
        // TODO: Implement proper recipe card front
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(HeirloomColors.cream)

            VStack {
                Text(recipe.title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Front of card")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

private struct RecipeCardBackView: View {
    let recipe: Recipe

    var body: some View {
        // TODO: Implement proper recipe card back
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(HeirloomColors.amber)

            VStack {
                Text(recipe.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Back of card")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let cardBack = recipe.cardBack {
                    if let note = cardBack.noteToFriends {
                        Text(note)
                            .font(.subheadline)
                            .italic()
                            .padding()
                    }
                }
            }
            .padding()
        }
    }
}
