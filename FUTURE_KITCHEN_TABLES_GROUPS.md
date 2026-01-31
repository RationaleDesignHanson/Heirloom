# Kitchen Tables (Groups) - Future Feature

**Status:** 🔮 Future implementation (save for later)
**Prerequisites:** Phases 6-7 complete
**Estimated Time:** 8-12 hours

---

## Overview

Kitchen Tables are **multi-user cooking groups** where members can:
- Share recipes within the group
- Have group discussions
- Coordinate cooking activities
- Build themed collections together

Think of it as "group chats for cooking" - but focused on recipes and culinary collaboration.

---

## Core Concepts

### What is a Kitchen Table?

A Kitchen Table is a **private group** where:
- Members are explicitly invited
- All members can share recipes
- Recipes shared to the table are visible to all members
- Each table has a unique identity (name, description, icon)
- Tables can have different purposes (family recipes, meal planning, cooking club, etc.)

### Kitchen Table vs Connections

| Feature | Connections | Kitchen Tables |
|---------|-------------|----------------|
| Relationship | 1:1 (two people) | Many:Many (group) |
| Recipe Sharing | Direct to connection | Share to entire table |
| Privacy | Bilateral | Group-controlled |
| Purpose | Personal network | Shared cooking projects |

---

## Features to Implement

### 1. Create Kitchen Table

**UI:** KitchenTableCreateView
- Table name (required)
- Description (optional)
- Icon/emoji selector
- Privacy settings (invite-only for MVP)

**Backend:**
```swift
// Firestore document: kitchenTables/{tableId}
{
  "id": "uuid",
  "name": "Family Recipes",
  "description": "Our family cookbook",
  "iconEmoji": "👨‍🍳",
  "ownerId": "userId",
  "memberIds": ["userId1", "userId2"],
  "createdAt": timestamp,
  "updatedAt": timestamp
}
```

### 2. Invite Members

**UI:** KitchenTableInviteView
- Search from existing connections
- Select multiple members
- Send invites

**Flow:**
1. Owner selects connections to invite
2. Invites sent as notifications
3. Recipients accept/decline
4. Accepted members added to `memberIds`

**Backend:**
```swift
// Firestore: notifications/{notificationId}
{
  "type": "kitchenTableInvite",
  "tableId": "uuid",
  "tableName": "Family Recipes",
  "invitedBy": "userId",
  "invitedByName": "Matt",
  "status": "pending" | "accepted" | "declined"
}
```

### 3. Share Recipe to Table

**Integration Points:**
- RecipeDetailView → Add "Share to Table" action
- RecipeListView → Bulk share to table
- Import flows → Optionally add to table on import

**UI:**
- Sheet with table picker
- Optional message with share
- Toast confirmation

**Backend:**
```swift
// Firestore: kitchenTables/{tableId}/recipes/{recipeId}
{
  "recipeId": "uuid",
  "sharedBy": "userId",
  "sharedByName": "Matt",
  "sharedAt": timestamp,
  "message": "Check out this recipe!"
}

// Also store reference in recipe:
// recipes/{recipeId}
{
  "sharedToTables": ["tableId1", "tableId2"]
}
```

### 4. Kitchen Table Feed

**UI:** KitchenTableFeedView
- Recent recipes shared to table
- Activity feed (who shared what)
- Filter by member
- Search within table

**Components:**
- Table header (name, member count, settings)
- Recipe cards with "Shared by X" attribution
- Member avatars
- Activity timestamps

### 5. Table Settings

**UI:** KitchenTableSettingsView

**Features:**
- Edit table name/description/icon
- View members list
- Invite more members
- Leave table (if not owner)
- Delete table (owner only)
- Remove members (owner only)

### 6. Table Discovery

**UI:** KitchenTablesListView

**Show:**
- Tables you own
- Tables you're a member of
- Pending invites
- Create new table button

