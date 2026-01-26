# Complete Theme Cover Images (14 Total)

## Theme Collections (10 covers)

### 1. Automat Classics
- **File:** `theme-01-automat-classics-cover.webp`
- **Era:** 1920s-1950s
- **Description:** NYC automat cafeteria with chrome dispensers and art deco styling

### 2. Golden Age of Rail
- **File:** `theme-02-railroad-dining-cover.webp`
- **Era:** 1920s-1950s
- **Description:** Luxury train dining car with white tablecloths and landscape views

### 3. Victory Kitchen
- **File:** `theme-03-victory-kitchen-cover.webp`
- **Era:** 1940s
- **Description:** WWII home front kitchen with patriotic accents and ration books

### 4. Navy Mess Hall
- **File:** `theme-04-navy-mess-cover.webp`
- **Era:** Timeless Naval Tradition
- **Description:** Naval mess hall with stainless steel trays and hearty portions

### 5. Boston Cooking School
- **File:** `theme-05-boston-cooking-cover.webp`
- **Era:** 1890s-1920s
- **Description:** Victorian Boston kitchen with antique cookbooks and brass cookware

### 6. Southern Roots
- **File:** `theme-06-southern-roots-cover.webp`
- **Era:** Traditional Southern
- **Description:** Warm Southern table with comfort food and Mason jars

### 7. Scandinavian Heritage
- **File:** `theme-07-scandinavian-cover.webp`
- **Era:** Nordic Heritage
- **Description:** Clean Nordic kitchen with seasonal produce and minimalist aesthetic

### 8. German-American Heritage
- **File:** `theme-08-german-american-cover.webp`
- **Era:** Old World Heritage
- **Description:** Traditional German-American feast table with robust dishes

### 9. Quick Weeknight Meals
- **File:** `theme-09-quick-weeknight-cover.webp`
- **Era:** 1950s-1960s
- **Description:** Cheerful suburban kitchen with practical family meals

### 10. Sunday Suppers
- **File:** `theme-10-sunday-suppers-cover.webp`
- **Era:** Timeless Family Tradition
- **Description:** Multi-generational family supper table with heirloom dishes

---

## Heritage Collections (4 covers)

### 11. Presidential Pantry
- **File:** `presidential-pantry-cover.webp`
- **Era:** 1700s-1900s
- **Description:** Elegant White House state dining room with presidential china and patriotic accents

### 12. Literary Kitchen
- **File:** `literary-kitchen-cover.webp`
- **Era:** Victorian-Edwardian
- **Description:** Cozy library reading nook with vintage cookbooks and candlelight

### 13. Ancient Table
- **File:** `ancient-table-cover.webp`
- **Era:** Ancient Greece & Rome
- **Description:** Classical dining room with amphoras, olive branches, and archaeological styling

### 14. American Foundation
- **File:** `american-foundation-cover.webp`
- **Era:** 1700s-1800s
- **Description:** Colonial American hearth kitchen with copper pots and candlelit warmth

---

## Technical Specs

- **Format:** WebP
- **Aspect Ratio:** 16:9 (1600×900) landscape
- **Quality:** 90
- **Style:** Heritage aesthetic with no text, people, or modern elements
- **Total Cost:** 14 × $0.003 = $0.04
- **Generation Time:** ~2 minutes (7 second delay)

## Generate All Covers

```bash
cd /Users/matthanson/Heirloom/scripts/theme-image-gen

# Preview prompts first
./run_image_gen.sh preview-covers

# Generate all 14 covers
./run_image_gen.sh generate-covers

# Check status
./run_image_gen.sh status-covers
```

## Individual Generation

Generate a specific cover:

```bash
python3 generate_theme_covers.py --theme theme-01-automat-classics
python3 generate_theme_covers.py --theme presidential-pantry
```
