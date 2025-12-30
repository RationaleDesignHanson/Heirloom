# Heirloom Backend - Recipe Import & URL Shortening Service

TypeScript/Node.js Cloud Functions for web recipe import, URL shortening, and analytics.

## 🏗️ Architecture

- **Runtime**: Node.js 20 + TypeScript
- **Framework**: Firebase Cloud Functions (Gen 2)
- **Database**: Firestore (analytics, patterns, training queue)
- **Storage**: Firebase Storage (images, cache)
- **Parsing**: Cheerio (HTML), Schema.org + Heuristic fallback

## 📦 What's Included

### Cloud Functions
**Recipe Import:**
- `importRecipe` - Main import endpoint (called by iOS app)
- `submitFeedback` - User feedback collection
- `getStats` - Admin analytics dashboard
- `updateSitePatterns` - Scheduled learning (every 6 hours)
- `cleanCache` - Scheduled cleanup (daily)

**URL Shortening:**
- `shortenURL` - Generate short URLs for recipe sharing
- `expandURL` - Redirect short codes to CloudKit URLs
- `urlAnalytics` - Get analytics for short URLs

### Parsers
- **Schema.org Parser**: Extracts structured recipe data (JSON-LD)
- **Heuristic Parser**: Fallback for sites without structured data
- **Confidence Scoring**: 0-1 score for import quality

### Analytics & Learning
- Stores ALL import attempts (success + failure)
- Tracks per-domain success rates
- Training queue for failed/low-confidence imports
- User feedback loop for continuous improvement

### Resilience Features
- Retry logic with exponential backoff
- Circuit breaker pattern (prevents cascading failures)
- Timeout handling (15s default)
- Graceful degradation (schema.org → heuristic)

## 🚀 Quick Start

### Prerequisites
- Node.js 20+
- Firebase CLI: `npm install -g firebase-tools`
- Google Cloud account with Firebase enabled

### 1. Install Dependencies
```bash
cd backend/functions
npm install
```

### 2. Configure Firebase Project
```bash
# Login to Firebase
firebase login

# Set project
firebase use dev  # or staging, prod
```

### 3. Run Locally with Emulators
```bash
# Start emulators (Firestore, Functions, Storage, UI)
firebase emulators:start
```

Emulator UI: http://localhost:4000

### 4. Test Import Endpoint
```bash
curl -X POST http://localhost:5001/heirloom-dev/us-central1/importRecipe \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.allrecipes.com/recipe/10813/best-chocolate-chip-cookies/"}'
```

### 5. Deploy to Firebase
```bash
# From the backend directory:
cd backend

# Deploy using the deployment script
./deploy.sh dev      # Deploy to dev
./deploy.sh staging  # Deploy to staging
./deploy.sh prod     # Deploy to production

# Or deploy manually:
firebase deploy --only functions --project dev
```

## 📁 Project Structure

```
Heirloom/backend/
├── firebase.json           # Firebase config
├── .firebaserc            # Project aliases
├── firestore.rules        # Security rules
├── storage.rules          # Storage security
├── firestore.indexes.json # Database indexes
├── deploy.sh              # Deployment script
└── functions/
    ├── package.json
    ├── tsconfig.json
    └── src/
        ├── index.ts                    # Cloud Functions entry
        ├── types.ts                    # TypeScript definitions
        ├── utils/
        │   ├── urlUtils.ts             # URL helpers
        │   └── httpFetcher.ts          # HTTP client
        ├── parsers/
        │   ├── schemaOrgParser.ts      # Schema.org extraction
        │   └── heuristicParser.ts      # Fallback parser
        └── services/
            ├── recipeImporter.ts       # Main orchestrator
            └── analyticsService.ts     # Firestore tracking
```

**Note**: This backend is part of the main Heirloom repository and lives in the `backend/` subdirectory alongside the iOS app.

## 🔧 Configuration

### Environment Variables
Create `.env` in functions directory:

```bash
# Firebase project ID
FIREBASE_PROJECT_ID=heirloom-dev

# Optional: Rate limiting
MAX_REQUESTS_PER_MINUTE=100
MAX_REQUESTS_PER_DOMAIN_PER_MINUTE=10
```

### Firebase Projects
Configure in `.firebaserc`:

```json
{
  "projects": {
    "dev": "heirloom-dev",
    "staging": "heirloom-staging",
    "prod": "heirloom-prod"
  }
}
```

## 📊 Firestore Collections

### `import_attempts`
Stores every import attempt (success + failure):
```typescript
{
  url: string,
  domain: string,
  timestamp: Date,
  userId?: string,
  status: 'success' | 'partial' | 'failed',
  extracted: { title, ingredients, instructions, ... },
  parserUsed: 'schemaOrg' | 'heuristic' | 'none',
  confidence: number,  // 0-1
  htmlStructure: { hasSchemaOrg, hasRecipeCard, ... },
  errors?: [...],
  rawHTML?: string,  // Only for failed/low confidence
  userFeedback?: { wasAccurate, corrections, ... }
}
```

