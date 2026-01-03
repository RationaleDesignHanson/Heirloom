# Git Worktree Workflow Guide

## Overview

Git worktrees allow you to work on multiple branches simultaneously without switching branches or stashing changes. This is ideal for parallel development with multiple Claude Code sessions.

## Directory Structure

```
/Users/matthanson/Heirloom/              → main worktree (main branch)
/Users/matthanson/Heirloom-worktrees/
├── testing/                              → feature/testing-infrastructure
├── services/                             → feature/firebase-refactor
└── views/                                → feature/view-decomposition
```

## Feature Branches

| Branch | Purpose | Worktree Location |
|--------|---------|-------------------|
| `main` | Production-ready code | `/Users/matthanson/Heirloom` |
| `feature/testing-infrastructure` | Testing framework | `/Users/matthanson/Heirloom-worktrees/testing` |
| `feature/firebase-refactor` | Service layer refactoring | `/Users/matthanson/Heirloom-worktrees/services` |
| `feature/view-decomposition` | View layer decomposition | `/Users/matthanson/Heirloom-worktrees/views` |
| `feature/code-quality` | Logging, naming, cleanup | (no worktree) |
| `feature/architecture-modernization` | DI, protocols | (no worktree) |
| `feature/performance-optimization` | Performance improvements | (no worktree) |

## Using Worktrees

### Opening a Claude Code Session in a Worktree

```bash
# Terminal 1: Testing work
cd /Users/matthanson/Heirloom-worktrees/testing
claude  # or open in your IDE

# Terminal 2: Service refactoring
cd /Users/matthanson/Heirloom-worktrees/services
claude  # or open in your IDE

# Terminal 3: View decomposition
cd /Users/matthanson/Heirloom-worktrees/views
claude  # or open in your IDE
```

### Making Changes in a Worktree

```bash
# Navigate to worktree
cd /Users/matthanson/Heirloom-worktrees/testing

# Verify you're on the right branch
git branch  # Should show * feature/testing-infrastructure

# Make changes
# ... edit files ...

# Commit changes
git add .
git commit -m "[Testing] Add Firebase sync tests"

# Push to remote
git push origin feature/testing-infrastructure
```

### Syncing Between Worktrees

**Important:** Each worktree works on its own feature branch. To share work between worktrees:

1. **Push your feature branch to remote:**
   ```bash
   cd /Users/matthanson/Heirloom-worktrees/testing
   git push origin feature/testing-infrastructure
   ```

2. **Merge to main** (from main worktree):
   ```bash
   cd /Users/matthanson/Heirloom
   git checkout main
   git merge feature/testing-infrastructure
   git push origin main
   ```

3. **Update other worktrees** from main:
   ```bash
   cd /Users/matthanson/Heirloom-worktrees/services
   git fetch origin
   git rebase origin/main  # Rebase your feature branch on latest main
   ```

### Coordination Rules (CRITICAL)

