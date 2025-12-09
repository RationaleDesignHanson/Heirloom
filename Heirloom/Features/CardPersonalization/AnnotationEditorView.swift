import SwiftUI
import SwiftData

struct RecipeAnnotationEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var recipe: Recipe

    let annotation: RecipeAnnotation?

    @State private var text: String = ""
    @State private var style: RecipeAnnotation.AnnotationStyle = .stickyNote
    @State private var colorHex: String = "#FFD93D"
    @State private var fontSize: Double = 14.0
    @State private var rotation: Double = 0.0
    @State private var positionX: Double = 0.5
    @State private var positionY: Double = 0.5

    private var isEditing: Bool {
        annotation != nil
    }

    init(recipe: Recipe, annotation: RecipeAnnotation? = nil) {
        self.recipe = recipe
        self.annotation = annotation

        if let annotation = annotation {
            _text = State(initialValue: annotation.text)
            _style = State(initialValue: annotation.style)
            _colorHex = State(initialValue: annotation.colorHex)
            _fontSize = State(initialValue: annotation.fontSize)
            _rotation = State(initialValue: annotation.rotation)
            _positionX = State(initialValue: annotation.positionX)
            _positionY = State(initialValue: annotation.positionY)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview Section
                previewSection
                    .frame(height: 300)
                    .background(Color.gray.opacity(0.05))

                Divider()

                // Editor Controls
                editorControls
            }
            .navigationTitle(isEditing ? "Edit Note" : "Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveRecipeAnnotation()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
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

            // Preview RecipeAnnotation
            if !text.isEmpty {
                annotationPreview
                    .position(
                        x: positionX * 300,
                        y: positionY * 300
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                positionX = max(0.15, min(0.85, value.location.x / 300))
                                positionY = max(0.15, min(0.85, value.location.y / 300))
                            }
                    )
            } else {
                VStack(spacing: HeirloomSpacing.md) {
                    Image(systemName: "note.text")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.gray.opacity(0.3))

                    Text("Type your note below")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
        }
        .frame(height: 300)
    }

    private var annotationPreview: some View {
        Group {
            switch style {
            case .stickyNote:
                stickyNotePreview
            case .handwritten:
                handwrittenPreview
            case .marker:
                markerPreview
            }
        }
        .rotationEffect(.degrees(rotation))
    }

    private var stickyNotePreview: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .regular, design: .rounded))
            .foregroundStyle(.black)
            .padding(12)
            .frame(minWidth: 80, maxWidth: 180)
            .background(
                ZStack {
                    Rectangle()
                        .fill(Color(hex: colorHex))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)

                    // Paper texture lines
                    VStack(spacing: 0) {
                        ForEach(0..<5) { _ in
                            Rectangle()
                                .fill(Color.black.opacity(0.05))
                                .frame(height: 1)
                                .padding(.vertical, 6)
                        }
                    }
                }
            )
            .overlay(
                // Top tape effect
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 16)
                    .offset(y: -42)
            )
    }

    private var handwrittenPreview: some View {
        Text(text)
            .font(.custom("Bradley Hand", size: fontSize).weight(.regular))
            .foregroundStyle(Color(hex: colorHex))
            .padding(8)
            .background(Color.clear)
    }

    private var markerPreview: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(hex: colorHex))
            )
    }

    // MARK: - Editor Controls

    private var editorControls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
                // Text Input
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Note Text")
                        .font(HeirloomFonts.bodyBold)

                    TextField("Type your note...", text: $text, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(HeirloomFonts.body)
                        .lineLimit(3...8)
                }

                // Position Guide
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text("Position")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .textCase(.uppercase)

                    Text("Drag the note on the preview above to position it")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                // Style Selection
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Style")
                        .font(HeirloomFonts.bodyBold)

                    HStack(spacing: HeirloomSpacing.sm) {
                        ForEach([RecipeAnnotation.AnnotationStyle.stickyNote, .handwritten, .marker], id: \.self) { styleOption in
                            styleButton(styleOption)
                        }
                    }
                }

                // Color Selection
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Color")
                        .font(HeirloomFonts.bodyBold)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 50))],
                        spacing: HeirloomSpacing.sm
                    ) {
                        ForEach(RecipeAnnotation.predefinedColors, id: \.self) { color in
                            colorSwatchButton(color)
                        }
                    }
                }

                // Font Size
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    HStack {
                        Text("Font Size")
                            .font(HeirloomFonts.bodyBold)

                        Spacer()

                        Text("\(Int(fontSize))pt")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    HStack(spacing: HeirloomSpacing.sm) {
                        Image(systemName: "textformat.size.smaller")
                            .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))
                            .onTapGesture {
                                withAnimation {
                                    fontSize = max(12.0, fontSize - 2.0)
                                }
                            }

                        Slider(value: $fontSize, in: 12.0...24.0, step: 1.0)
                            .tint(HeirloomColors.tomato)

                        Image(systemName: "textformat.size.larger")
                            .foregroundStyle(HeirloomColors.tomato)
                            .onTapGesture {
                                withAnimation {
                                    fontSize = min(24.0, fontSize + 2.0)
                                }
                            }
                    }

                    HStack(spacing: HeirloomSpacing.xs) {
                        ForEach([12, 14, 16, 18, 20], id: \.self) { size in
                            Button("\(size)pt") {
                                withAnimation {
                                    fontSize = Double(size)
                                }
                            }
                            .font(HeirloomFonts.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                }

                // Rotation
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    HStack {
                        Text("Rotation")
                            .font(HeirloomFonts.bodyBold)

                        Spacer()

                        Text("\(Int(rotation))°")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    HStack(spacing: HeirloomSpacing.sm) {
                        Image(systemName: "rotate.left.fill")
                            .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))
                            .onTapGesture {
                                withAnimation {
                                    rotation = (rotation - 5).truncatingRemainder(dividingBy: 360)
                                    if rotation < 0 { rotation += 360 }
                                }
                            }

                        Slider(value: $rotation, in: -15...15)
                            .tint(HeirloomColors.tomato)

                        Image(systemName: "rotate.right.fill")
                            .foregroundStyle(HeirloomColors.tomato)
                            .onTapGesture {
                                withAnimation {
                                    rotation = (rotation + 5).truncatingRemainder(dividingBy: 360)
                                }
                            }
                    }

                    HStack(spacing: HeirloomSpacing.xs) {
                        ForEach([-10, -5, 0, 5, 10], id: \.self) { angle in
                            Button("\(angle)°") {
                                withAnimation {
                                    rotation = Double(angle)
                                }
                            }
                            .font(HeirloomFonts.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }

                    Text("Adds a handwritten feel with slight tilt")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                // Delete Button (if editing)
                if isEditing {
                    Button(role: .destructive) {
                        deleteRecipeAnnotation()
                    } label: {
                        Label("Delete Note", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundStyle(.red)
                            .cornerRadius(12)
                    }
                }

                // Reset Button
                Button {
                    withAnimation {
                        fontSize = 14.0
                        rotation = 0.0
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
    }

    private func styleButton(_ styleOption: RecipeAnnotation.AnnotationStyle) -> some View {
        let isSelected = style == styleOption

        return Button {
            withAnimation(.spring(response: 0.3)) {
                style = styleOption
            }

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            VStack(spacing: HeirloomSpacing.xs) {
                Image(systemName: styleIcon(styleOption))
                    .font(.title2)

                Text(styleOption.displayName)
                    .font(HeirloomFonts.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HeirloomSpacing.md)
            .background(isSelected ? HeirloomColors.tomato.opacity(0.1) : Color.gray.opacity(0.05))
            .foregroundStyle(isSelected ? HeirloomColors.tomato : HeirloomColors.primaryText)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? HeirloomColors.tomato : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func styleIcon(_ style: RecipeAnnotation.AnnotationStyle) -> String {
        switch style {
        case .handwritten:
            return "pencil.tip"
        case .stickyNote:
            return "note.text"
        case .marker:
            return "highlighter"
        }
    }

    private func colorSwatchButton(_ color: String) -> some View {
        let isSelected = colorHex == color

        return Button {
            colorHex = color

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: color))
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

    // MARK: - Actions

    private func saveRecipeAnnotation() {
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }

        if let annotation = annotation {
            // Update existing annotation
            annotation.text = trimmedText
            annotation.style = style
            annotation.colorHex = colorHex
            annotation.fontSize = fontSize
            annotation.rotation = rotation
            annotation.positionX = positionX
            annotation.positionY = positionY
            annotation.lastModified = Date()
        } else {
            // Create new annotation
            let newRecipeAnnotation = RecipeAnnotation(
                text: trimmedText,
                style: style,
                positionX: positionX,
                positionY: positionY,
                fontSize: fontSize,
                rotation: rotation,
                colorHex: colorHex
            )

            newRecipeAnnotation.recipe = recipe
            modelContext.insert(newRecipeAnnotation)

            // Add to recipe's annotations array
            if recipe.annotations == nil {
                recipe.annotations = []
            }
            recipe.annotations?.append(newRecipeAnnotation)
        }

        do {
            try modelContext.save()

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            ToastManager.shared.success(
                title: isEditing ? "Note updated!" : "Note added!"
            )

            // Track analytics
            AnalyticsService.shared.track(event: .recipeEdited, properties: [
                "action": isEditing ? "annotation_updated" : "annotation_added",
                "style": style.rawValue
            ])

            dismiss()
        } catch {
            ToastManager.shared.error(
                title: "Failed to save note",
                message: error.localizedDescription
            )
        }
    }

    private func deleteRecipeAnnotation() {
        guard let annotation = annotation else { return }

        modelContext.delete(annotation)

        do {
            try modelContext.save()

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            ToastManager.shared.success(title: "Note deleted")

            dismiss()
        } catch {
            ToastManager.shared.error(
                title: "Failed to delete note",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Preview

#Preview("New") {
    RecipeAnnotationEditorView(recipe: .example)
        .modelContainer(for: Recipe.self, inMemory: true)
        .toastContainer()
}

#Preview("Editing") {
    let annotation = RecipeAnnotation(text: "Mom's favorite!", style: .stickyNote)
    return RecipeAnnotationEditorView(recipe: .example, annotation: annotation)
        .modelContainer(for: Recipe.self, inMemory: true)
        .toastContainer()
}
