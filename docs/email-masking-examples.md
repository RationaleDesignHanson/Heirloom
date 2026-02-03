# Email Masking Examples

> **Privacy-preserving email disambiguation for user search**

## Overview

When users search for connections, we show **proportionally masked emails** to distinguish between people with the same name while protecting privacy.

### Algorithm

- **Shows 40% of username** (rounded)
- **Min 1 character, max 10 characters**
- **Always masks at least 1 character**
- **Domain always visible** (for disambiguation)

---

## Visual Examples

### Short Usernames (1-4 characters)

| Original | Masked | Visible % |
|----------|--------|-----------|
| `a@example.com` | `a***@example.com` | 100% (min 1) |
| `ab@example.com` | `a***@example.com` | 50% |
| `john@example.com` | `jo***@example.com` | 50% (2/4) |
| `jane@example.com` | `ja***@example.com` | 50% (2/4) |

---

### Medium Usernames (5-10 characters)

| Original | Masked | Visible % |
|----------|--------|-----------|
| `sarah@example.com` | `sa***@example.com` | 40% (2/5) |
| `david@example.com` | `da***@example.com` | 40% (2/5) |
| `grandma@family.com` | `gra***@family.com` | 43% (3/7) |
| `grandpop@family.com` | `gra***@family.com` | 38% (3/8) |
| `elizabeth@work.com` | `eli***@work.com` | 33% (3/9) |

---

### Long Usernames (11+ characters)

| Original | Masked | Visible % |
|----------|--------|-----------|
| `grandmother@family.com` | `gran***@family.com` | 36% (4/11) |
| `grandfather@family.com` | `gran***@family.com` | 36% (4/11) |
| `grandma_betty@family.com` | `grandma_be***@family.com` | 35% (6/17) |
| `contact_support@company.com` | `contact_su***@company.com` | 35% (6/17) |

---

### Very Long Usernames (capped at 10 chars)

| Original | Masked | Note |
|----------|--------|------|
| `this_is_a_really_long_email@example.com` | `this_is_a_***@example.com` | Max 10 chars shown |
| `firstname.middlename.lastname@company.com` | `firstname.***@company.com` | Max 10 chars shown |

---

## Real-World Scenarios

### Scenario 1: Duplicate Names, Different Domains

**Problem**: Two "Grandma Betty" users

**Solution**: Domain remains visible for disambiguation

```
Search Results: "Grandma Betty"
┌────────────────────────────────┐
│ 👤 Grandma Betty               │
│    gran***@family.com          │  ← Your real grandma
│    "Loves apple pie"           │
├────────────────────────────────┤
│ 👤 Grandma Betty               │
│    gran***@scammer.com         │  ← Different person!
│    "Send me money"             │
└────────────────────────────────┘
```

✅ **User can distinguish**: Different domain = different person

---

### Scenario 2: Duplicate Names, Same Domain

**Problem**: Two family members named "John Smith"

**Solution**: Longer usernames show more characters

```
Search Results: "John Smith"
┌────────────────────────────────┐
│ 👤 John Smith                  │
│    john.smi***@family.org      │  ← Uncle John
│    "Loves fishing"             │
├────────────────────────────────┤
│ 👤 John Smith                  │
│    johns***@family.org         │  ← Cousin John
│    "Loves hiking"              │
└────────────────────────────────┘
```

✅ **User can distinguish**: Different email prefixes visible

---

### Scenario 3: Very Similar Emails

**Problem**: `grandma_betty@family.com` vs `grandma_susan@family.com`

**Solution**: Proportional masking shows enough to distinguish

```
Search Results: "Grandma"
┌────────────────────────────────┐
│ 👤 Grandma Betty               │
│    grandma_be***@family.com    │  ← Shows "betty" prefix
│    "Loves baking"              │
├────────────────────────────────┤
│ 👤 Grandma Susan               │
│    grandma_su***@family.com    │  ← Shows "susan" prefix
│    "Loves gardening"           │
└────────────────────────────────┘
```

✅ **User can distinguish**: Different visible prefixes

---

## Privacy Protection

### What's Hidden

❌ **Full email address** (not exposed to strangers searching)
❌ **Last 60% of username** (protects identity)

### What's Visible

✅ **First 40% of username** (enough to distinguish)
✅ **Full domain** (family.com vs scammer.com)
✅ **Profile picture & bio** (additional context)

---

## Testing

### Run Unit Tests

```bash
xcodebuild test \
  -scheme Heirloom \
  -only-testing:HeirloomTestsV2/EmailMaskerTests
```

**15 test methods** covering:
- Short/medium/long usernames
- Edge cases (invalid format, empty)
- Disambiguation scenarios
- Privacy verification (never shows full username)

---

## Implementation

### Code Location

- **Utility**: `Core/Utilities/EmailMasker.swift`
- **Tests**: `HeirloomTestsV2/Unit/EmailMaskerTests.swift`

### Usage

```swift
// In UserSearchResultRow
if let email = user.email {
    Text(EmailMasker.mask(email))
        .font(HeirloomFonts.caption2)
        .foregroundStyle(HeirloomColors.secondaryText.opacity(0.8))
}
```

### API

```swift
// Mask single email
let masked = EmailMasker.mask("grandma@family.com")
// → "gra***@family.com"

// Mask multiple emails
let masked = EmailMasker.maskAll([
    "john@example.com",
    "jane@example.com"
])
// → ["jo***@example.com", "ja***@example.com"]
```

---

## User Benefits

### Safety ✅
- Can't accidentally connect to wrong person
- "Grandma Betty (gran***@family.com)" ≠ "Grandma Betty (gran***@scammer.com)"

### Privacy ✅
- Grandma's full email not exposed to strangers
- Only shows enough to distinguish

### Usability ✅
- Longer emails show more characters (more useful)
- Familiar pattern (like phone contacts with partial numbers)

---

## Deployment Checklist

Before enabling user search:

- [ ] Run `EmailMaskerTests` - all 15 tests pass
- [ ] Verify Algolia index includes `email` field
- [ ] Test with real duplicate names (if available)
- [ ] Verify masking shows in search results
- [ ] Verify masking shows in profile preview
- [ ] Test edge cases (very short/long emails)

---

## Future Enhancements

### Option 1: User-Controlled Visibility

Let users choose how much to show:
- Public (full email)
- Friends (partial mask)
- Private (maximum mask)

### Option 2: Mutual Friend Indicator

Show mutual connections instead of email:
```
👤 Grandma Betty
   Mutual: Sarah, John
   "Loves baking"
```

### Option 3: Contact Import

Match against device contacts:
```
👤 Grandma Betty ✓
   From Contacts
   "Loves baking"
```

---

## Questions?

**Security**: Email masking prevents impersonation
**Privacy**: Only 40% of username visible
**Usability**: Proportional masking balances safety & clarity