#### Rule 1: No Overlapping File Changes
- **testing/** worktree: Only modify files in `HeirloomTests/`, `HeirloomUITests/`
- **services/** worktree: Only modify files in `Core/Services/`
- **views/** worktree: Only modify files in `Features/*/Views/`

If you need to modify the same file in multiple worktrees, **coordinate via main branch** (merge one feature first, then rebase the other).

#### Rule 2: Frequent Syncs
- Push to remote at least once per day
- Merge to main when a logical unit of work is complete
- Rebase feature branches on main daily to avoid conflicts

#### Rule 3: Build Validation
- **Always build and test before pushing:**
  ```bash
  xcodebuild -project Heirloom.xcodeproj -scheme Heirloom -sdk iphonesimulator build test
  ```
- If build fails in your worktree, do NOT push until fixed

#### Rule 4: Communication
- Use git commit messages to communicate what you're working on
- Prefix commits with [Testing], [Services], [Views] for clarity
- If you encounter a conflict, resolve in main worktree first

## Worktree Management Commands

### List all worktrees:
```bash
git worktree list
```

### Check which branch a worktree is on:
```bash
cd /Users/matthanson/Heirloom-worktrees/testing
git branch  # Shows current branch
```

### Remove a worktree (when done):
```bash
git worktree remove /Users/matthanson/Heirloom-worktrees/testing
```

**Note:** This only removes the worktree directory, not the branch. The branch still exists and can be checked out later.

### Prune stale worktrees:
```bash
git worktree prune
```

### Add a new worktree later:
```bash
git worktree add /Users/matthanson/Heirloom-worktrees/performance feature/performance-optimization
```

## Parallel Development Workflow

### Scenario: Three Claude Code sessions working in parallel

**Session 1 (Testing):**
```bash
cd /Users/matthanson/Heirloom-worktrees/testing
# Work on Firebase sync tests
# Commit: "[Testing] Add FirebaseSyncServiceTests with 20 test methods"
git push origin feature/testing-infrastructure
```

**Session 2 (Services):**
```bash
cd /Users/matthanson/Heirloom-worktrees/services
# Extract FirebaseRecordConverter
# Commit: "[Services] Extract FirebaseRecordConverter (300 lines)"
git push origin feature/firebase-refactor
```

**Session 3 (Views):**
```bash
cd /Users/matthanson/Heirloom-worktrees/views
# Decompose RecipeDetailView
# Commit: "[Views] Extract RecipeHeaderSection component"
git push origin feature/view-decomposition
```

**Integration (Main worktree):**
```bash
cd /Users/matthanson/Heirloom
git checkout main

# Merge testing work first
git merge feature/testing-infrastructure
git push origin main

# Merge services work
git merge feature/firebase-refactor
git push origin main

# Merge views work
git merge feature/view-decomposition
git push origin main

# Run full test suite to validate integration
xcodebuild test
```

## Best Practices

### ✅ DO:
- Keep worktrees focused on separate areas of the codebase
- Push frequently to avoid losing work
- Run tests before pushing
- Use descriptive commit messages
- Merge to main when a logical unit is complete
- Delete worktrees when feature is fully merged

### ❌ DON'T:
- Modify the same file in multiple worktrees simultaneously
- Let worktrees diverge from main for more than 1 week
- Push broken code (always validate build passes)
- Work directly in main worktree (use feature branches)
- Forget to sync worktrees after merging to main

## Troubleshooting

### Problem: "Branch is already checked out"
**Cause:** Trying to check out a branch that's already in use by another worktree.

**Solution:** Each worktree must use a unique branch. Either:
1. Create a new branch: `git checkout -b feature/my-new-branch`
2. Remove the existing worktree: `git worktree remove <path>`

### Problem: Merge conflicts when syncing
**Cause:** Both worktrees modified the same file.

**Solution:**
1. In main worktree, merge one feature first
2. In conflicting worktree, rebase on main:
   ```bash
   git fetch origin
   git rebase origin/main
   # Resolve conflicts
   git rebase --continue
   ```

### Problem: Xcode showing wrong files
**Cause:** Xcode caching from different worktree.

**Solution:**
```bash
# Close Xcode
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData
# Reopen Xcode in correct worktree
open Heirloom.xcodeproj
```

## Cleanup After Refactor

Once all refactor work is merged to main, clean up:

```bash
# Remove all worktrees
git worktree remove /Users/matthanson/Heirloom-worktrees/testing
git worktree remove /Users/matthanson/Heirloom-worktrees/services
git worktree remove /Users/matthanson/Heirloom-worktrees/views

# Delete feature branches (optional)
git branch -d feature/testing-infrastructure
git branch -d feature/firebase-refactor
git branch -d feature/view-decomposition

# Remove worktrees directory
rm -rf /Users/matthanson/Heirloom-worktrees
```

## Summary

Git worktrees enable **true parallel development** without branch switching overhead. Use them when:
- Running multiple Claude Code sessions simultaneously
- Working on independent features that don't overlap
- Want to keep main worktree clean for production testing

**Key principle:** Each worktree = separate workspace with its own files, allowing parallel progress without interference.

---

**Created:** January 3, 2026
**Last Updated:** January 3, 2026
**Status:** Infrastructure ready, sequential execution recommended for refactor