### `site_patterns`
Learned patterns per domain:
```typescript
{
  domain: string,
  successRate: number,
  totalAttempts: number,
  lastSuccessful?: Date,
  bestParser: 'schemaOrg' | 'heuristic',
  commonIssues: string[],
  updatedAt: Date
}
```

### `training_queue`
URLs needing human review:
```typescript
{
  url: string,
  domain: string,
  priority: number,
  attemptCount: number,
  status: 'pending' | 'reviewed' | 'training',
  extractedData?: {...},
  groundTruth?: {...}  // Human-labeled
}
```

### `short_urls`
Shortened URLs for recipe sharing:
```typescript
{
  code: string,  // Document ID (e.g., "abc123")
  longUrl: string,  // Original CloudKit URL
  recipeId?: string,
  userId?: string,
  createdAt: Date,
  expiresAt?: Date,
  clicks: number,
  lastAccessed?: Date,
  clicksByDay?: Record<string, number>,  // Daily click stats
  referrers?: Record<string, number>  // Traffic sources
}
```

### `url_clicks`
Individual click events for detailed analytics:
```typescript
{
  code: string,
  timestamp: Date,
  userAgent?: string,
  referrer?: string,
  ipHash?: string  // Hashed for privacy
}
```

## 🧪 Testing

### Unit Tests
```bash
cd functions
npm test
```

### Integration Tests
```bash
# Start emulators
firebase emulators:start

# Run tests against emulators
npm run test:integration
```

### Test with Real URLs
```bash
# AllRecipes (schema.org)
curl -X POST http://localhost:5001/.../importRecipe \
  -d '{"url": "https://www.allrecipes.com/recipe/10813/..."}'

# Food blog (heuristic)
curl -X POST http://localhost:5001/.../importRecipe \
  -d '{"url": "https://sallysbakingaddiction.com/..."}'
```

## 📈 Monitoring

### View Logs
```bash
# Real-time logs
firebase functions:log --only importRecipe

# Follow logs
firebase functions:log --only importRecipe --follow
```

### Analytics Dashboard
```bash
# Get stats
curl http://localhost:5001/.../getStats

# Returns:
# {
#   totalImports: 1234,
#   successRate: 0.87,
#   topDomains: [...]
# }
```

### Firebase Console
- Functions: https://console.firebase.google.com/project/PROJECT_ID/functions
- Firestore: https://console.firebase.google.com/project/PROJECT_ID/firestore
- Logs: https://console.firebase.google.com/project/PROJECT_ID/logs

## 🔒 Security

### Firestore Rules
- `import_attempts`: Users can only read/write their own
- `site_patterns`: Read-only for clients
- `training_queue`: Admin-only

### Storage Rules
- Recipe images: Public read, server write only
- Import cache: Server-only
- Temp uploads: Authenticated users only

### CORS
Currently allows all origins. Restrict in production:
```typescript
const corsOptions = {
  origin: ['https://heirloom.app', 'https://app.heirloom.com'],
  methods: ['POST', 'GET'],
};
```

## 🚢 Deployment

### Pre-Deployment Checklist
- [ ] Tests pass locally
- [ ] Emulators work correctly
- [ ] Security rules deployed
- [ ] Indexes created
- [ ] Environment variables set

### Deployment Pipeline
```bash
# 1. Deploy to dev (automatic on commit)
git push origin main

# 2. Test in dev environment
./scripts/test-dev.sh

# 3. Deploy to staging
firebase deploy --only functions,firestore:rules,storage --project staging

# 4. Manual QA in staging
./scripts/test-staging.sh

# 5. Deploy to production
firebase deploy --only functions,firestore:rules,storage --project prod

# 6. Monitor for 1 hour
firebase functions:log --project prod --follow
```

## 💰 Cost Estimate

Based on 10,000 imports/month:

- Cloud Functions: $1.00 (execution time)
- Firestore: $2.00 (writes + reads)
- Storage: $0.50 (cached HTML)
- **Total**: ~$3.50/month

Scales linearly with usage.

## 🐛 Troubleshooting

### "Permission denied" errors
- Check Firestore rules
- Ensure user is authenticated
- Verify project permissions

### "Circuit breaker open" errors
- Domain has too many failures
- Wait 1 minute for automatic reset
- Or reset manually: `HttpFetcher.resetCircuitBreaker(domain)`

### Slow imports
- Check network latency
- Increase timeout: `timeoutSeconds: 120`
- Add caching layer

### Low confidence scores
- Site may not have structured data
- Heuristic parser needs improvement
- Add site-specific patterns

## 📚 Additional Resources

- [Firebase Functions Docs](https://firebase.google.com/docs/functions)
- [Cheerio API](https://cheerio.js.org/)
- [Schema.org Recipe](https://schema.org/Recipe)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)

## 🤝 Contributing

1. Create feature branch
2. Write tests
3. Test locally with emulators
4. Deploy to dev
5. Create PR

## 📄 License

Proprietary - Heirloom App
