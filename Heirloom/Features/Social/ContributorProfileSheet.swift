//
//  ContributorProfileSheet.swift
//  Heirloom
//
//  Social Layer Phase 6: View another user's profile
//  Shows profile info, connection status, and shared recipes
//

import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseAuth

// MARK: - Shared Recipe Info

struct SharedRecipeInfo: Identifiable {
    let id: String
    let recipeId: String
    let recipeTitle: String
    let sharedAt: Date
    let message: String?
}

struct ContributorProfileSheet: View {
    let connection: Connection

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var connectionService: ConnectionServiceProtocol {
        ServiceContainer.shared.resolve(ConnectionServiceProtocol.self)
    }

    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
    }

    // MARK: - State

    @State private var showEditNote = false
    @State private var editingNote = ""
    @State private var isSavingNote = false
    @State private var showRemoveConfirmation = false
    @State private var isRemoving = false

    // Shared recipes state
    @State private var sharedByMe: [SharedRecipeInfo] = []
    @State private var sharedByThem: [SharedRecipeInfo] = []
    @State private var isLoadingShares = true

    var body: some View {
        NavigationStack {
            profileContent
                .navigationTitle(connection.connectedUserDisplayName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $showEditNote) {
                    editNoteSheet
                }
        }
    }

    // MARK: - Profile Content

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: HeirloomSpacing.xl) {
                // Header: Avatar + Name + Handle
                VStack(spacing: HeirloomSpacing.md) {
                    // Avatar
                    if let photoURL = connection.connectedUserPhotoURL,
                       let url = URL(string: photoURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            case .failure, .empty:
                                placeholderAvatar
                            @unknown default:
                                placeholderAvatar
                            }
                        }
                    } else {
                        placeholderAvatar
                    }

                    // Name
                    Text(connection.connectedUserDisplayName)
                        .font(HeirloomFonts.title1)
                        .foregroundStyle(HeirloomColors.primaryText)

                    // Handle
                    if let handle = connection.connectedUserHandle {
                        Text("@\(handle)")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }
                .padding(.top, HeirloomSpacing.lg)

                // Connection status badge
                connectionStatusBadge

                // Kitchen Table connection (if applicable)
                if connection.isKitchenTableConnection {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Image(systemName: "fork.knife")
                            .font(.caption)
                        Text("Kitchen Table Connection")
                            .font(HeirloomFonts.caption1)
                    }
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .padding(.horizontal, HeirloomSpacing.md)
                    .padding(.vertical, HeirloomSpacing.xs)
                    .background(HeirloomColors.warmGray.opacity(0.1))
                    .cornerRadius(8)
                }

                // Private note
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    HStack {
                        Text("Note")
                            .font(HeirloomFonts.caption1Bold)
                            .foregroundStyle(HeirloomColors.secondaryText)

                        Spacer()

                        Button {
                            editingNote = connection.privateNote ?? ""
                            showEditNote = true
                        } label: {
                            Text(connection.privateNote == nil || connection.privateNote?.isEmpty == true ? "Add" : "Edit")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.tomato)
                        }
                    }

                    if let note = connection.privateNote, !note.isEmpty {
                        Text(note)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                    } else {
                        Text("Add a private note about this connection")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.secondaryText.opacity(0.6))
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(HeirloomSpacing.md)
                .background(HeirloomColors.warmGray.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal, HeirloomSpacing.md)

                // Stats
                HStack(spacing: 0) {
                    statCard(
                        value: "\(connection.recipesSharedCount)",
                        label: "You Shared"
                    )
                    Divider()
                        .frame(height: 50)
                    statCard(
                        value: "\(connection.recipesReceivedCount)",
                        label: "They Shared"
                    )
                }
                .background(HeirloomColors.cardBackground)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, HeirloomSpacing.md)

                // Shared Recipes Section
                sharedRecipesSection

                // Remove Connection Button
                Button(role: .destructive) {
                    showRemoveConfirmation = true
                } label: {
                    HStack {
                        if isRemoving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        } else {
                            Image(systemName: "person.fill.xmark")
                            Text("Remove Connection")
                        }
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HeirloomSpacing.md)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                .disabled(isRemoving)
                .padding(.horizontal, HeirloomSpacing.md)
                .padding(.top, HeirloomSpacing.lg)
            }
            .task {
                await loadSharedRecipes()
            }
            .padding(.bottom, HeirloomSpacing.xl)
        }
        .alert("Remove Connection", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    await removeConnection()
                }
            }
        } message: {
            Text("Are you sure you want to remove \(connection.connectedUserDisplayName) from your connections? This cannot be undone.")
        }
    }

    // MARK: - Components

    private var placeholderAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        HeirloomColors.tomato.opacity(0.8),
                        HeirloomColors.tomato.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 100, height: 100)
            .overlay(
                Text(initials)
                    .font(HeirloomFonts.largeTitle)
                    .foregroundStyle(.white)
            )
    }

    private var initials: String {
        let name = connection.connectedUserDisplayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[components.count - 1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else {
            return String(name.prefix(1)).uppercased()
        }
    }

    private var connectionStatusBadge: some View {
        HStack(spacing: HeirloomSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
            Text(connection.statusDisplayText)
                .font(HeirloomFonts.caption1Bold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.vertical, HeirloomSpacing.xs)
        .background(HeirloomColors.tomato)
        .cornerRadius(20)
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: HeirloomSpacing.xs) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(HeirloomColors.primaryText)

            Text(label)
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HeirloomSpacing.sm)
    }

    // MARK: - Shared Recipes Section

    @ViewBuilder
    private var sharedRecipesSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Shared Recipes")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)
                .padding(.horizontal, HeirloomSpacing.md)

            if isLoadingShares {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, HeirloomSpacing.lg)
                    Spacer()
                }
            } else if sharedByMe.isEmpty && sharedByThem.isEmpty {
                Text("No recipes shared yet")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .padding(.horizontal, HeirloomSpacing.md)
                    .padding(.vertical, HeirloomSpacing.sm)
            } else {
                // Recipes you shared with them
                if !sharedByMe.isEmpty {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                        Text("You Shared")
                            .font(HeirloomFonts.caption1Bold)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .padding(.horizontal, HeirloomSpacing.md)

                        ForEach(sharedByMe) { share in
                            sharedRecipeRow(share)
                        }
                    }
                }

                // Recipes they shared with you
                if !sharedByThem.isEmpty {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                        Text("They Shared")
                            .font(HeirloomFonts.caption1Bold)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .padding(.horizontal, HeirloomSpacing.md)

                        ForEach(sharedByThem) { share in
                            sharedRecipeRow(share)
                        }
                    }
                }
            }
        }
    }

    private func sharedRecipeRow(_ share: SharedRecipeInfo) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "doc.text")
                .font(.body)
                .foregroundStyle(HeirloomColors.tomato)
                .frame(width: 32, height: 32)
                .background(HeirloomColors.tomato.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(share.recipeTitle)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)

                Text(share.sharedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.vertical, HeirloomSpacing.sm)
        .background(HeirloomColors.cardBackground)
    }

    // MARK: - Load Shared Recipes

    private func loadSharedRecipes() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            await MainActor.run { isLoadingShares = false }
            return
        }

        let db = Firestore.firestore()
        let connectedUserId = connection.connectedUserId

        do {
            // Query shares where I shared with them
            let mySharesSnapshot = try await db.collection("shares")
                .whereField("ownerId", isEqualTo: currentUserId)
                .whereField("recipientUserIds", arrayContains: connectedUserId)
                .limit(to: 10)
                .getDocuments()

            let myShares = mySharesSnapshot.documents.compactMap { doc -> SharedRecipeInfo? in
                let data = doc.data()
                guard let recipeId = data["recipeId"] as? String,
                      let recipeTitle = data["recipeTitle"] as? String,
                      let sharedAtTimestamp = (data["sharedAt"] ?? data["createdAt"]) as? Timestamp else {
                    return nil
                }
                return SharedRecipeInfo(
                    id: doc.documentID,
                    recipeId: recipeId,
                    recipeTitle: recipeTitle,
                    sharedAt: sharedAtTimestamp.dateValue(),
                    message: data["message"] as? String
                )
            }.sorted(by: { $0.sharedAt > $1.sharedAt })

            // Query shares where they shared with me
            let theirSharesSnapshot = try await db.collection("shares")
                .whereField("ownerId", isEqualTo: connectedUserId)
                .whereField("recipientUserIds", arrayContains: currentUserId)
                .limit(to: 10)
                .getDocuments()

            let theirShares = theirSharesSnapshot.documents.compactMap { doc -> SharedRecipeInfo? in
                let data = doc.data()
                guard let recipeId = data["recipeId"] as? String,
                      let recipeTitle = data["recipeTitle"] as? String,
                      let sharedAtTimestamp = (data["sharedAt"] ?? data["createdAt"]) as? Timestamp else {
                    return nil
                }
                return SharedRecipeInfo(
                    id: doc.documentID,
                    recipeId: recipeId,
                    recipeTitle: recipeTitle,
                    sharedAt: sharedAtTimestamp.dateValue(),
                    message: data["message"] as? String
                )
            }.sorted(by: { $0.sharedAt > $1.sharedAt })

            await MainActor.run {
                self.sharedByMe = myShares
                self.sharedByThem = theirShares
                self.isLoadingShares = false
            }

            Log.info("Loaded shared recipes", category: .social, metadata: [
                "connectionId": connection.id,
                "sharedByMe": myShares.count,
                "sharedByThem": theirShares.count
            ])
        } catch {
            await MainActor.run {
                self.isLoadingShares = false
            }
            Log.error("Failed to load shared recipes", category: .social, error: error)
        }
    }

    // MARK: - Edit Note Sheet

    private var editNoteSheet: some View {
        NavigationStack {
            VStack(spacing: HeirloomSpacing.lg) {
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text("Private Note")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Only you can see this note")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Add a note about \(connection.connectedUserDisplayName)...", text: $editingNote, axis: .vertical)
                    .font(HeirloomFonts.body)
                    .padding(HeirloomSpacing.md)
                    .background(HeirloomColors.warmGray.opacity(0.1))
                    .cornerRadius(12)
                    .lineLimit(5...10)

                Spacer()
            }
            .padding(HeirloomSpacing.lg)
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showEditNote = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveNote()
                        }
                    }
                    .disabled(isSavingNote)
                }
            }
        }
    }

    // MARK: - Actions

    private func saveNote() async {
        isSavingNote = true

        do {
            let noteToSave = editingNote.trimmingCharacters(in: .whitespacesAndNewlines)
            try await connectionService.updatePrivateNote(
                connectionId: connection.id,
                note: noteToSave.isEmpty ? nil : noteToSave
            )

            await MainActor.run {
                showEditNote = false
                isSavingNote = false
                toastManager.success(title: "Note saved")
            }

            Log.info("Updated private note", category: .social, metadata: [
                "connectionId": connection.id
            ])
        } catch {
            await MainActor.run {
                isSavingNote = false
                toastManager.error(title: "Failed to save note")
            }
            Log.error("Failed to save private note", category: .social, error: error)
        }
    }

    private func removeConnection() async {
        isRemoving = true

        do {
            try await connectionService.removeConnection(connectionId: connection.id)

            await MainActor.run {
                isRemoving = false
                dismiss()

                // Show toast after dismissal
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    toastManager.success(title: "Connection removed")
                }
            }

            Log.info("Removed connection", category: .social, metadata: [
                "connectionId": connection.id,
                "connectedUser": connection.connectedUserDisplayName
            ])
        } catch {
            await MainActor.run {
                isRemoving = false
                toastManager.error(title: "Failed to remove connection")
            }
            Log.error("Failed to remove connection", category: .social, error: error)
        }
    }
}

#Preview {
    ContributorProfileSheet(connection: Connection(
        id: "preview",
        userId: "user1",
        connectedUserId: "user2",
        connectedUserDisplayName: "Chef Julia",
        connectedUserPhotoURL: nil,
        status: .connected,
        initiatedBy: "user2",
        requestedAt: Date(),
        acceptedAt: Date(),
        sourceKitchenTableId: "table1",
        recipesSharedCount: 12,
        recipesReceivedCount: 8,
        isFavorite: false,
        privateNote: nil,
        createdAt: Date(),
        updatedAt: Date()
    ))
}
