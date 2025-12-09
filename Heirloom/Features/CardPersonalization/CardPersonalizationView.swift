import SwiftUI
import SwiftData

struct CardPersonalizationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var recipe: Recipe

    @State private var selectedTab: PersonalizationTab = .background
    @State private var showingStickerPicker = false
    @State private var showingAnnotationEditor = false
    @State private var selectedSticker: Sticker?
    @State private var selectedAnnotation: Annotation?

    enum PersonalizationTab {
        case background
        case stickers
        case annotations
        case loveMarks
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
            .sheet(isPresented: $showingStickerPicker) {
                StickerPickerView(recipe: recipe)
            }
            .sheet(isPresented: $showingAnnotationEditor) {
                AnnotationEditorView(recipe: recipe, annotation: selectedAnnotation)
            }
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        ZStack {
            // Background
            cardBackground

            // Recipe Image (simplified)
            RoundedRectangle(cornerRadius: 12)
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

            // Stickers
            if let stickers = recipe.stickers {
                ForEach(stickers, id: \.id) { sticker in
                    stickerView(sticker)
                        .onTapGesture {
                            selectedSticker = sticker
                        }
                }
            }

            // Annotations
            if let annotations = recipe.annotations {
                ForEach(annotations, id: \.id) { annotation in
                    annotationView(annotation)
                        .onTapGesture {
                            selectedAnnotation = annotation
                            showingAnnotationEditor = true
                        }
                }
            }

            // Love Marks
            if let cardStyle = recipe.cardStyle {
                loveMarksOverlay(cardStyle)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(3/4, contentMode: .fit)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    private var cardBackground: some View {
        Group {
            if let cardStyle = recipe.cardStyle {
                switch cardStyle.backgroundType {
                case .default, .solid:
                    Color(hex: cardStyle.backgroundColorHex ?? CardStyle.predefinedBackgroundColors[0]) ?? HeirloomColors.cream
                case .gradient:
                    LinearGradient(
                        colors: [
                            Color(hex: cardStyle.backgroundColorHex ?? "#FFF9E6") ?? .white,
                            Color(hex: cardStyle.backgroundColorHex ?? "#FFE5D9") ?? .white.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                case .pattern, .texture:
                    Color(hex: cardStyle.backgroundColorHex ?? "#FEFDFB") ?? HeirloomColors.cream
                }
            } else {
                HeirloomColors.cream
            }
        }
    }

    private func stickerView(_ sticker: Sticker) -> some View {
        Image(systemName: sticker.stickerName)
            .font(.system(size: 40 * sticker.scale))
            .foregroundStyle(Color(hex: sticker.colorHex ?? "#FF6B6B") ?? .red)
            .opacity(sticker.opacity)
            .rotationEffect(.degrees(sticker.rotation))
            .position(
                x: CGFloat(sticker.positionX) * UIScreen.main.bounds.width * 0.9,
                y: CGFloat(sticker.positionY) * 400
            )
    }

    private func annotationView(_ annotation: Annotation) -> some View {
        Text(annotation.text)
            .font(annotation.style.font)
            .foregroundStyle(Color(hex: annotation.colorHex) ?? Color.yellow)
            .padding(8)
            .background(
                annotation.style == .stickyNote ?
                AnyView(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: annotation.colorHex) ?? Color.yellow)
                ) :
                AnyView(Color.clear)
            )
            .rotationEffect(.degrees(annotation.rotation))
            .position(
                x: CGFloat(annotation.positionX) * UIScreen.main.bounds.width * 0.9,
                y: CGFloat(annotation.positionY) * 400
            )
    }

    private func loveMarksOverlay(_ cardStyle: CardStyle) -> some View {
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

    private func coffeeStainPosition(_ position: CardStyle.CoffeeStainPosition) -> CGPoint {
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
        HStack(spacing: 0) {
            tabButton(tab: .background, icon: "photo.fill", title: "Background")
            tabButton(tab: .stickers, icon: "star.fill", title: "Stickers")
            tabButton(tab: .annotations, icon: "note.text", title: "Notes")
            tabButton(tab: .loveMarks, icon: "heart.fill", title: "Love Marks")
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
                ForEach(CardStyle.predefinedBackgroundColors, id: \.self) { colorHex in
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
                    .fill(Color(hex: colorHex) ?? .gray)
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
                showingStickerPicker = true
            } label: {
                Label("Add Sticker", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HeirloomColors.tomato)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }

            if let stickers = recipe.stickers, !stickers.isEmpty {
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Current Stickers")
                        .font(HeirloomFonts.bodyBold)

                    ForEach(stickers, id: \.id) { sticker in
                        HStack {
                            Image(systemName: sticker.stickerName)
                                .font(.title2)
                                .foregroundStyle(Color(hex: sticker.colorHex ?? "#FF6B6B") ?? .red)

                            Text(sticker.stickerType.rawValue.capitalized)
                                .font(HeirloomFonts.body)

                            Spacer()

                            Button {
                                removeSticker(sticker)
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
                selectedAnnotation = nil
                showingAnnotationEditor = true
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
                        .font(HeirloomFonts.bodyBold)

                    ForEach(annotations, id: \.id) { annotation in
                        HStack {
                            Text(annotation.text)
                                .font(HeirloomFonts.body)
                                .lineLimit(2)

                            Spacer()

                            Button {
                                selectedAnnotation = annotation
                                showingAnnotationEditor = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(HeirloomColors.tomato)
                            }

                            Button {
                                removeAnnotation(annotation)
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
                    get: { recipe.cardStyle?.coffeeStainEnabled ?? false },
                    set: { enabled in
                        ensureCardStyle()
                        recipe.cardStyle?.coffeeStainEnabled = enabled
                        if enabled && recipe.cardStyle?.coffeeStainPosition == nil {
                            recipe.cardStyle?.coffeeStainPosition = .topRight
                        }
                    }
                ))
                .font(HeirloomFonts.bodyBold)

                if recipe.cardStyle?.coffeeStainEnabled == true {
                    Picker("Position", selection: Binding(
                        get: { recipe.cardStyle?.coffeeStainPosition ?? .topRight },
                        set: { recipe.cardStyle?.coffeeStainPosition = $0 }
                    )) {
                        Text("Top Left").tag(CardStyle.CoffeeStainPosition.topLeft)
                        Text("Top Right").tag(CardStyle.CoffeeStainPosition.topRight)
                        Text("Bottom Left").tag(CardStyle.CoffeeStainPosition.bottomLeft)
                        Text("Bottom Right").tag(CardStyle.CoffeeStainPosition.bottomRight)
                        Text("Center").tag(CardStyle.CoffeeStainPosition.center)
                    }
                    .pickerStyle(.menu)
                }
            }

            // Worn Edges
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                Text("Worn Edges")
                    .font(HeirloomFonts.bodyBold)

                Slider(
                    value: Binding(
                        get: { recipe.cardStyle?.wornEdgesIntensity ?? 0.0 },
                        set: { value in
                            ensureCardStyle()
                            recipe.cardStyle?.wornEdgesIntensity = value
                        }
                    ),
                    in: 0...1
                )
                .tint(HeirloomColors.tomato)

                Text("Intensity: \(Int((recipe.cardStyle?.wornEdgesIntensity ?? 0.0) * 100))%")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            // Auto Love Marks
            Toggle("Auto Love Marks", isOn: Binding(
                get: { recipe.cardStyle?.autoLoveMarks ?? false },
                set: { enabled in
                    ensureCardStyle()
                    recipe.cardStyle?.autoLoveMarks = enabled
                }
            ))
            .font(HeirloomFonts.bodyBold)

            Text("Automatically add wear based on how many times you've cooked this recipe")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Actions

    private func ensureCardStyle() {
        if recipe.cardStyle == nil {
            let cardStyle = CardStyle()
            cardStyle.recipe = recipe
            recipe.cardStyle = cardStyle
            modelContext.insert(cardStyle)
        }
    }

    private func selectBackgroundColor(_ colorHex: String) {
        ensureCardStyle()
        recipe.cardStyle?.backgroundColorHex = colorHex
        recipe.cardStyle?.backgroundType = .solid
        recipe.cardStyle?.lastModified = Date()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func removeSticker(_ sticker: Sticker) {
        modelContext.delete(sticker)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func removeAnnotation(_ annotation: Annotation) {
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
