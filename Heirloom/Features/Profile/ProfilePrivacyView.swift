//
//  ProfilePrivacyView.swift
//  Heirloom
//
//  Social Layer Phase 5: Social Privacy Settings View
//  Granular privacy controls for social features
//

import SwiftUI

struct ProfilePrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var privacySettings: PrivacySettings
    let onSave: () -> Void

    @State private var isSaving = false

    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Profile Visibility
                Section {
                    Picker("Profile Visibility", selection: $privacySettings.profileVisibility) {
                        Text("Public").tag(ProfileVisibility.public)
                        Text("Connections Only").tag(ProfileVisibility.connections)
                        Text("Private").tag(ProfileVisibility.private)
                    }
                    .onChange(of: privacySettings.profileVisibility) { _, _ in
                        autoSave()
                    }

                    Toggle("Show Recipe Count", isOn: $privacySettings.showConnectionCount)
                        .onChange(of: privacySettings.showConnectionCount) { _, _ in
                            autoSave()
                        }

                    Toggle("Show Connection Count", isOn: $privacySettings.showConnectionCount)
                        .onChange(of: privacySettings.showConnectionCount) { _, _ in
                            autoSave()
                        }
                } header: {
                    Text("Profile Visibility")
                } footer: {
                    Text(profileVisibilityDescription)
                }

                // Connection Settings
                Section {
                    Picker("Who Can Connect", selection: $privacySettings.whoCanConnect) {
                        Text("Everyone").tag(WhoCanConnect.everyone)
                        Text("Connections of Connections").tag(WhoCanConnect.connections)
                        Text("Kitchen Table Members Only").tag(WhoCanConnect.kitchenTable)
                        Text("No One").tag(WhoCanConnect.noOne)
                    }
                    .onChange(of: privacySettings.whoCanConnect) { _, _ in
                        autoSave()
                    }

                    Toggle("Auto-Accept Kitchen Table Requests", isOn: $privacySettings.autoAcceptKitchenTableConnections)
                        .onChange(of: privacySettings.autoAcceptKitchenTableConnections) { _, _ in
                            autoSave()
                        }
                } header: {
                    Text("Connection Requests")
                } footer: {
                    Text("Control who can send you connection requests")
                }

                // Recipe Sharing
                Section {
                    Picker("Recipe Visibility", selection: $privacySettings.recipeVisibility) {
                        Text("Public").tag(RecipeVisibility.public)
                        Text("Connections Only").tag(RecipeVisibility.connections)
                        Text("Kitchen Table Only").tag(RecipeVisibility.kitchenTable)
                        Text("Private").tag(RecipeVisibility.private)
                    }
                    .onChange(of: privacySettings.recipeVisibility) { _, _ in
                        autoSave()
                    }

                    Toggle("Allow Recipe Re-sharing", isOn: $privacySettings.allowRecipeResharing)
                        .onChange(of: privacySettings.allowRecipeResharing) { _, _ in
                            autoSave()
                        }

                    Toggle("Show Recipe Attribution", isOn: $privacySettings.showRecipeAttribution)
                        .onChange(of: privacySettings.showRecipeAttribution) { _, _ in
                            autoSave()
                        }
                } header: {
                    Text("Recipe Sharing")
                } footer: {
                    Text("Control how your recipes can be shared and discovered")
                }

                // Notifications
                Section {
                    Toggle("Connection Requests", isOn: $privacySettings.notifyConnectionRequests)
                        .onChange(of: privacySettings.notifyConnectionRequests) { _, _ in
                            autoSave()
                        }

                    Toggle("Recipe Shares", isOn: $privacySettings.notifyRecipeShares)
                        .onChange(of: privacySettings.notifyRecipeShares) { _, _ in
                            autoSave()
                        }

                    Toggle("Kitchen Table Invites", isOn: $privacySettings.notifyKitchenTableInvites)
                        .onChange(of: privacySettings.notifyKitchenTableInvites) { _, _ in
                            autoSave()
                        }
                } header: {
                    Text("Notifications")
                }

                // Public Profile
                Section {
                    Toggle("Allow Search Indexing", isOn: $privacySettings.allowSearchIndexing)
                        .onChange(of: privacySettings.allowSearchIndexing) { _, _ in
                            autoSave()
                        }

                    Toggle("Show Join Date", isOn: $privacySettings.showJoinDate)
                        .onChange(of: privacySettings.showJoinDate) { _, _ in
                            autoSave()
                        }

                    Toggle("Show Heritage Stats", isOn: $privacySettings.showHeritageStats)
                        .onChange(of: privacySettings.showHeritageStats) { _, _ in
                            autoSave()
                        }
                } header: {
                    Text("Public Profile")
                } footer: {
                    Text("Controls what appears on your public profile URL")
                }

                // Data & Discovery
                Section {
                    Toggle("Usage Analytics", isOn: $privacySettings.allowAnalytics)
                        .onChange(of: privacySettings.allowAnalytics) { _, _ in
                            autoSave()
                        }

                    Toggle("Connection Suggestions", isOn: $privacySettings.allowConnectionSuggestions)
                        .onChange(of: privacySettings.allowConnectionSuggestions) { _, _ in
                            autoSave()
                        }
                } header: {
                    Text("Data & Discovery")
                } footer: {
                    Text("Help us improve Heirloom and connect you with others")
                }

                // Search Privacy
                Section {
                    Toggle("Hide from Search", isOn: $privacySettings.hideFromSearch)
                        .onChange(of: privacySettings.hideFromSearch) { _, _ in
                            autoSave()
                        }

                    Toggle("Show Location in Search", isOn: $privacySettings.showLocationInSearch)
                        .disabled(privacySettings.hideFromSearch)
                        .onChange(of: privacySettings.showLocationInSearch) { _, _ in
                            autoSave()
                        }

                    Toggle("Show Specialties in Search", isOn: $privacySettings.showSpecialtiesInSearch)
                        .disabled(privacySettings.hideFromSearch)
                        .onChange(of: privacySettings.showSpecialtiesInSearch) { _, _ in
                            autoSave()
                        }
                } header: {
                    Text("Search Visibility")
                } footer: {
                    Text(searchVisibilityDescription)
                }

                // Presets
                Section {
                    Button {
                        privacySettings = .maxPrivacy
                        autoSave()
                    } label: {
                        HStack {
                            Image(systemName: "lock.fill")
                            Text("Maximum Privacy")
                            Spacer()
                        }
                    }

                    Button {
                        privacySettings = .fullyPublic
                        autoSave()
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                            Text("Fully Public")
                            Spacer()
                        }
                    }

                    Button {
                        privacySettings = PrivacySettings()
                        autoSave()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                            Spacer()
                        }
                    }
                } header: {
                    Text("Quick Presets")
                }
            }
            .navigationTitle("Privacy Settings")
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

    // MARK: - Helper Properties

    private var profileVisibilityDescription: String {
        switch privacySettings.profileVisibility {
        case .public:
            return "Anyone can view your profile"
        case .connections:
            return "Only your connections can view your full profile"
        case .private:
            return "Your profile is hidden from others"
        }
    }

    private var searchVisibilityDescription: String {
        if privacySettings.hideFromSearch {
            return "When enabled, other users won't be able to find you in search. You can still send connection requests."
        } else {
            return "Control what information appears when others search for you"
        }
    }

    // MARK: - Actions

    private func autoSave() {
        // Auto-save after a brief delay to batch changes
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                onSave()
            }
        }
    }
}

#Preview {
    @Previewable @State var settings = PrivacySettings()

    ProfilePrivacyView(
        privacySettings: $settings,
        onSave: {
            print("Settings saved")
        }
    )
}
