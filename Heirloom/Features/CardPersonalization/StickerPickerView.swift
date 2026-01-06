import SwiftUI
import SwiftData

struct RecipeStickerPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    @Bindable var recipe: Recipe

    @State private var selectedCategory: RecipeSticker.StickerType = .food
    @State private var selectedRecipeStickerName: String?
    @State private var stickerScale: Double = 1.0
    @State private var stickerRotation: Double = 0.0
    @State private var stickerColor: String = "#FF6B6B"
    @State private var stickerOpacity: Double = 1.0
    @State private var positionX: Double = 0.5
    @State private var positionY: Double = 0.5

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview Section
                previewSection
                    .frame(height: 300)
                    .background(Color.gray.opacity(0.05))

                Divider()

                // Category Tabs
                categoryTabs

                Divider()

                // RecipeSticker Grid
                stickerGrid

                Divider()

                // Customization Controls
                if selectedRecipeStickerName != nil {
                    customizationControls
                }
            }
            .navigationTitle("Add RecipeSticker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addRecipeSticker()
                    }
                    .disabled(selectedRecipeStickerName == nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        ZStack {
            // Card Background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 10)
                .padding()

            // Preview RecipeSticker
            if let stickerName = selectedRecipeStickerName {
                Image(systemName: stickerName)
                    .font(.system(size: 60 * stickerScale))
                    .foregroundStyle(Color(hex: stickerColor))
                    .opacity(stickerOpacity)
                    .rotationEffect(.degrees(stickerRotation))
                    .position(
                        x: positionX * 300,
                        y: positionY * 300
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                positionX = max(0.1, min(0.9, value.location.x / 300))
                                positionY = max(0.1, min(0.9, value.location.y / 300))
                            }
                    )
            } else {
                VStack(spacing: HeirloomSpacing.md) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.gray.opacity(0.3))

                    Text("Select a sticker below")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
        }
        .frame(height: 300)
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HeirloomSpacing.md) {
                ForEach(RecipeSticker.allCategories, id: \.self) { category in
                    categoryTab(category)
                }
            }
            .padding(.horizontal, HeirloomSpacing.lg)
            .padding(.vertical, HeirloomSpacing.md)
        }
    }

    private func categoryTab(_ category: RecipeSticker.StickerType) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedCategory = category
                selectedRecipeStickerName = nil // Reset selection when changing category
            }

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            HStack(spacing: HeirloomSpacing.xs) {
                Image(systemName: categoryIcon(category))
                    .font(.body)

                Text(category.rawValue.capitalized)
                    .font(HeirloomFonts.bodyBold)
            }
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.vertical, HeirloomSpacing.sm)
            .background(isSelected ? HeirloomColors.tomato : Color.gray.opacity(0.1))
            .foregroundStyle(isSelected ? .white : HeirloomColors.primaryText)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    private func categoryIcon(_ category: RecipeSticker.StickerType) -> String {
        switch category {
        case .food:
            return "carrot.fill"
        case .badge:
            return "star.fill"
        case .emotional:
            return "face.smiling"
        case .seasonal:
            return "snowflake"
        }
    }

    // MARK: - RecipeSticker Grid

    private var stickerGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 70), spacing: HeirloomSpacing.md)
                ],
                spacing: HeirloomSpacing.md
            ) {
                ForEach(RecipeSticker.stickers(for: selectedCategory), id: \.self) { stickerName in
                    stickerButton(stickerName)
                }
            }
            .padding(HeirloomSpacing.lg)
        }
    }

    private func stickerButton(_ stickerName: String) -> some View {
        let isSelected = selectedRecipeStickerName == stickerName

        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedRecipeStickerName = stickerName
            }

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? HeirloomColors.tomato.opacity(0.1) : Color.gray.opacity(0.05))
                    .frame(width: 70, height: 70)

                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(HeirloomColors.tomato, lineWidth: 2)
                        .frame(width: 70, height: 70)
                }

                Image(systemName: stickerName)
                    .font(.system(size: 32))
                    .foregroundStyle(isSelected ? HeirloomColors.tomato : HeirloomColors.primaryText)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Customization Controls

    private var customizationControls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
                // Position Guide
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text("Position")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .textCase(.uppercase)

                    Text("Drag the sticker on the preview above to position it")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                // Scale
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    HStack {
                        Text("Size")
                            .font(HeirloomFonts.bodyBold)

                        Spacer()

                        Text("\(Int(stickerScale * 100))%")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    HStack(spacing: HeirloomSpacing.sm) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))
                            .onTapGesture {
                                withAnimation {
                                    stickerScale = max(0.5, stickerScale - 0.1)
                                }
                            }

                        Slider(value: $stickerScale, in: 0.5...2.0)
                            .tint(HeirloomColors.tomato)

                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(HeirloomColors.tomato)
                            .onTapGesture {
                                withAnimation {
                                    stickerScale = min(2.0, stickerScale + 0.1)
                                }
                            }
                    }
                }

                // Rotation
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    HStack {
                        Text("Rotation")
                            .font(HeirloomFonts.bodyBold)

                        Spacer()

                        Text("\(Int(stickerRotation))°")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.tomato)
                    }

                    Slider(value: $stickerRotation, in: 0...360)
                        .tint(HeirloomColors.tomato)
                }

                // Color
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Color")
                        .font(HeirloomFonts.bodyBold)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 50))],
                        spacing: HeirloomSpacing.sm
                    ) {
                        ForEach(stickerColorPalette, id: \.self) { colorHex in
                            colorSwatchButton(colorHex)
                        }
                    }
                }

                // Opacity
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    HStack {
                        Text("Opacity")
                            .font(HeirloomFonts.bodyBold)

                        Spacer()

                        Text("\(Int(stickerOpacity * 100))%")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Slider(value: $stickerOpacity, in: 0.3...1.0)
                        .tint(HeirloomColors.tomato)
                }

                // Reset Button
                Button {
                    withAnimation {
                        stickerScale = 1.0
                        stickerRotation = 0.0
                        stickerOpacity = 1.0
                        positionX = 0.5
                        positionY = 0.5
                    }

                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .foregroundStyle(HeirloomColors.primaryText)
                        .cornerRadius(12)
                }
            }
            .padding(HeirloomSpacing.lg)
        }
        .frame(maxHeight: 350)
    }

    private func colorSwatchButton(_ colorHex: String) -> some View {
        let isSelected = stickerColor == colorHex

        return Button {
            stickerColor = colorHex

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 50, height: 50)

                if isSelected {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                        .frame(width: 50, height: 50)

                    Circle()
                        .strokeBorder(HeirloomColors.tomato, lineWidth: 2)
                        .frame(width: 54, height: 54)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var stickerColorPalette: [String] {
        [
            "#FF6B6B", // Red
            "#4ECDC4", // Turquoise
            "#FFD93D", // Yellow
            "#95E1D3", // Mint
            "#F38181", // Coral
            "#AA96DA", // Lavender
            "#FCBAD3", // Pink
            "#FF8C42", // Orange
            "#6BCF7F", // Green
            "#4A90E2", // Blue
            "#8B4513", // Brown
            "#2C3E50"  // Dark
        ]
    }

    // MARK: - Actions

    private func addRecipeSticker() {
        guard let stickerName = selectedRecipeStickerName else { return }

        let sticker = RecipeSticker(
            stickerType: selectedCategory,
            stickerName: stickerName,
            positionX: positionX,
            positionY: positionY,
            scale: stickerScale,
            rotation: stickerRotation,
            colorHex: stickerColor,
            opacity: stickerOpacity
        )

        sticker.recipe = recipe
        modelContext.insert(sticker)

        // Add to recipe's stickers array
        if recipe.stickers == nil {
            recipe.stickers = []
        }
        recipe.stickers?.append(sticker)

        do {
            try modelContext.save()

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            toastManager.success(title: "RecipeSticker added!")

            // Track analytics
            analytics.track(event: .recipeEdited, properties: [
                "action": "sticker_added",
                "category": selectedCategory.rawValue
            ])

            dismiss()
        } catch {
            toastManager.error(
                title: "Failed to add sticker",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Preview

#Preview {
    RecipeStickerPickerView(recipe: .example)
        .modelContainer(for: Recipe.self, inMemory: true)
        .toastContainer()
}
