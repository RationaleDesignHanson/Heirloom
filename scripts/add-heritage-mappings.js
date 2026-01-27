#!/usr/bin/env node

/**
 * Add heritage theme recipes to id_conversion_mapping.json
 *
 * Maps the new full IDs to their image slugs
 */

const fs = require('fs');
const path = require('path');

const mappingPath = path.join(__dirname, 'theme-image-gen', 'id_conversion_mapping.json');
const mapping = JSON.parse(fs.readFileSync(mappingPath, 'utf8'));

const heritageThemes = [
  {
    themeId: 'presidential-pantry',
    themeName: 'Presidential Pantry',
    count: 14,
    oldPrefix: 'presidential-',
    newPrefix: 'presidential-pantry-'
  },
  {
    themeId: 'literary-kitchen',
    themeName: 'Literary Kitchen',
    count: 14,
    oldPrefix: 'literary-',
    newPrefix: 'literary-kitchen-'
  },
  {
    themeId: 'ancient-table',
    themeName: 'Ancient Table',
    count: 12,
    oldPrefix: 'ancient-',
    newPrefix: 'ancient-table-'
  },
  {
    themeId: 'american-foundation',
    themeName: 'American Foundation',
    count: 12,
    oldPrefix: 'american-',
    newPrefix: 'american-foundation-'
  }
];

console.log('📝 Adding heritage theme mappings...\n');

let addedCount = 0;

heritageThemes.forEach(({ themeId, themeName, count, oldPrefix, newPrefix }) => {
  console.log(`Processing ${themeName}...`);

  for (let i = 1; i <= count; i++) {
    const num = String(i).padStart(3, '0');
    const newId = `${newPrefix}${num}`;
    const oldId = `${oldPrefix}${num}`;

    // Check if already exists
    const exists = mapping.conversions.find(c => c.new_id === newId);
    if (!exists) {
      mapping.conversions.push({
        theme_id: themeId,
        theme_name: themeName,
        old_id: oldId,
        new_id: newId,
        title: `Recipe ${i}`, // Placeholder, will be overwritten by actual title
        sort_order: i
      });
      addedCount++;
    }
  }

  console.log(`  ✓ Added ${count} mappings for ${themeName}`);
});

// Update metadata
mapping.total_recipes = mapping.conversions.length;
mapping.total_themes = 14;
mapping.conversion_date = new Date().toISOString();

// Write back
fs.writeFileSync(mappingPath, JSON.stringify(mapping, null, 2), 'utf8');

console.log(`\n✅ Added ${addedCount} heritage recipe mappings`);
console.log(`📊 Total mappings: ${mapping.conversions.length}`);
