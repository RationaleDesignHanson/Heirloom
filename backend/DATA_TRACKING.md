# Recipe Import Data Tracking & Fine-Tuning

This document explains how we track recipe import data and use it to improve the system over time.

## Overview

Every recipe import attempt (successful or failed) is logged to Firestore for analytics and future fine-tuning of our parsers.

## Data Storage Locations

### 1. Firestore Collections

#### `import_attempts` Collection
**Purpose**: Store every import attempt for analytics and learning

**What We Store:**
```typescript
{
  id: string;                        // Auto-generated Firestore ID
  url: string;                       // Original recipe URL
  domain: string;                    // Extracted domain (e.g., "allrecipes.com")
  timestamp: Date;                   // When import occurred
  userId?: string;                   // Optional user ID (for user-specific analytics)
  status: 'success' | 'partial' | 'failed';  // Import outcome
  extracted: Partial<ExtractedRecipe>;       // Parsed recipe data
  parserUsed: 'schemaOrg' | 'heuristic' | 'none';  // Which parser succeeded
  confidence: number;                // 0-1 confidence score
  rawHTML?: string;                  // Full page HTML (only for failed/low confidence)
  htmlStructure: {                   // Page structure metadata
    hasSchemaOrg: boolean;
    hasRecipeCard: boolean;
    dominantTags: string[];
    headingCount: number;
    listCount: number;
    imageCount: number;
  };
  errors?: ImportError[];            // Any errors encountered
  userFeedback?: {                   // User corrections (if provided)
    wasAccurate: boolean;
    corrections: { field: string; correctValue: string }[];
    rating: number;
    comment: string;
    timestamp: Date;
  };
  parseTimeMs: number;               // How long parsing took
}
```

**When We Store Raw HTML:**
- Status is 'failed'
- OR confidence < 0.7 (70%)

This allows us to retrain parsers on difficult pages.

#### `site_patterns` Collection
**Purpose**: Track performance by domain for adaptive parsing

**What We Store:**
```typescript
{
  domain: string;                    // e.g., "bonappetit.com"
  successRate: number;               // 0-1 success rate
  totalAttempts: number;             // Total imports from this domain
  successfulAttempts: number;        // Successful imports
  lastSuccessful?: Date;             // Most recent success
  lastFailed?: Date;                 // Most recent failure
  bestParser: 'schemaOrg' | 'heuristic';  // Which parser works best
  commonIssues: string[];            // Recurring problems
  htmlPatterns?: {                   // Domain-specific patterns (future)
    ingredientSelectors: string[];
    instructionSelectors: string[];
    titleSelectors: string[];
  };
  updatedAt: Date;
}
```

#### `training_queue` Collection
**Purpose**: Priority queue for manual review and retraining

**What We Store:**
```typescript
{
  url: string;                       // Recipe URL that failed
  domain: string;
  priority: number;                  // Higher = more important (based on domain popularity)
  attemptCount: number;              // How many times we've tried
  lastAttempted: Date;
  status: 'pending' | 'reviewed' | 'training';
  extractedData: Partial<ExtractedRecipe>;  // What we got (wrong)
  groundTruth?: ExtractedRecipe;     // Human-labeled correct data
  createdAt: Date;
  reviewedAt?: Date;
  reviewedBy?: string;               // Who reviewed it
}
```

## Data Flow for Fine-Tuning

```
1. Recipe Import Attempt
   ↓
2. Parse with schemaOrg parser
   ↓
3. If low confidence → Try heuristic parser
   ↓
4. Extract author via fallback methods
   ↓
5. Calculate confidence score
   ↓
6. Store in Firestore:
   - import_attempts collection
   - Update site_patterns collection
   - Add to training_queue (if needed)
   ↓
7. Return result to iOS app
```

## How Data Is Used for Improvement

### Automatic Learning (Implemented)

1. **Domain Pattern Tracking**
   - Track which parser works best per domain
   - Track success rates by site
   - Future: Use domain patterns to choose parser strategy

2. **Confidence Scoring**
   - Multi-factor scoring (ingredients, instructions quality, metadata)
   - Rewards comprehensive content (long detailed instructions)
   - Penalizes missing critical fields

3. **Author Extraction Fallback**
   - 4 fallback strategies when schema.org doesn't provide author
   - Logs which strategy worked for future optimization

### Manual Review Process (Future)

1. **Training Queue**
   - Failed imports automatically added to queue
   - Prioritized by domain popularity
   - Manual review adds ground truth labels

2. **Retraining Workflow**
   ```
   1. Review failed imports in Firebase Console
   2. Manually extract correct recipe data
   3. Store as ground truth in training_queue
   4. Use labeled data to:
      - Improve heuristic parser selectors
      - Train custom ML model (future)
      - Generate domain-specific patterns
   ```

## Accessing the Data

### View in Firebase Console

**Import Attempts:**
```
https://console.firebase.google.com/project/heriloom-dev/firestore/data/import_attempts
```

**Site Patterns:**
```
https://console.firebase.google.com/project/heriloom-dev/firestore/data/site_patterns
```

**Training Queue:**
```
https://console.firebase.google.com/project/heriloom-dev/firestore/data/training_queue
```

### Query via API

**Get Statistics:**
```bash
curl https://getstats-7kk7et3yua-uc.a.run.app
```

Returns:
```json
{
  "totalImports": 150,
  "successRate": 0.94,
  "topDomains": [
    { "domain": "allrecipes.com", "count": 45 },
    { "domain": "bonappetit.com", "count": 32 }
  ]
}
```

**Get User's Imports:**
(iOS app will implement this)
```typescript
const db = admin.firestore();
const userImports = await db.collection('import_attempts')
  .where('userId', '==', userId)
  .orderBy('timestamp', 'desc')
  .limit(20)
  .get();
```

## Confidence Scoring Breakdown

Total possible: 102 points

| Category | Points | Threshold |
|----------|--------|-----------|
| **Title** | 15 | Must have |
| **Ingredients** | 35 | Full credit at 5+ |
| **Instructions** | 35 | Count + quality |
| **Image** | 8 | UX important |
| **Timing** | 4 | Total/prep/cook |
| **Servings** | 2 | Useful |
| **Author** | 2 | Attribution |
| **Description** | 1 | Context |

**Instruction Quality Bonus:**
- Count: 5 pts per step (max 25 pts at 5 steps)
- Quality: Up to 10 pts for comprehensive instructions (>500 chars)

This rewards detailed paragraph-style instructions (like Bon Appetit) rather than just counting steps.

## Privacy & Data Retention

- **User-specific data**: Only stored if userId provided
- **Raw HTML**: Only stored for failed/low confidence imports
- **Cleanup**: Automated job deletes successful imports after 30 days
- **Failed imports**: Retained for 1 year for analysis

## Future Enhancements

1. **ML-Powered Extraction**
   - Train custom model on labeled data
   - Use training_queue ground truth as dataset
   - Deploy fine-tuned model for difficult sites

2. **Domain-Specific Parsers**
   - Generate custom selectors per domain
   - Store in site_patterns.htmlPatterns
   - Auto-apply best strategy per site

3. **Feedback Loop**
   - User corrections automatically improve parsers
   - A/B test parser improvements
   - Track confidence score improvements over time

4. **Analytics Dashboard**
   - Visualize success rates by domain
   - Track confidence score trends
   - Identify problematic sites for manual review
