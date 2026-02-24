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

    // Dependency injection for formatter
    private var formatter: IngredientFormatter {
        ServiceContainer.shared.resolve(IngredientFormatter.self)
    }

    // Observe UnitsConfiguration for reactive updates
    @ObservedObject private var unitsConfig: UnitsConfiguration = ServiceContainer.shared.resolve(UnitsConfiguration.self)

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
            ZStack {
                // Elegant warm background
                LinearGradient(
                    colors: [
                        Color(hex: "#FFFBF5"),
                        Color(hex: "#FFF8F0")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

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
            }
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
                    .foregroundColor(HeirloomColors.secondaryText)
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
        VStack(spacing: 10) {
            HStack {
                Text("Step \(currentStep + 1) of \(activeInstructions.count)")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(HeirloomColors.familyGreen)
                    Text("\(completedSteps.count) done")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.familyGreen)
                }
            }
            .padding(.horizontal, HeirloomSpacing.lg)

            // Elegant progress bar with rounded ends
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.black.opacity(0.06))

                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [HeirloomColors.tomato, HeirloomColors.tomato.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geometry.size.width * progress))
                }
            }
            .frame(height: 6)
            .padding(.horizontal, HeirloomSpacing.lg)
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
            VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                // Step Number & Completion Toggle
                HStack(alignment: .center) {
                    // Elegant step number badge
                    ZStack {
                        Circle()
                            .fill(HeirloomColors.tomato.opacity(0.1))
                            .frame(width: 72, height: 72)

                        Text("\(currentStep + 1)")
                            .font(.system(size: 80, weight: .bold, design: .rounded))
                            .foregroundStyle(HeirloomColors.tomato)
                            .offset(y: -4)
                    }

                    Spacer()

                    // Completion button with elegant styling
                    Button {
                        toggleStepComplete()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isCurrentStepComplete ? HeirloomColors.familyGreen.opacity(0.1) : Color.clear)
                                .frame(width: 56, height: 56)

                            Circle()
                                .stroke(isCurrentStepComplete ? HeirloomColors.familyGreen : Color.gray.opacity(0.25), lineWidth: 2)
                                .frame(width: 56, height: 56)

                            if isCurrentStepComplete {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(HeirloomColors.familyGreen)
                            }
                        }
                    }
                }
                .padding(.bottom, 4)

                // Step Text with elegant card treatment
                VStack(alignment: .leading, spacing: 0) {
                    Text(currentStepText)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(HeirloomColors.primaryText)
                        .lineSpacing(8)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                )

                // Timer Section
                timerSection

                // Ingredients Reference
                if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                    ingredientsSection(ingredients: ingredients)
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

    // MARK: - Ingredients Section

    private func ingredientsSection(ingredients: [Ingredient]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 14))
                    .foregroundColor(HeirloomColors.tomato.opacity(0.7))

                Text("INGREDIENTS")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            // Ingredients list with elegant styling
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ingredients.prefix(4)) { ingredient in
                    HStack(alignment: .center, spacing: 10) {
                        Circle()
                            .fill(HeirloomColors.tomato.opacity(0.2))
                            .frame(width: 6, height: 6)

                        Text(scaledIngredientText(ingredient))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(HeirloomColors.primaryText)
                            .lineLimit(2)
                    }
                }

                if ingredients.count > 4 {
                    Text("+ \(ingredients.count - 4) more ingredients")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .padding(.leading, 16)
                        .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                )
        )
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(spacing: HeirloomSpacing.md) {
            if let _ = timerEndTime, remainingTime > 0 {
                // Active Timer Display
                VStack(spacing: 16) {
                    // Timer display
                    HStack(spacing: 12) {
                        Image(systemName: "timer")
                            .font(.system(size: 24))
                            .foregroundStyle(HeirloomColors.amber)

                        Text(timeString(from: remainingTime))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(HeirloomColors.primaryText)
                            .monospacedDigit()
                    }

                    // Timer controls
                    HStack(spacing: 12) {
                        Button {
                            cancelTimer()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Cancel")
                                    .font(HeirloomFonts.bodyBold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .foregroundStyle(HeirloomColors.primaryText)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                        }

                        Button {
                            addTime(minutes: 1)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("1 min")
                                    .font(HeirloomFonts.bodyBold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(HeirloomColors.tomato)
                            .foregroundStyle(HeirloomColors.buttonTextLight)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(HeirloomColors.amber.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(HeirloomColors.amber.opacity(0.2), lineWidth: 1)
                        )
                )
            } else {
                // Set Timer Button
                Button {
                    showTimerPicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "timer")
                            .font(.system(size: 20))
                        Text("Set Timer")
                            .font(HeirloomFonts.bodyBold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                }
            }
        }
        .sheet(isPresented: $showTimerPicker) {
            timerPickerView
        }
    }

    private var timerPickerView: some View {
        NavigationStack {
            VStack(spacing: HeirloomSpacing.lg) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 32))
                        .foregroundStyle(HeirloomColors.tomato)

                    Text("Set Timer")
                        .font(HeirloomFonts.title1)
                        .foregroundStyle(HeirloomColors.primaryText)
                }
                .padding(.top, HeirloomSpacing.xl)

                // Time pickers
                HStack(spacing: HeirloomSpacing.lg) {
                    // Minutes Picker
                    VStack(spacing: 4) {
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

                    Text(":")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(HeirloomColors.secondaryText)

                    // Seconds Picker
                    VStack(spacing: 4) {
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
                VStack(spacing: 10) {
                    Text("QUICK TIMES")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.8)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    HStack(spacing: 10) {
                        ForEach([1, 5, 10, 15, 30], id: \.self) { minutes in
                            Button("\(minutes)") {
                                timerMinutes = minutes
                                timerSeconds = 0
                            }
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 48, height: 40)
                            .background(
                                timerMinutes == minutes && timerSeconds == 0
                                    ? HeirloomColors.tomato.opacity(0.1)
                                    : Color.black.opacity(0.03)
                            )
                            .foregroundStyle(
                                timerMinutes == minutes && timerSeconds == 0
                                    ? HeirloomColors.tomato
                                    : HeirloomColors.primaryText
                            )
                            .cornerRadius(10)
                        }
                    }
                }

                Spacer()

                // Start button
                Button {
                    startTimer()
                    showTimerPicker = false
                } label: {
                    Text("Start Timer")
                        .font(HeirloomFonts.bodyBold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(timerMinutes == 0 && timerSeconds == 0 ? Color.gray.opacity(0.3) : HeirloomColors.tomato)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .cornerRadius(14)
                }
                .disabled(timerMinutes == 0 && timerSeconds == 0)
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.bottom, HeirloomSpacing.lg)
            }
            .background(Color(hex: "#FFFBF7"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showTimerPicker = false
                    }
                    .foregroundColor(HeirloomColors.secondaryText)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Navigation Controls

    private var navigationControls: some View {
        VStack(spacing: 0) {
            // Subtle separator
            Rectangle()
                .fill(Color.black.opacity(0.04))
                .frame(height: 1)

            HStack(spacing: 12) {
                // Previous Button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentStep = max(0, currentStep - 1)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Previous")
                            .font(HeirloomFonts.bodyBold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(currentStep > 0 ? Color.white : Color.clear)
                    .foregroundStyle(currentStep > 0 ? HeirloomColors.primaryText : HeirloomColors.warmGray)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(currentStep > 0 ? Color.black.opacity(0.08) : Color.clear, lineWidth: 1)
                    )
                }
                .disabled(currentStep == 0)

                // Next/Finish Button
                Button {
                    if currentStep < activeInstructions.count - 1 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStep += 1
                        }
                    } else {
                        showFinishConfirmation = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(currentStep < activeInstructions.count - 1 ? "Next" : "Finish")
                            .font(HeirloomFonts.bodyBold)
                        Image(systemName: currentStep < activeInstructions.count - 1 ? "chevron.right" : "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(HeirloomColors.tomato)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .cornerRadius(14)
                }
            }
            .padding(.horizontal, HeirloomSpacing.lg)
            .padding(.vertical, 16)
            .background(
                Color.white.opacity(0.9)
                    .background(.ultraThinMaterial)
            )
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

        // Use IngredientFormatter to format with scaling and unit conversion
        return formatter.format(ingredient, scaleFactor: scaleFactor, convertUnits: true)
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
