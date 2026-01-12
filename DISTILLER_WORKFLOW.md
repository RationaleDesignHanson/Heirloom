# Distiller Continuous Development Workflow

## Access Methods

### 1. Web Interface (VSCode)
- **Desktop**: http://192.168.1.215:3000
- **Mobile**: Scan QR code on device screen
- **Local**: http://localhost:3000 (when SSH tunneled)

### 2. SSH Access
```bash
ssh distiller@192.168.1.215
cd ~/projects/Heirloom
```

## Git Workflow

### Branch Strategy
- `main` - Your primary development branch (synced from Mac)
- `distiller-dev` - Distiller's working branch for continuous tasks

### Syncing Changes

**From Mac to Distiller:**
```bash
# On Mac: Push changes
git push origin main

# Distiller will pull automatically or:
ssh distiller@192.168.1.215 "cd ~/projects/Heirloom && git pull origin main"
```

**From Distiller to Mac:**
```bash
# On Mac: Fetch Distiller's work
git fetch origin distiller-dev
git checkout distiller-dev
git pull

# Review and merge
git checkout main
git merge distiller-dev
```

## Continuous Development Tasks

### Recommended Tasks for Distiller

**Code Quality:**
- Fix Swift compiler warnings
- Resolve TODO comments
- Refactor code based on patterns
- Add documentation to undocumented functions

**Testing:**
- Write unit tests for existing functions
- Run test suite and fix failures
- Add integration tests

**Maintenance:**
- Update dependencies
- Fix deprecated API usage
- Cleanup unused code

### Starting a Task

1. Access Claude Code at http://192.168.1.215:3000
2. Create a new branch: `git checkout -b distiller-dev`
3. Give Claude Code a specific task:
   - "Fix all Swift compiler warnings in the Core/ directory"
   - "Add unit tests for RecipeImportService"
   - "Implement TODO items in FEATURE_BACKLOG.md"

### Monitoring Progress

**LED Indicators:**
- Yellow: Request received
- Blue: Working on task
- Green: Task completed

**Check Status:**
```bash
ssh distiller@192.168.1.215 "cd ~/projects/Heirloom && git status && git log -3 --oneline"
```

## Best Practices

1. **Separate Branches**: Keep Distiller work on distiller-dev branch
2. **Review Before Merge**: Always review Distiller's commits before merging
3. **Specific Tasks**: Give clear, well-defined tasks for best results
4. **Daily Sync**: Pull Distiller changes each morning to review progress
5. **Commit Often**: Distiller should commit small, atomic changes

## Example Workflow

**Evening (before bed):**
```bash
# Access Claude Code web interface
open http://192.168.1.215:3000

# In Claude Code, create task:
"Please fix all compiler warnings in the Heirloom/Core/ directory. 
Create a separate commit for each file fixed. 
Work on distiller-dev branch."
```

**Morning:**
```bash
# On Mac, review progress
git fetch origin distiller-dev
git log origin/distiller-dev --oneline -10

# If changes look good:
git checkout distiller-dev
git pull
git checkout main
git merge distiller-dev
git push origin main
```

## Troubleshooting

**Distiller not responding:**
```bash
ssh distiller@192.168.1.215 "sudo reboot"
```

**Git conflicts:**
```bash
# On Distiller
cd ~/projects/Heirloom
git stash
git pull origin main
git stash pop
```

**Reset Distiller branch:**
```bash
ssh distiller@192.168.1.215 "cd ~/projects/Heirloom && git checkout main && git branch -D distiller-dev && git checkout -b distiller-dev"
```