**Layout:**
- Card grid (2 columns on iPad)
- Table icon/emoji prominent
- Member count badge
- Recent activity indicator

---

## Data Model

### KitchenTable Model

```swift
struct KitchenTable: Codable, Identifiable {
    let id: String
    var name: String
    var description: String?
    var iconEmoji: String
    let ownerId: String
    var ownerDisplayName: String
    var memberIds: [String]
    var members: [TableMember]? // Denormalized for display
    let createdAt: Date
    var updatedAt: Date
}

struct TableMember: Codable {
    let userId: String
    let displayName: String
    let photoURL: String?
    let joinedAt: Date
    let role: TableRole // owner, admin, member
}

enum TableRole: String, Codable {
    case owner
    case admin
    case member
}
```

### TableRecipeShare Model

```swift
struct TableRecipeShare: Codable, Identifiable {
    let id: String
    let tableId: String
    let recipeId: String
    let sharedBy: String
    let sharedByName: String
    var message: String?
    let sharedAt: Date

    // Denormalized recipe data for feed
    var recipeTitle: String
    var recipeImageURL: String?
}
```

---

## Service Layer

### KitchenTableService

```swift
protocol KitchenTableServiceProtocol {
    // CRUD operations
    func createTable(_ table: KitchenTable) async throws -> KitchenTable
    func fetchMyTables() async throws -> [KitchenTable]
    func fetchTable(id: String) async throws -> KitchenTable
    func updateTable(_ table: KitchenTable) async throws
    func deleteTable(id: String) async throws

    // Member management
    func inviteMember(tableId: String, userId: String) async throws
    func acceptInvite(tableId: String) async throws
    func declineInvite(tableId: String) async throws
    func removeMember(tableId: String, userId: String) async throws
    func leaveTable(tableId: String) async throws

    // Recipe sharing
    func shareRecipe(recipeId: String, to tableId: String, message: String?) async throws
    func fetchTableRecipes(tableId: String) async throws -> [TableRecipeShare]
    func removeRecipeFromTable(recipeId: String, tableId: String) async throws
}
```

---

## Firestore Structure

```
kitchenTables/
  {tableId}/
    - Table document (name, description, memberIds, etc.)

    recipes/
      {shareId}/
        - Shared recipe reference (recipeId, sharedBy, sharedAt, message)

    members/
      {userId}/
        - Member profile snapshot (displayName, photoURL, joinedAt, role)

    invites/
      {inviteId}/
        - Pending invites (invitedUserId, status, invitedAt)

users/
  {userId}/
    kitchenTables/
      {tableId}/
        - User's view of table membership (role, notifications, lastViewed)
```

---

## Firestore Security Rules

```javascript
// Kitchen Tables
match /kitchenTables/{tableId} {
  // Members can read table
  allow read: if request.auth.uid in resource.data.memberIds;

  // Only owner can create
  allow create: if request.auth.uid == request.resource.data.ownerId;

  // Members can update (for invites, shares)
  // Owner can update all fields
  allow update: if request.auth.uid in resource.data.memberIds;

  // Only owner can delete
  allow delete: if request.auth.uid == resource.data.ownerId;

  // Shared recipes subcollection
  match /recipes/{shareId} {
    allow read: if request.auth.uid in get(/databases/$(database)/documents/kitchenTables/$(tableId)).data.memberIds;
    allow write: if request.auth.uid in get(/databases/$(database)/documents/kitchenTables/$(tableId)).data.memberIds;
  }
}
```

---

## UI Components

### New Files Needed

1. **Views:**
   - `KitchenTablesListView.swift` - List all tables
   - `KitchenTableFeedView.swift` - Table activity feed
   - `KitchenTableCreateView.swift` - Create new table
   - `KitchenTableSettingsView.swift` - Manage table
   - `KitchenTableInviteView.swift` - Invite members

