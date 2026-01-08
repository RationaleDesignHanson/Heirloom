# Heirloom Cloud Functions

Firebase Cloud Functions backend for Heirloom recipe management app.

## Overview

This backend provides REST API endpoints for:
- **Recipe Import**: Scraping and parsing recipes from URLs
- **Language Detection & Translation**: Multilingual recipe support (6 languages)
- **URL Shortening**: CloudKit share URL shortening service
- **Analytics**: Usage tracking and feedback collection

## Setup

### Prerequisites
- Node.js 20+
- Firebase CLI (`npm install -g firebase-tools`)
- Firebase project configured

### Installation

```bash
cd backend/functions
npm install
```

### Environment Variables

Required environment variables (set via Firebase config):

```bash
# Required for language detection and translation
firebase functions:config:set claude.api_key="your-anthropic-api-key-here"

# Verify configuration
firebase functions:config:get
```

### Build & Deploy

```bash
# Build TypeScript
npm run build

# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:detectLanguage
```

## API Endpoints

### Recipe Import

#### `POST /importRecipe`
Import and parse recipe from URL.

**Request:**
```json
{
  "url": "https://example.com/recipe",
  "userId": "optional-user-id"
}
```

**Response:**
```json
{
  "status": "success" | "partial" | "failed",
  "importId": "firestore-doc-id",
  "confidence": 0.95,
  "recipe": {
    "title": "Chocolate Cake",
    "ingredients": ["2 cups flour", ...],
    "instructions": ["Preheat oven...", ...],
    "servings": "12",
    "prepTime": "15 minutes",
    "cookTime": "30 minutes",
    "imageUrl": "https://...",
    ...
  },
  "warnings": [],
  "errors": [],
  "metadata": {
    "parserUsed": "schemaOrg" | "heuristic" | "none",
    "parseTimeMs": 1234,
    "hasSchemaOrg": true,
    "needsFeedback": false,
    "domain": "example.com",
    "sourceUrl": "https://...",
    "timestamp": "2026-01-06T..."
  }
}
```

### Language Detection & Translation

#### `POST /detectLanguage`
Detect language of recipe text using Claude AI.

**Request:**
```json
{
  "text": "Recette de gâteau au chocolat...",
  "hints": {
    "url": "https://example.fr/recette",
    "domain": "example.fr"
  }
}
```

**Response:**
```json
{
  "language": "fr",
  "confidence": 0.98,
  "languageName": "French",
  "detectedUnitSystem": "metric",
  "needsTranslation": true
}
```

**Supported Languages:**
- `en` - English
- `fr` - French
- `es` - Spanish
- `de` - German
- `ja` - Japanese
- `zh` - Chinese
- `ko` - Korean

#### `POST /translateText`
Translate recipe text using Claude AI.

**Request:**
```json
{
  "text": "Crème Brûlée",
  "sourceLanguage": "fr",
  "targetLanguage": "en",
  "context": "title" | "ingredient" | "instruction" | "note"
}
```

**Response:**
```json
{
  "translatedText": "Burnt Cream",
  "sourceLanguage": "fr",
  "targetLanguage": "en",
  "confidence": 0.95,
  "engine": "claude"
}
```

### Feedback

#### `POST /submitFeedback`
Submit user feedback for import quality.

**Request:**
```json
{
  "importId": "firestore-doc-id",
  "userId": "optional-user-id",
  "wasAccurate": true,
  "corrections": [
    {
      "field": "servings",
      "correctValue": "8"
    }
  ],
  "rating": 5,
  "comment": "Perfect import!"
}
```

### URL Shortening

#### `POST /shortenURL`
Shorten CloudKit share URL.

**Request:**
```json
{
  "url": "https://www.icloud.com/...",
  "customCode": "optional-custom-code",
  "recipeId": "optional-recipe-id",
  "userId": "optional-user-id"
}
```

**Response:**
```json
{
  "success": true,
  "shortUrl": "https://heirloom.app/r/abc123",
  "code": "abc123",
  "longUrl": "https://www.icloud.com/..."
}
```

#### `GET /r/:code`
Expand short URL (redirects to original URL).

#### `GET /urlAnalytics/:code`
Get analytics for a short URL.

### Analytics

#### `GET /getStats`
Get import statistics and success rates by domain.

## Architecture

### Services

- **`RecipeImporter`**: Orchestrates recipe scraping and parsing
- **`SchemaOrgParser`**: Extracts recipe from Schema.org JSON-LD
- **`HeuristicParser`**: Fallback parser using DOM heuristics
- **`LanguageService`**: Language detection and translation via Claude API
- **`AnalyticsService`**: Tracks imports, success rates, and feedback
- **`URLShortenerService`**: Manages short URLs and click tracking

### Data Storage

Firestore collections:
- `import_attempts` - Import history and raw HTML (30-day retention)
- `site_patterns` - Domain-specific parsing patterns and success rates
- `short_urls` - URL shortening mapping and analytics
- `url_clicks` - Individual click events for analytics

## Development

### Local Testing

```bash
# Run emulator
firebase emulators:start

# Test endpoint locally
curl -X POST http://localhost:5001/your-project/us-central1/detectLanguage \
  -H "Content-Type: application/json" \
  -d '{"text": "Recette de gâteau au chocolat"}'
```

### Linting & Type Checking

```bash
npm run lint
npm run build  # TypeScript compilation
```

## Scheduled Functions

- **`updateSitePatterns`**: Analyzes site patterns every 6 hours
- **`cleanCache`**: Deletes old import attempts daily at 3 AM

## Cost Optimization

- Language detection/translation uses Claude Sonnet 3.5 (cost-effective, high accuracy)
- Short URL cleanup removes expired entries (90-day TTL)
- Import attempts auto-delete after 30 days (successful) or 1 year (failed)
- Raw HTML only stored for failed/low-confidence imports

## Error Handling

All endpoints return consistent error format:

```json
{
  "error": "Error description",
  "message": "Detailed error message"
}
```

Common error codes:
- `400` - Bad request (missing/invalid parameters)
- `405` - Method not allowed
- `500` - Internal server error

## Monitoring

View logs:
```bash
firebase functions:log
```

Monitor performance:
- Firebase Console → Functions → Metrics
- Track parse times, success rates, and error rates

## Support

For issues or questions, see project documentation at `/docs`.
