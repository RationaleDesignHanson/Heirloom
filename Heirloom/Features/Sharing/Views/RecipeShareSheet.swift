import SwiftUI
import SwiftData
import FirebaseAuth

/// Complete sheet for sharing a recipe with customization options via Firebase
/// Redesigned for clarity: Share type and button prominent, advanced settings collapsed
struct RecipeShareSheet: View {
    let recipe: Recipe

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.firebaseShare) private var firebaseShare

    // State
    @State private var options = ShareOptions.default
    @State private var isSharing = false
    @State private var shareURL: URL?
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false
    @State private var showAdvancedSettings = false
    @State private var versionCount: Int = 1 // Number of versions available (1 = original only)

    // Direct sharing state (Phase 1: Inter-Heirloom Sharing)
    @State private var shareMethod: ShareMethod = .link
    @State private var selectedConnectionIds: Set<String> = []

    /// Share method selection
    enum ShareMethod {
        case link        // Creates generic public link
        case connections // Creates direct share to selected users
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: HeirloomSpacing.lg) {
                        // Share type selector (PROMINENT)
                        shareTypeSelector
                            .zIndex(0)

                        // NEW: Share method selector (Phase 1: Inter-Heirloom Sharing)
                        shareMethodSelector

                        // NEW: Connection picker (if sharing to connections)
                        if shareMethod == .connections {
                            connectionPickerSection
                                .zIndex(0)
                        }

                        // Preview card
                        SharePreviewCard(recipe: recipe, options: options)
                            .padding(.horizontal)
                            .zIndex(0)

                        // Advanced settings (COLLAPSED)
                        advancedSettingsSection
                    }
                    .padding(.top)
                }

                // Primary action OUTSIDE ScrollView (pinned to bottom)
                VStack(spacing: 0) {
                    Divider()
                    primaryShareButton
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                        .background(HeirloomColors.cream)
                }
            }
            .navigationTitle("Share Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showSuccessMessage) {
                if shareMethod == .connections {
                    directShareSuccessView
                } else if let url = shareURL {
                    linkShareSuccessView(url: url)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
        .onAppear {
            setupDefaultOptions()
        }
    }

    // MARK: - Share Type Selector (Prominent)

    private var shareTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share As")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
                .padding(.horizontal)

            // SIMPLIFIED: Only heirloom (editable) shares allowed
            // Generic (frozen/read-only) shares removed per product decision
            // This encourages collaboration and simplifies UX
            ShareTypeCard(
                type: .heirloom,
                isSelected: true, // Always selected
                versionCount: versionCount,
                action: {} // No action needed - always heirloom
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Share Method Selector (Phase 1: Inter-Heirloom Sharing)

    private var shareMethodSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share Via")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
                .padding(.horizontal)

            Picker("Share Method", selection: $shareMethod) {
                Text("Link").tag(ShareMethod.link)
                Text("To Connections").tag(ShareMethod.connections)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .frame(height: 44) // Explicit minimum tap target height
        }
        .background(Color.clear) // Ensure no overlay blocking
        .zIndex(1) // Ensure picker is above other content
        .allowsHitTesting(true) // Explicitly enable touch events
    }

    // MARK: - Connection Picker Section (Phase 1: Inter-Heirloom Sharing)

    private var connectionPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Recipients")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
                .padding(.horizontal)

            ConnectionPickerView(selectedConnectionIds: $selectedConnectionIds)
                .frame(height: 300)
                .padding(.horizontal)
        }
    }

    // MARK: - Primary Share Button

    private var primaryShareButton: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            Button(action: isSharing ? {} : createShare) {
                HStack(spacing: 12) {
                    if isSharing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(HeirloomColors.buttonTextLight)
                    } else {
                        Image(systemName: shareMethod == .link ? "link" : "person.2.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(shareButtonText)
                            .font(HeirloomFonts.bodyBold)
                    }
                }
                .foregroundStyle(HeirloomColors.buttonTextLight)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isShareButtonEnabled ? HeirloomColors.tomato : HeirloomColors.warmGray)
                .cornerRadius(12)
            }
            .disabled(!isShareButtonEnabled)

            // Share method description
            Text(shareButtonDescription)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
    }

    /// Dynamic button text based on share method and selection
    private var shareButtonText: String {
        switch shareMethod {
        case .link:
            return "Create Heirloom Share"
        case .connections:
            let count = selectedConnectionIds.count
            if count == 0 {
                return "Select Connections"
            } else if count == 1 {
                return "Share with 1 Friend"
            } else {
                return "Share with \(count) Friends"
            }
        }
    }

    /// Button description based on share method
    private var shareButtonDescription: String {
        switch shareMethod {
        case .link:
            return "Recipients can edit and build on this recipe"
        case .connections:
            if selectedConnectionIds.isEmpty {
                return "Select at least one connection to share with"
            } else {
                return "Direct notification sent to selected friends"
            }
        }
    }

    /// Whether share button should be enabled
    private var isShareButtonEnabled: Bool {
        switch shareMethod {
        case .link:
            return true
        case .connections:
            return !selectedConnectionIds.isEmpty
        }
    }

    // MARK: - Advanced Settings (Collapsed)

    private var advancedSettingsSection: some View {
        VStack(spacing: 0) {
            // Accordion header
            Button(action: { withAnimation { showAdvancedSettings.toggle() } }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Advanced Settings")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)
                    Spacer()
                    Image(systemName: showAdvancedSettings ? "chevron.up" : "chevron.down")
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius))
            }
            .padding(.horizontal)

            // Expanded content
            if showAdvancedSettings {
                VStack(spacing: HeirloomSpacing.lg) {
                    // What to include
                    customizationSection

                    // Personal message
                    personalMessageSection

                    // Link settings
                    linkSettingsSection
                }
                .padding(.top, 16)
                .transition(.opacity.combined(with: .scale))
            }
        }
    }

    // MARK: - Customization Section (Collapsed Content)

    private var customizationSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            SectionHeader(icon: "checklist", title: "What to Include")

            VStack(spacing: 12) {
                Toggle(isOn: $options.includeCardBack) {
                    ToggleLabel(
                        icon: "rectangle.portrait.fill",
                        title: "Card Back",
                        subtitle: "Personal notes and layout"
                    )
                }

                Toggle(isOn: $options.includeRating) {
                    ToggleLabel(
                        icon: "star.fill",
                        title: "My Rating",
                        subtitle: "Your personal rating"
                    )
                }

                Toggle(isOn: $options.includeNotes) {
                    ToggleLabel(
                        icon: "note.text",
                        title: "Notes to Friends",
                        subtitle: "Your personal message on card"
                    )
                }

                Toggle(isOn: $options.includePinnedComments) {
                    ToggleLabel(
                        icon: "pin.fill",
                        title: "Pinned Comments",
                        subtitle: "Highlighted tips and tricks"
                    )
                }

                Toggle(isOn: $options.includeAllComments) {
                    ToggleLabel(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "All Comments",
                        subtitle: "Include all comments, not just pinned"
                    )
                }
                .disabled(!options.includePinnedComments)

                Toggle(isOn: $options.includeStickers) {
                    ToggleLabel(
                        icon: "star.circle.fill",
                        title: "Stickers & Decorations",
                        subtitle: "Visual customizations"
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Personal Message Section (Collapsed Content)

    private var personalMessageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "quote.bubble.fill", title: "Personal Message")

            TextField("Add a personal note (optional)", text: Binding(
                get: { options.personalMessage ?? "" },
                set: { options.personalMessage = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(3...6)
            .padding(.horizontal)

            Text("This message will appear at the top of the recipe for the recipient")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .padding(.horizontal)
        }
    }

    // MARK: - Link Settings Section (Collapsed Content)

    private var linkSettingsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            SectionHeader(icon: "link", title: "Link Settings")

            VStack(spacing: 12) {
                // Expiration picker
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Link Expires")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Picker("Expiration", selection: $options.expirationDuration) {
                        ForEach(ShareOptions.ExpirationDuration.allCases, id: \.self) { duration in
                            Label {
                                VStack(alignment: .leading) {
                                    Text(duration.displayName)
                                        .font(HeirloomFonts.body)
                                    Text(duration.description)
                                        .font(HeirloomFonts.caption1)
                                        .foregroundStyle(HeirloomColors.secondaryText)
                                }
                            } icon: {
                                Image(systemName: duration.iconName)
                            }
                            .tag(duration as ShareOptions.ExpirationDuration?)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Allow re-sharing toggle
                Toggle(isOn: $options.allowReSharing) {
                    ToggleLabel(
                        icon: "arrow.triangle.branch",
                        title: "Allow Re-sharing",
                        subtitle: "Recipients can share with others"
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private func setupDefaultOptions() {
        // CRITICAL: Always use heirloom share type (generic/frozen shares disabled)
        options.shareType = .heirloom

        // Load user display name and version count
        Task {
            await loadUserDisplayName()
            await loadVersionCount()
        }
    }

    private func loadUserDisplayName() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            await MainActor.run {
                options.sharerName = "You"
            }
            return
        }

        // Try to get display name from Firebase User Profile Service
        let userProfileService = ServiceContainer.shared.resolve(FirebaseUserProfileService.self)

        do {
            if let displayName = try await userProfileService.fetchDisplayName(for: userId) {
                await MainActor.run {
                    options.sharerName = displayName
                    Log.debug("Loaded user display name for share sheet", category: .firebase, metadata: [
                        "displayName": displayName
                    ])
                }
            } else {
                // Fallback to "You" if no display name found
                await MainActor.run {
                    options.sharerName = "You"
                }
            }
        } catch {
            Log.warning("Failed to load user display name, using 'You'", category: .firebase, metadata: [
                "error": error.localizedDescription
            ])
            await MainActor.run {
                options.sharerName = "You"
            }
        }
    }

    private func loadVersionCount() async {
        // Count how many versions exist for this recipe
        let viewModel = RecipeVersionSelectorViewModel()
        await viewModel.loadVersions(for: recipe, context: modelContext)

        await MainActor.run {
            versionCount = viewModel.versions.count
            Log.debug("Loaded version count for share sheet", category: .firebase, metadata: [
                "recipeTitle": recipe.title,
                "versionCount": versionCount
            ])
        }
    }

    private func createShare() {
        Log.info("Share button tapped", category: .firebase)

        // Validate recipe can be shared
        let (canShare, reason) = recipe.canShare()
        Log.info("Can share validation", category: .firebase, metadata: ["canShare": canShare, "reason": reason ?? "none"])

        guard canShare else {
            errorMessage = reason ?? "This recipe cannot be shared"
            Log.warning("Share blocked by validation", category: .firebase, metadata: ["reason": reason ?? "unknown"])
            return
        }

        Task {
            isSharing = true
            errorMessage = nil

            do {
                let (shareId, url): (String, URL)

                // Choose share path based on selected method
                switch shareMethod {
                case .link:
                    // EXISTING PATH: Generic link share
                    (shareId, url) = try await firebaseShare.createShare(
                        for: recipe,
                        options: options,
                        recipientUserIds: nil,
                        context: modelContext
                    )

                case .connections:
                    // NEW PATH: Direct share to selected connections
                    guard !selectedConnectionIds.isEmpty else {
                        throw NSError(
                            domain: "RecipeShareSheet",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Please select at least one connection"]
                        )
                    }

                    (shareId, url) = try await firebaseShare.createDirectShare(
                        for: recipe,
                        options: options,
                        recipientUserIds: Array(selectedConnectionIds),
                        context: modelContext
                    )
                }

                await MainActor.run {
                    shareURL = url
                    showSuccessMessage = true
                    isSharing = false

                    Log.info("✅ Share created successfully", category: .firebase, metadata: [
                        "shareId": shareId,
                        "shareMethod": shareMethod == .link ? "link" : "direct",
                        "recipientCount": selectedConnectionIds.count,
                        "shareURL": url.absoluteString
                    ])
                }

            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create share: \(error.localizedDescription)"
                    isSharing = false
                }

                Log.error("Failed to create share", category: .firebase, metadata: [
                    "shareMethod": shareMethod == .link ? "link" : "direct",
                    "error": error.localizedDescription
                ])
            }
        }
    }

    // MARK: - Share Success View

    @ViewBuilder
    // MARK: - Direct Share Success View

    private var directShareSuccessView: some View {
        NavigationStack {
            VStack(spacing: HeirloomSpacing.xl) {
                Spacer()

                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(HeirloomColors.success)

                // Success message
                VStack(spacing: HeirloomSpacing.sm) {
                    Text("Recipe Shared!")
                        .font(HeirloomFonts.title1)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text(recipe.title)
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Recipient info
                VStack(spacing: HeirloomSpacing.xs) {
                    Text("Shared with \(selectedConnectionIds.count) friend\(selectedConnectionIds.count == 1 ? "" : "s")")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("They'll receive a notification and can accept the recipe")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, HeirloomSpacing.xl)
                }

                Spacer()

                // Done button
                Button {
                    showSuccessMessage = false
                    dismiss()
                } label: {
                    Text("Done")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, HeirloomSpacing.xl)
            }
            .navigationTitle("Success")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Link Share Success View

    private func linkShareSuccessView(url: URL) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.xl) {
                    // Success header
                    VStack(spacing: HeirloomSpacing.md) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(HeirloomColors.success)

                        Text("Share Link Created!")
                            .font(HeirloomFonts.title1)
                            .foregroundStyle(HeirloomColors.primaryText)

                        Text(recipe.title)
                            .font(HeirloomFonts.title3)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding()

                    // URL display card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Share Link")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.secondaryText)

                        HStack {
                            Text(url.absoluteString)
                                .font(HeirloomFonts.callout)
                                .foregroundStyle(HeirloomColors.primaryText)
                                .lineLimit(2)
                                .truncationMode(.middle)

                            Spacer()

                            Button(action: { copyLink(url) }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(HeirloomColors.tomato)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: { copyLink(url) }) {
                            HStack {
                                Image(systemName: "link")
                                Text("Copy Link")
                            }
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.buttonTextLight)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(HeirloomColors.tomato)
                            .cornerRadius(12)
                        }

                        if let url = shareURL {
                            ShareLink(item: url) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share via...")
                                }
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.tomato)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 32)
            }
            .background(HeirloomColors.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func copyLink(_ url: URL) {
        // Generate universal link format for Messages compatibility
        // Custom scheme: heirloom://share/UUID
        // Universal: https://heirloom.app/share/UUID
        let shareId = url.lastPathComponent
        let universalLink = "https://heirloom.app/share/\(shareId)"

        // Copy universal link for better compatibility in Messages and other apps
        UIPasteboard.general.string = universalLink

        ServiceContainer.shared.resolve(ToastManager.self).show(
            type: .success,
            title: "Link Copied",
            message: "Share link copied to clipboard"
        )
        Log.info("Share link copied (universal format)", category: .firebase, metadata: [
            "shareId": shareId,
            "format": "universal"
        ])
    }
}

// MARK: - Share Type Card

struct ShareTypeCard: View {
    let type: ShareOptions.ShareType
    let isSelected: Bool
    let versionCount: Int // Number of versions available (for Heirloom badge)
    let action: () -> Void

    private var selectedColor: Color {
        // Changed to green for better visual clarity
        type == .heirloom ? HeirloomColors.familyGreen : HeirloomColors.familyGreen
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon (smaller for banner layout)
                Image(systemName: type.iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)

                    Text(type.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                }

                Spacer()

                // Badge (compact)
                if type == .heirloom {
                    Text("\(versionCount) \(versionCount == 1 ? "version" : "versions")")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(HeirloomColors.familyGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(selectedColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(HeirloomColors.tomato)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
        }
        .padding(.horizontal)
    }
}

// MARK: - Toggle Label

struct ToggleLabel: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(HeirloomColors.tomato)
                .font(.system(size: 16))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)
                Text(subtitle)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RecipeShareSheet(recipe: Recipe(
        title: "Grandma's Chocolate Chip Cookies",
        sourceType: .family,
        instructions: ["Mix ingredients", "Bake at 350°F for 12 minutes"]
    ))
}
