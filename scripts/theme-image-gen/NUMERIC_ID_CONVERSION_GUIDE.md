# Numeric ID Conversion Guide

## Why Convert to Numeric IDs?

✓ **Title-change proof** - Recipe IDs won't break if titles change
✓ **Consistent** - All themes follow same pattern
✓ **Cleaner URLs** - No special characters or long descriptive names
✓ **Sequential** - Clear ordering (001, 002, 003...)
✓ **Future-proof** - Easier database management

## Accuracy Guarantees

The conversion script ensures 100% accuracy through:

1. **Automatic Backup** - Original files saved with timestamp
2. **Dry Run Preview** - See all changes before executing
3. **Complete Mapping** - Every old ID → new ID documented
4. **Data Validation** - Verifies all recipe data preserved
5. **Audit Trail** - Full conversion log with timestamps

## Step-by-Step Process

### Step 1: Preview the Conversion (Dry Run)

```bash
cd /Users/matthanson/Heirloom/scripts/theme-image-gen

# See what will change WITHOUT modifying files
python3 convert_to_numeric_ids.py --dry-run
```

**Output:**
```
================================================================================
Recipe ID Conversion to Numeric Format
================================================================================

📋 DRY RUN MODE - No files will be modified

Found 14 theme files

Processing: theme-01-automat-classics.json
  Recipes: 14
    automat-mac-cheese → automat-classics-001 (Horn & Hardart Macaroni and Cheese)
    automat-baked-beans → automat-classics-002 (Automat Baked Beans)
    automat-rice-pudding → automat-classics-003 (Creamy Rice Pudding)
    ... and 11 more

Processing: theme-11-presidential-pantry.json
  Recipes: 14
    presidential-001 → presidential-pantry-001 (Martha Washington's Great Cake)
    presidential-002 → presidential-pantry-002 (Thomas Jefferson's Ice Cream)
    ... and 12 more

================================================================================
Summary:
  Total themes processed: 14
  Total recipes converted: 186
  Mapping file: id_conversion_mapping_preview.json
================================================================================

✓ Dry run complete - no files were modified
✓ Review the preview mapping at: id_conversion_mapping_preview.json
```

### Step 2: Review the Mapping File

```bash
# Open the preview mapping to verify accuracy
cat id_conversion_mapping_preview.json | python3 -m json.tool | less
```

**Mapping Structure:**
```json
{
  "conversion_date": "2026-01-26T16:00:00",
  "total_themes": 14,
  "total_recipes": 186,
  "dry_run": true,
  "conversions": [
    {
      "theme_id": "automat-classics",
      "theme_name": "Automat Classics",
      "old_id": "automat-mac-cheese",
      "new_id": "automat-classics-001",
      "title": "Horn & Hardart Macaroni and Cheese",
      "sort_order": 1
    },
    // ... 185 more conversions
  ]
}
```

### Step 3: Execute the Conversion

Once you've verified the preview looks correct:

```bash
# Execute the conversion (creates backup automatically)
python3 convert_to_numeric_ids.py --execute
```

**Output:**
```
================================================================================
Recipe ID Conversion to Numeric Format
================================================================================

⚠️  EXECUTE MODE - Files will be modified
Creating backup first...

✓ Backup created: backups/20260126_160000

Found 14 theme files

Processing: theme-01-automat-classics.json
  Recipes: 14
    automat-mac-cheese → automat-classics-001 (Horn & Hardart Macaroni and Cheese)
    ...

================================================================================
Summary:
  Total themes processed: 14
  Total recipes converted: 186
  Mapping file: id_conversion_mapping.json
  Backup location: backups/20260126_160000
================================================================================

✓ Conversion complete!
✓ Original files backed up to: backups/20260126_160000
✓ Conversion mapping saved to: id_conversion_mapping.json
```

### Step 4: Verify the Conversion

```bash
# Check a few recipe IDs in the converted files
python3 -c "
import json, glob
files = glob.glob('../../themerecipes/theme-*.json')[:2]
for f in files:
    data = json.load(open(f))
    print(f'{data[\"themeName\"]}:')
    for r in data['recipes'][:3]:
        print(f'  {r[\"id\"]}: {r[\"title\"]}')
    print()
"
```

