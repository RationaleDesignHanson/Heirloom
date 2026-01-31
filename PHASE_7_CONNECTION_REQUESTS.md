# Phase 7: Connection Requests & User Discovery (No Handles)

**Status:** Ready to implement
**Prerequisites:** Phase 6 complete ✅
**Estimated Time:** 3-4 hours

---

## Overview

Add the ability to search for users by display name and send connection requests that require acceptance (unlike invite links which auto-connect).

**Key Difference from Invite Links:**
- **Invite links:** Immediate connection (no pending state)
- **Connection requests:** Recipient must accept/decline (pending state)

---

## What Already Works

✅ Backend complete:
- `ConnectionService.sendConnectionRequest()` - Creates PENDING connection
- `ConnectionService.acceptRequest()` - Accepts pending request
- `ConnectionService.declineRequest()` - Declines pending request
- `ConnectionService.getPendingRequestsCount()` - Counts inbound requests

✅ UI components exist:
- `ConnectionRequestsView` - Shows pending requests
- `ConnectionRequestCard` - Displays request with accept/decline buttons

---

## What's Missing

❌ No way to search for users
❌ No way to send traditional connection requests from UI
❌ No pending request badge/notification
❌ Search only works by display name (no handles in the system)

---

## Implementation Plan

### Step 1: Add User Search to ProfileService

**File:** `Heirloom/Core/Services/Social/ProfileService.swift`

**Add new method:**
```swift
/// Search users by display name
func searchUsers(query: String, limit: Int = 20) async throws -> [UserSearchResult]
```

**Implementation:**
```swift
func searchUsers(query: String, limit: Int = 20) async throws -> [UserSearchResult] {
    guard let currentUserId = auth.currentUser?.uid else {
        throw NSError(domain: "ProfileService", code: 401, ...)
    }

    // Query all user profiles via collectionGroup
    let snapshot = try await db.collectionGroup("profile")
        .whereField("displayName", isGreaterThanOrEqualTo: query)
        .whereField("displayName", isLessThan: query + "z")
        .limit(to: limit)
        .getDocuments()

    var results: [UserSearchResult] = []

    for doc in snapshot.documents {
        let data = doc.data()
        let userId = doc.reference.parent.parent?.documentID ?? ""

        // Skip current user
        if userId == currentUserId { continue }

        let result = UserSearchResult(
            id: userId,
            displayName: data["displayName"] as? String ?? "Unknown",
            photoURL: data["photoURL"] as? String,
            bio: data["bio"] as? String
        )
        results.append(result)
    }

    return results
}
```

**Firestore Index Required:**
- Collection Group: `profile`
- Fields: `displayName` (ASC)

### Step 2: Create UserSearchResult Model

**File:** `Heirloom/Core/Models/Social/UserSearchResult.swift` (NEW)

```swift
import Foundation

/// Lightweight model for user search results
struct UserSearchResult: Codable, Identifiable {
    let id: String  // userId
    let displayName: String
    let photoURL: String?
    let bio: String?
}
```

### Step 3: Create UserSearchView

**File:** `Heirloom/Features/Social/UserSearchView.swift` (NEW)

**Structure:**
```swift
struct UserSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var selectedUser: UserSearchResult?
    @State private var showUserPreview = false

    private var profileService: ProfileServiceProtocol {
        ServiceContainer.shared.resolve(ProfileServiceProtocol.self)
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                searchBar

                if isSearching {
                    loadingView
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    emptyStateView
                } else {
                    resultsListView
                }
            }
            .navigationTitle("Find Users")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showUserPreview) {
                if let user = selectedUser {
                    UserProfilePreviewSheet(user: user)
                }
            }
        }
    }

    private var searchBar: some View {
        TextField("Search by name", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .padding()
            .onChange(of: searchText) { _, newValue in
                Task {
                    await performSearch(query: newValue)
                }
            }
    }

    private var resultsListView: some View {
        ScrollView {
            LazyVStack {
                ForEach(searchResults) { user in
                    UserSearchResultRow(user: user)
                        .onTapGesture {
                            selectedUser = user
                            showUserPreview = true
                        }
                }
            }
        }
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty, query.count >= 2 else {
            searchResults = []
            return
        }

        // Debounce
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

        isSearching = true

        do {
            let results = try await profileService.searchUsers(query: query)
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        } catch {
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
            }
        }
    }
}
```

### Step 4: Create UserSearchResultRow

**File:** `Heirloom/Features/Social/Components/UserSearchResultRow.swift` (NEW)

```swift
struct UserSearchResultRow: View {
    let user: UserSearchResult

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Avatar
            AsyncImage(url: user.photoURL.flatMap(URL.init)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle()
                    .fill(HeirloomColors.tomato.opacity(0.2))
                    .overlay(
                        Text(user.displayName.prefix(1).uppercased())
                            .font(HeirloomFonts.title3)
                            .foregroundStyle(HeirloomColors.tomato)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())

            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                if let bio = user.bio {
                    Text(bio)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding()
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
    }
}
```

### Step 5: Create UserProfilePreviewSheet

**File:** `Heirloom/Features/Social/UserProfilePreviewSheet.swift` (NEW)