2. **Components:**
   - `KitchenTableCard.swift` - Table preview card
   - `TableRecipeCard.swift` - Recipe card with attribution
   - `TableMemberRow.swift` - Member list item
   - `TableInviteCard.swift` - Pending invite card

3. **Services:**
   - `KitchenTableService.swift` - Backend operations

4. **Models:**
   - `KitchenTable.swift` - Table model
   - `TableRecipeShare.swift` - Shared recipe model
   - `TableMember.swift` - Member model

---

## Integration with Existing Features

### Recipe Detail View
Add "Share to Table" action:
```swift
Button {
    showTablePicker = true
} label: {
    Label("Share to Table", systemImage: "person.3")
}
.sheet(isPresented: $showTablePicker) {
    TablePickerView(recipe: recipe)
}
```

### Connection Accept Flow
After accepting connection, prompt:
```swift
// "Would you like to invite [Name] to a Kitchen Table?"
// - Show list of your tables
// - Or create new table
```

### Recipe Import
Add checkbox: "Add to Kitchen Table" during import flow

---

## Future Enhancements (Beyond MVP)

1. **Table Discussions**
   - Comments on shared recipes
   - General chat thread
   - @mentions

2. **Collaborative Collections**
   - Table-owned recipe collections
   - Members can add recipes

3. **Cooking Events**
   - Schedule group cooking sessions
   - Meal planning calendar
   - Shopping lists

4. **Table Analytics**
   - Most shared recipes
   - Most active members
   - Popular cuisines

5. **Public Tables**
   - Discoverable cooking communities
   - Join without invite
   - Moderation tools

6. **Table Templates**
   - "Family Recipes" template
   - "Meal Prep Club" template
   - "Holiday Cooking" template

---

## Testing Plan

**Table Creation:**
- [ ] Create table with name and icon
- [ ] Owner automatically added as member
- [ ] Table appears in tables list

**Invitations:**
- [ ] Invite connection to table
- [ ] Invitee receives notification
- [ ] Accept invite → added to memberIds
- [ ] Decline invite → invite removed

**Recipe Sharing:**
- [ ] Share recipe to table
- [ ] Recipe appears in table feed
- [ ] All members see shared recipe
- [ ] Attribution shows correctly

**Member Management:**
- [ ] Owner can remove members
- [ ] Members can leave table
- [ ] Owner cannot leave (must transfer ownership or delete)

**Table Deletion:**
- [ ] Only owner can delete
- [ ] All members notified
- [ ] Shared recipes references cleaned up

---

## Performance Considerations

- **Denormalized Data:** Cache member info in table document
- **Pagination:** Load feed in chunks (20 recipes at a time)
- **Lazy Loading:** Only fetch table details when viewed
- **Caching:** Cache tables list locally
- **Real-time:** Use Firestore listeners for feed updates

---

## Estimated Timeline

| Phase | Task | Time |
|-------|------|------|
| 1 | Data models + service | 2h |
| 2 | Create table flow | 1.5h |
| 3 | Invite members flow | 2h |
| 4 | Share recipe to table | 1.5h |
| 5 | Table feed view | 2h |
| 6 | Table settings | 1.5h |
| 7 | Integration with recipes | 1.5h |
| 8 | Testing & polish | 2h |

**Total:** 14 hours (estimate 2 weeks part-time)

---

## Why This is Separate from Phase 7

Kitchen Tables are a **significant feature** that adds group dynamics to the social layer. It requires:
- New data models and relationships
- Complex permission logic
- Multi-user coordination
- Additional UI surfaces

It makes sense to build **after** the core 1:1 connection features are solid.

---

## When to Implement

**Good time to build this:**
- After Phase 7 (Connection Requests) is stable
- When users are actively using connections
- When you hear requests like "I want to share with my family" or "cooking club needs this"

**Don't build if:**
- Still ironing out connection bugs
- Low active user base
- Other priorities are higher

Save this document and revisit when ready! 🚀
