import SwiftUI
import SwiftData
import UserNotifications
import AVFoundation

struct CookingModeView: View {
    let recipe: Recipe
    let targetServings: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Using concrete type for version management
    private var versionService: RecipeVersionService { ServiceContainer.shared.resolve(RecipeVersionService.self) }
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    @State private var currentStep = 0
    @State private var completedSteps: Set<Int> = []
    @State private var showFinishConfirmation = false

    // Timer State
    @State private var showTimerPicker = false
    @State private var timerMinutes = 0
    @State private var timerSeconds = 0
    @State private var timerEndTime: Date?
    @State private var timer: Timer?
    @State private var remainingTime: TimeInterval = 0

    // Version selection
    @State private var selectedVersionID: UUID?

    // MARK: - Computed Properties

    /// Get instructions from active version
    private var activeInstructions: [String] {
        if let activeVersion = recipe.activeVersion,
           let versionInstructions = activeVersion.instructions,
           !versionInstructions.isEmpty {
            return versionInstructions
        }
        return recipe.instructions
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Version Selector (if multiple versions exist)
                if recipe.hasMultipleVersions {
                    VersionSelectorView(
                        recipe: recipe,
                        selectedVersionID: Binding(
                            get: { selectedVersionID ?? recipe.selectedVersionID },
                            set: { selectedVersionID = $0 }
                        )
                    )
                    .padding(.top, HeirloomSpacing.sm)
                }

                // Progress Bar
                progressBar

                // Step Content
                stepContent

                // Navigation Controls
                navigationControls
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Exit") {
                        if completedSteps.count > 0 {
                            showFinishConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .confirmationDialog(
                "Finish Cooking?",
                isPresented: $showFinishConfirmation,
                titleVisibility: .visible
            ) {
                Button("Mark as Cooked") {
                    finishCooking()
                }
                Button("Exit Without Saving") {
                    dismiss()
                }
                Button("Continue Cooking", role: .cancel) {}
            } message: {
                Text("You've completed \(completedSteps.count) of \(activeInstructions.count) steps. Mark this recipe as cooked?")
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            HStack {
                Text("Step \(currentStep + 1) of \(activeInstructions.count)")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)

                Spacer()

                Text("\(completedSteps.count) completed")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.familyGreen)
            }
            .padding(.horizontal, HeirloomSpacing.lg)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(HeirloomColors.warmGray.opacity(0.2))

                    // Progress
                    Rectangle()
                        .fill(HeirloomColors.tomato)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.top, HeirloomSpacing.md)
        .padding(.bottom, HeirloomSpacing.lg)
    }

    private var progress: Double {
        guard !activeInstructions.isEmpty else { return 0 }
        return Double(currentStep + 1) / Double(activeInstructions.count)
    }

    // MARK: - Step Content

    private var stepContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
                // Step Number
                HStack {
                    Text("\(currentStep + 1)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundStyle(HeirloomColors.tomato)

                    Spacer()

                    Button {
                        toggleStepComplete()
                    } label: {
                        Image(systemName: isCurrentStepComplete ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 40))
                            .foregroundStyle(isCurrentStepComplete ? HeirloomColors.familyGreen : HeirloomColors.warmGray)
                    }
                }

                // Step Text
                Text(currentStepText)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineSpacing(8)

                // Timer Section
                timerSection

                Divider()
                    .padding(.vertical, HeirloomSpacing.md)

                // Ingredients Reference (if any)
                if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        Text("Ingredients")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(HeirloomColors.primaryText)
                            .textCase(.uppercase)

                        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                            ForEach(ingredients.prefix(4)) { ingredient in
                                HStack(spacing: HeirloomSpacing.sm) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(HeirloomColors.tomato)

                                    Text(scaledIngredientText(ingredient))
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(HeirloomColors.primaryText)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, HeirloomSpacing.xxs)
                            }

                            if ingredients.count > 4 {
                                Text("+ \(ingredients.count - 4) more")
                                    .font(HeirloomFonts.caption2)
                                    .foregroundStyle(HeirloomColors.secondaryText)
                                    .padding(.leading, 8)
                            }
                        }
                    }
                }
            }
            .padding(HeirloomSpacing.lg)
        }
    }

    private var currentStepText: String {
        guard currentStep < activeInstructions.count else {
            return "All steps complete!"
        }
        return activeInstructions[currentStep]
    }

    private var isCurrentStepComplete: Bool {
        completedSteps.contains(currentStep)
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(spacing: HeirloomSpacing.md) {
            if let _ = timerEndTime, remainingTime > 0 {
                // Active Timer Display
                VStack(spacing: HeirloomSpacing.sm) {
                    HStack {
                        Image(systemName: "timer")
                            .font(.title2)
                            .foregroundStyle(HeirloomColors.tomato)

                        Text(timeString(from: remainingTime))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(HeirloomColors.primaryText)
                            .monospacedDigit()
                    }

                    HStack(spacing: HeirloomSpacing.md) {
                        Button {
                            cancelTimer()
                        } label: {
                            Label("Cancel", systemImage: "xmark.circle.fill")
                                .font(HeirloomFonts.bodyBold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(HeirloomColors.warmGray.opacity(0.2))
                                .foregroundStyle(HeirloomColors.primaryText)
                                .cornerRadius(HeirloomSpacing.cardCornerRadius)
                        }

                        Button {
                            addTime(minutes: 1)
                        } label: {
                            Label("+1 min", systemImage: "plus.circle.fill")
                                .font(HeirloomFonts.bodyBold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(HeirloomColors.tomato)
                                .foregroundStyle(HeirloomColors.buttonTextLight)
                                .cornerRadius(HeirloomSpacing.cardCornerRadius)
                        }
                    }
                }
                .padding(HeirloomSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(HeirloomColors.amber.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(HeirloomColors.amber.opacity(0.3), lineWidth: 2)
                        )
                )
            } else {
                // Set Timer Button
                Button {
                    showTimerPicker = true
                } label: {
                    HStack {
                        Image(systemName: "timer")
                            .font(HeirloomFonts.title2)
                        Text("Set Timer")
                            .font(HeirloomFonts.bodyBold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HeirloomColors.warmGray.opacity(0.1))
                    .foregroundStyle(HeirloomColors.primaryText)
                    .cornerRadius(HeirloomSpacing.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                            .strokeBorder(HeirloomColors.warmGray.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .sheet(isPresented: $showTimerPicker) {
            timerPickerView
        }
    }

    private var timerPickerView: some View {
        NavigationStack {
            VStack(spacing: HeirloomSpacing.xl) {
                Text("Set Timer")
                    .font(HeirloomFonts.title1)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .padding(.top, HeirloomSpacing.xl)

                HStack(spacing: HeirloomSpacing.lg) {
                    // Minutes Picker
                    VStack {
                        Picker("Minutes", selection: $timerMinutes) {
                            ForEach(0..<60) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100, height: 150)

                        Text("min")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    // Seconds Picker
                    VStack {
                        Picker("Seconds", selection: $timerSeconds) {
                            ForEach(0..<60) { second in
                                Text("\(second)").tag(second)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100, height: 150)

                        Text("sec")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }

                // Quick Time Buttons
                VStack(spacing: HeirloomSpacing.sm) {
                    Text("Quick Times")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .textCase(.uppercase)

                    HStack(spacing: HeirloomSpacing.sm) {
                        ForEach([1, 5, 10, 15, 30], id: \.self) { minutes in
                            Button("\(minutes) min") {
                                timerMinutes = minutes
                                timerSeconds = 0
                            }
                            .font(HeirloomFonts.caption1)
                            .padding(.horizontal, HeirloomSpacing.md)
                            .padding(.vertical, HeirloomSpacing.sm)
                            .background(HeirloomColors.warmGray.opacity(0.1))
                            .foregroundStyle(HeirloomColors.primaryText)
                            .cornerRadius(8)
                        }
                    }
                }

                Spacer()

                Button {
                    startTimer()
                    showTimerPicker = false
                } label: {
                    Text("Start Timer")
                        .font(HeirloomFonts.bodyBold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(timerMinutes == 0 && timerSeconds == 0 ? HeirloomColors.warmGray : HeirloomColors.tomato)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .cornerRadius(HeirloomSpacing.cardCornerRadius)
                }
                .disabled(timerMinutes == 0 && timerSeconds == 0)
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.bottom, HeirloomSpacing.lg)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showTimerPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Navigation Controls

    private var navigationControls: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Divider()

            HStack(spacing: HeirloomSpacing.lg) {
                // Previous Button
                Button {
                    withAnimation {
                        currentStep = max(0, currentStep - 1)
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(currentStep > 0 ? HeirloomColors.warmGray.opacity(0.2) : Color.clear)
                    .foregroundStyle(currentStep > 0 ? HeirloomColors.primaryText : HeirloomColors.warmGray)
                    .cornerRadius(HeirloomSpacing.cardCornerRadius)
                }
                .disabled(currentStep == 0)

                // Next/Finish Button
                Button {
                    if currentStep < activeInstructions.count - 1 {
                        withAnimation {
                            currentStep += 1
                        }
                    } else {
                        showFinishConfirmation = true
                    }
                } label: {
                    HStack {
                        Text(currentStep < activeInstructions.count - 1 ? "Next" : "Finish")
                        Image(systemName: currentStep < activeInstructions.count - 1 ? "chevron.right" : "checkmark")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HeirloomColors.tomato)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .cornerRadius(HeirloomSpacing.cardCornerRadius)
                }
            }
            .padding(.horizontal, HeirloomSpacing.lg)
            .padding(.bottom, HeirloomSpacing.lg)
        }
    }

    // MARK: - Timer Actions

    private func startTimer() {
        let totalSeconds = TimeInterval(timerMinutes * 60 + timerSeconds)
        timerEndTime = Date().addingTimeInterval(totalSeconds)
        remainingTime = totalSeconds

        // Create repeating timer
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateTimer()
        }

        // Schedule notification
        scheduleTimerNotification(for: totalSeconds)

        analytics.track(event: .timerStarted, properties: [
            "recipe_id": recipe.id.uuidString,
            "duration_seconds": totalSeconds,
            "step_number": currentStep + 1
        ])
    }

    private func updateTimer() {
        guard let endTime = timerEndTime else {
            cancelTimer()
            return
        }

        remainingTime = endTime.timeIntervalSinceNow

        if remainingTime <= 0 {
            timerComplete()
        }
    }

    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
        timerEndTime = nil
        remainingTime = 0

        // Cancel any pending notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["cooking-timer"])
    }

    private func addTime(minutes: Int) {
        if let endTime = timerEndTime {
            timerEndTime = endTime.addingTimeInterval(TimeInterval(minutes * 60))
        }
    }

    private func timerComplete() {
        cancelTimer()

        // Play audible alarm sound (system sound)
        AudioServicesPlayAlertSound(SystemSoundID(1005)) // Glass chime

        // Also play haptic feedback for extra emphasis
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        toastManager.success(
            title: "Timer Complete!",
            message: "Step \(currentStep + 1) timer finished"
        )

        analytics.track(event: .timerCompleted, properties: [
            "recipe_id": recipe.id.uuidString,
            "step_number": currentStep + 1
        ])
    }

    private func scheduleTimerNotification(for duration: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Timer Complete"
        content.body = "\(recipe.title) - Step \(currentStep + 1)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(identifier: "cooking-timer", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.error("Failed to schedule cooking timer notification", category: .general, metadata: ["error": error.localizedDescription])
            }
        }
    }

    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Ingredient Scaling

    private func scaledIngredientText(_ ingredient: Ingredient) -> String {
        // Calculate scale factor from target servings
        let originalServings = recipe.parsedServingCount
        let scaleFactor = Double(targetServings) / Double(originalServings)

        // If scaling is 1.0, just show original text
        guard scaleFactor != 1.0 else {
            return ingredient.displayText
        }

        // If ingredient has no quantity, can't scale it
        guard let quantity = ingredient.quantity else {
            return ingredient.displayText
        }

        // Scale the quantity
        let scaledQty = quantity * scaleFactor
        let scaledQtyMax = ingredient.quantityMax.map { $0 * scaleFactor }

        // Build scaled display text
        var parts: [String] = []

        // Format quantity with fractions
        parts.append(formatQuantity(scaledQty))

        if let max = scaledQtyMax {
            parts.append("-\(formatQuantity(max))")
        }

        if let unit = ingredient.unit {
            parts.append(unit)
        }

        parts.append(ingredient.name)

        if let prep = ingredient.preparation {
            parts.append("(\(prep))")
        }

        return parts.joined(separator: " ")
    }

    private func formatQuantity(_ value: Double) -> String {
        let fractions: [(Double, String)] = [
            (0.125, "⅛"), (0.25, "¼"), (0.333, "⅓"),
            (0.375, "⅜"), (0.5, "½"), (0.625, "⅝"),
            (0.666, "⅔"), (0.75, "¾"), (0.875, "⅞")
        ]

        let wholePart = Int(value)
        let fractionalPart = value - Double(wholePart)

        // First pass: exact matches (within 0.01)
        for (decimalValue, fractionSymbol) in fractions {
            if abs(fractionalPart - decimalValue) < 0.01 {
                if wholePart > 0 {
                    return "\(wholePart) \(fractionSymbol)"
                } else {
                    return fractionSymbol
                }
            }
        }

        // Second pass: snap to nearest common fraction (within 0.12)
        let commonFractions: [(Double, String)] = [
            (0.125, "⅛"), (0.25, "¼"), (0.333, "⅓"),
            (0.5, "½"), (0.666, "⅔"), (0.75, "¾")
        ]

        for (decimalValue, fractionSymbol) in commonFractions {
            if abs(fractionalPart - decimalValue) < 0.12 {
                if wholePart > 0 {
                    return "\(wholePart) \(fractionSymbol)"
                } else {
                    return fractionSymbol
                }
            }
        }

        if fractionalPart < 0.01 {
            return "\(wholePart)"
        }

        return String(format: "%.1f", value)
    }

    // MARK: - Actions

    private func toggleStepComplete() {
        if completedSteps.contains(currentStep) {
            completedSteps.remove(currentStep)
        } else {
            completedSteps.insert(currentStep)
        }
    }

    private func finishCooking() {
        recipe.timesCooked += 1
        recipe.lastCooked = Date()

        do {
            try modelContext.save()

            toastManager.success(
                title: "Recipe Complete!",
                message: "You've cooked this \(recipe.timesCooked) \(recipe.timesCooked == 1 ? "time" : "times")"
            )

            // Mark active version as cooked
            if let activeVersion = recipe.activeVersion {
                do {
                    try versionService.markAsCooked(activeVersion, context: modelContext)
                } catch {
                    Log.error("Failed to mark version as cooked", category: .database, metadata: ["error": error.localizedDescription, "versionId": activeVersion.id.uuidString])
                }
            }

            analytics.track(event: .cookingCompleted, properties: [
                "recipe_id": recipe.id.uuidString,
                "recipe_title": recipe.title,
                "times_cooked": recipe.timesCooked,
                "steps_completed": completedSteps.count,
                "total_steps": activeInstructions.count,
                "version_used": recipe.activeVersion?.creatorDisplayName ?? "base"
            ])

            dismiss()
        } catch {
            toastManager.error(
                title: "Failed to save",
                message: error.localizedDescription
            )
        }
    }
}

#Preview {
    @Previewable @State var container: ModelContainer = {
        let container = try! ModelContainer(for: Recipe.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let recipe = Recipe.example
        recipe.instructions = [
            "Preheat oven to 375°F",
            "Cream together butter and sugars until light and fluffy",
            "Beat in eggs and vanilla extract",
            "In a separate bowl, whisk together flour, baking soda, and salt",
            "Gradually blend dry ingredients into wet ingredients",
            "Stir in chocolate chips",
            "Drop by rounded tablespoon onto ungreased cookie sheets",
            "Bake for 9 to 11 minutes or until golden brown",
            "Cool on baking sheet for 2 minutes before removing to a wire rack"
        ]
        context.insert(recipe)

        return container
    }()

    CookingModeView(recipe: Recipe.example, targetServings: Recipe.example.parsedServingCount)
        .modelContainer(container)
}