### Step 5: Clean Old Images

```bash
# Remove old images (they use old IDs)
rm images/*.webp

# Verify they're gone
ls images/
# Should show: empty or only theme covers
```

### Step 6: Regenerate All Images

```bash
# Generate all 186 recipe images with new numeric IDs
./run_image_gen.sh generate
```

Cost: 186 × $0.003 = $0.56
Time: ~22 minutes

### Step 7: Generate Theme Covers

```bash
# Generate 14 theme cover images
./run_image_gen.sh generate-covers
```

Cost: 14 × $0.003 = $0.04
Time: ~2 minutes

### Step 8: Upload to Firebase

```bash
# Upload all images with new numeric IDs
python3 upload_theme_images_to_firebase.py
```

## New Naming Convention

After conversion, all images will use consistent numeric IDs:

```
automat-classics-001.webp
automat-classics-002.webp
railroad-dining-001.webp
railroad-dining-002.webp
victory-kitchen-001.webp
presidential-pantry-001.webp
literary-kitchen-001.webp
ancient-table-001.webp
american-foundation-001.webp
```

Theme covers:
```
automat-classics-cover.webp
presidential-pantry-cover.webp
...
```

## Safety Features

### Automatic Backup
Every execution creates a timestamped backup:
```
backups/
  20260126_160000/
    theme-01-automat-classics.json
    theme-02-railroad-dining.json
    ...
    newthemes/
      theme-11-presidential-pantry.json
      ...
```

### Rollback if Needed
```bash
# If something went wrong, restore from backup
BACKUP_DIR="backups/20260126_160000"  # Use your timestamp

# Restore main themes
cp $BACKUP_DIR/theme-*.json ../../themerecipes/

# Restore heritage themes
cp $BACKUP_DIR/newthemes/theme-*.json ../../themerecipes/newthemes/
```

### Complete Audit Trail

The mapping file (`id_conversion_mapping.json`) contains:
- Exact timestamp of conversion
- Every old ID → new ID mapping
- Recipe titles for cross-reference
- Original sort order preserved

## Validation Checklist

Before uploading to Firebase, verify:

- [ ] Mapping file shows all 186 conversions
- [ ] All theme JSON files have numeric IDs (001, 002, 003...)
- [ ] Recipe counts match: 14 themes, 186 total recipes
- [ ] Generated images use new numeric IDs
- [ ] No duplicate IDs across themes
- [ ] Sort order preserved (001 is first recipe, etc.)

## Total Cost & Time

| Task | Cost | Time |
|------|------|------|
| Conversion | $0 | 2 min |
| Regenerate recipes | $0.56 | ~22 min |
| Generate covers | $0.04 | ~2 min |
| Upload to Firebase | $0 | 5 min |
| **Total** | **$0.60** | **~31 min** |

## Questions to Verify Accuracy

1. **Does the mapping file show all 186 recipes?**
   ```bash
   python3 -c "import json; print(len(json.load(open('id_conversion_mapping.json'))['conversions']))"
   # Should output: 186
   ```

2. **Are IDs sequential within each theme?**
   ```bash
   python3 -c "
   import json
   data = json.load(open('../../themerecipes/theme-01-automat-classics.json'))
   ids = [r['id'] for r in data['recipes']]
   print('First 5 IDs:', ids[:5])
   # Should show: automat-classics-001, 002, 003, 004, 005
   "
   ```

3. **Are recipe titles preserved?**
   Check the mapping file - old and new IDs should have same titles

4. **Can you find specific recipes in mapping?**
   ```bash
   grep "Martha Washington" id_conversion_mapping.json
   # Should show the conversion for this recipe
   ```

## Support

If anything looks wrong:
1. Stop immediately
2. Check the mapping file for anomalies
3. Restore from backup if needed
4. Original files are safely backed up with timestamp

The conversion is reversible and fully documented.