```swift
struct UserProfilePreviewSheet: View {
    let user: UserSearchResult

    @Environment(\.dismiss) private var dismiss
    @State private var isSendingRequest = false

    private var connectionService: ConnectionServiceProtocol {
        ServiceContainer.shared.resolve(ConnectionServiceProtocol.self)
    }

    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: HeirloomSpacing.xl) {
                Spacer()

                // Avatar
                AsyncImage(url: user.photoURL.flatMap(URL.init)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(HeirloomColors.tomato.opacity(0.2))
                        .overlay(
                            Text(user.displayName.prefix(1).uppercased())
                                .font(.system(size: 48))
                                .foregroundStyle(HeirloomColors.tomato)
                        )
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())

                // Name
                Text(user.displayName)
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                // Bio
                if let bio = user.bio {
                    Text(bio)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, HeirloomSpacing.xl)
                }

                Spacer()

                // Send Request Button
                Button {
                    Task {
                        await sendConnectionRequest()
                    }
                } label: {
                    HStack {
                        if isSendingRequest {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send Connection Request")
                        }
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HeirloomSpacing.md)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(12)
                }
                .disabled(isSendingRequest)
                .padding(.horizontal, HeirloomSpacing.lg)

                Button("Cancel") {
                    dismiss()
                }
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .padding(.bottom, HeirloomSpacing.xl)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func sendConnectionRequest() async {
        isSendingRequest = true

        do {
            _ = try await connectionService.sendConnectionRequest(
                to: user.id,
                displayName: user.displayName,
                sourceKitchenTableId: nil
            )

            await MainActor.run {
                isSendingRequest = false
                toastManager.success(title: "Connection request sent")
                dismiss()
            }
        } catch let error as NSError {
            await MainActor.run {
                isSendingRequest = false

                let message: String
                if error.domain == "ConnectionService" {
                    switch error.code {
                    case 400: message = "Cannot connect to yourself"
                    case 409: message = "Connection already exists"
                    default: message = "Failed to send request"
                    }
                } else {
                    message = "Failed to send request"
                }

                toastManager.error(title: message)
            }
        }
    }
}
```

### Step 6: Add Search Button to KitchenTableView

**File:** `Heirloom/Features/Social/KitchenTableView.swift`

**Add state (line ~35):**
```swift
@State private var showUserSearch = false
```

**Add toolbar button (line ~72, before invite button):**
```swift
ToolbarItem(placement: .topBarTrailing) {
    Button {
        showUserSearch = true
    } label: {
        Image(systemName: "magnifyingglass")
    }
}
```

**Add sheet presentation (line ~90):**
```swift
.sheet(isPresented: $showUserSearch) {
    UserSearchView()
}
```

### Step 7: Add Pending Request Badge

**File:** `Heirloom/Features/Social/KitchenTableView.swift`

**Update pending request banner (line ~110):**
```swift
if !pendingRequests.isEmpty {
    Button {
        showConnectionRequests = true
    } label: {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.title3)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Connection Requests")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.white)

                Text("\(pendingRequests.count) pending")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            // Badge
            Text("\(pendingRequests.count)")
                .font(HeirloomFonts.caption1Bold)
                .foregroundStyle(HeirloomColors.tomato)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white)
                .cornerRadius(12)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.tomato)
        .cornerRadius(12)
    }
    .padding(.horizontal, HeirloomSpacing.lg)
}
```

---

## Testing Checklist

**User Search:**
- [ ] Search by partial name ("Mat" finds "Matt Personal")
- [ ] Search by full name ("Mealtime" finds exact match)
- [ ] Empty search shows no results
- [ ] Loading state appears during search
- [ ] Minimum 2 characters required

**Connection Requests:**
- [ ] Send request from search results
- [ ] Toast appears: "Connection request sent"
- [ ] Cannot send duplicate request
- [ ] Recipient sees request in ConnectionRequestsView
- [ ] Accept request → both users see connection
- [ ] Decline request → request disappears
- [ ] Pending badge shows correct count

**Edge Cases:**
- [ ] Cannot send request to self
- [ ] Already connected users show error
- [ ] Search with no network shows error
- [ ] Request fails gracefully

---

## Firestore Index Required

```bash
firebase firestore:indexes
```

Add to `firestore.indexes.json`:
```json
{
  "collectionGroup": "profile",
  "queryScope": "COLLECTION_GROUP",
  "fields": [
    {
      "fieldPath": "displayName",
      "order": "ASCENDING"
    }
  ]
}
```

Deploy:
```bash
firebase deploy --only firestore:indexes
```

---

## Files to Create

1. `Heirloom/Core/Models/Social/UserSearchResult.swift`
2. `Heirloom/Features/Social/UserSearchView.swift`
3. `Heirloom/Features/Social/UserProfilePreviewSheet.swift`
4. `Heirloom/Features/Social/Components/UserSearchResultRow.swift`

## Files to Modify

1. `Heirloom/Core/Services/Social/ProfileService.swift` - Add `searchUsers()` method
2. `Heirloom/Features/Social/KitchenTableView.swift` - Add search button and badge

---

## Implementation Order

1. Create UserSearchResult model (5 min)
2. Add searchUsers() to ProfileService (15 min)
3. Create UserSearchResultRow component (20 min)
4. Create UserProfilePreviewSheet (30 min)
5. Create UserSearchView (45 min)
6. Add search button to KitchenTableView (10 min)
7. Enhance pending request badge (15 min)
8. Test end-to-end (30 min)

**Total:** ~3 hours

---

## Notes

- **No handle system:** Search only by display name (simpler than original plan)
- **Existing backend:** All ConnectionService methods already work
- **Simple search:** Firestore prefix match (not fuzzy search)
- **Cache strategy:** No caching needed (search is always fresh)
- **Privacy:** All profiles searchable (no privacy settings yet)
