# Heirloom Testing Infrastructure: Analysis & Implementation

## Context
Heirloom is a recipe app preparing for beta launch. The existing automated testing is outdated and broken. We need a complete overhaul to establish a robust, modern, and performant testing system that covers all features, services, and database operations.

### Known Feature Set
- **Recipe CRUD**: Create, read, update, delete recipes with rich metadata
- **Recipe Scaling ("Smallify")**: Adjust serving sizes with intelligent ingredient scaling
- **Social Sharing**: Share recipes with attribution and lineage tracking (who shared what, recipe "family trees")
- **Video-to-Recipe Import**: AI-powered extraction of recipes from video content
- **Multilingual Import**: Parse and import recipes from multiple languages
- **Heritage Recipe Collections**: Curated collections to solve cold-start problem for new users
- **User Accounts**: Authentication, profiles, preferences
- **Recipe Collections/Cookbooks**: User-organized recipe groupings

---

## Phase 1: Deep Codebase Analysis

**Use extended thinking (ultrathink) for this entire phase.**

### 1.1 Tech Stack Discovery
```
Investigate and document:
- Frontend framework (React Native, Swift/SwiftUI, Flutter, etc.)
- Backend/API layer (Node, Python, serverless functions, etc.)
- Database (PostgreSQL, MongoDB, Supabase, Firebase, etc.)
- Authentication provider (Auth0, Supabase Auth, Firebase Auth, etc.)
- File/media storage (S3, Cloudflare R2, etc.)
- AI/ML services for video import (OpenAI, Claude, custom models)
- Build tools and package manager
- Current test files and configurations (even if broken)
```

### 1.2 Architecture Mapping
```
Document:
- Directory structure and module organization
- API routes and endpoint inventory
- Data models and schema (Recipe, User, Collection, Share, etc.)
- Service boundaries and external integrations
- Environment variables and secrets required
- State management approach (if mobile/frontend heavy)
```

### 1.3 Existing Test Audit
```
Analyze:
- Location of all existing test files
- Currently installed test dependencies
- Why tests are broken (outdated deps, API drift, missing mocks)
- What percentage of features have any test coverage
- Test configuration files and their state
```

### 1.4 Critical Path Identification
```
Identify and rank by importance:
1. Recipe creation and storage (core value)
2. Recipe scaling calculations (key differentiator)
3. User authentication flows
4. Social sharing and attribution tracking
5. Video import pipeline
6. Search and discovery
```

---

## Phase 2: Testing Strategy Design

**Use extended thinking (ultrathink) for this entire phase.**

### 2.1 Framework Recommendations

Based on discovered stack, recommend appropriate tools. General guidance:

| Layer | Recommended Tools |
|-------|-------------------|
| Unit Tests | Vitest (JS/TS), pytest (Python), XCTest (Swift) |
| Integration | Vitest + Supertest, pytest + httpx |
| E2E Mobile | Detox (React Native), XCUITest (iOS), Maestro |
| E2E Web | Playwright |
| API Testing | Vitest + mock servers, Postman/Newman for contract tests |
| DB Testing | pgTAP (Postgres), in-memory SQLite, test containers |

### 2.2 Test Architecture Design

```
tests/
├── unit/                     # Fast, isolated tests (~70%)
│   ├── utils/
│   ├── models/
│   ├── scaling/              # Recipe scaling logic
│   └── parsers/              # Import parsers
├── integration/              # Service boundary tests (~20%)
│   ├── api/
│   ├── database/
│   └── services/
├── e2e/                      # Critical user flows (~10%)
│   ├── auth/
│   ├── recipes/
│   └── sharing/
├── fixtures/                 # Test data
│   ├── recipes/
│   ├── users/
│   └── media/
├── mocks/                    # Mock implementations
│   ├── services/
│   └── factories/
└── helpers/                  # Shared utilities
```

### 2.3 Heirloom-Specific Testing Considerations

**Recipe Scaling ("Smallify")**
- Fractional scaling (halving, quartering)
- Upscaling (doubling, tripling)
- Ingredient type handling (volumetric, weight, count, descriptive)
- Edge cases: "pinch of salt", "to taste", ranges ("2-3 cups")
- Fraction display (1/4 vs 0.25)
- Unit conversion during scaling

**Social Sharing & Lineage**
- Attribution chain integrity
- Privacy settings propagation
- Circular reference prevention
- Lineage tree accuracy
- Share count accuracy

**Video-to-Recipe Import**
- Mock AI service responses
- Parsing accuracy validation
- Error handling for failed extractions
- Partial extraction handling
- Rate limiting and queue management

**Multilingual Import**
- Character encoding handling
- Measurement unit localization
- Ingredient name normalization
- RTL language support (if applicable)

---

## Phase 3: Implementation

### 3.1 Foundation Setup

```bash
# Example for JS/TS stack - adapt based on discovered stack
# Install test frameworks
npm install -D vitest @vitest/coverage-v8 @vitest/ui
npm install -D @testing-library/react @testing-library/jest-dom
npm install -D msw                    # API mocking
npm install -D @faker-js/faker        # Test data generation
npm install -D testcontainers         # DB testing (if applicable)

# For E2E
npm install -D playwright @playwright/test
# OR for React Native
npm install -D detox
```

Create configuration files:
- `vitest.config.ts` with proper paths, coverage thresholds
- `playwright.config.ts` for E2E
- `.env.test` for test environment variables

### 3.2 Test Utilities & Factories

Create `/tests/helpers/` with:

```typescript
// factories/recipe.factory.ts
export const createRecipe = (overrides?: Partial<Recipe>): Recipe => ({
  id: faker.string.uuid(),
  title: faker.food.dish(),
  description: faker.food.description(),
  servings: faker.number.int({ min: 1, max: 12 }),
  prepTime: faker.number.int({ min: 5, max: 60 }),
  cookTime: faker.number.int({ min: 10, max: 180 }),
  ingredients: generateIngredients(),
  instructions: generateInstructions(),
  createdBy: faker.string.uuid(),
  createdAt: faker.date.recent(),
  lineage: null,
  ...overrides,
});

// factories/ingredient.factory.ts
export const createIngredient = (overrides?: Partial<Ingredient>): Ingredient => ({
  id: faker.string.uuid(),
  name: faker.food.ingredient(),
  quantity: faker.number.float({ min: 0.25, max: 4, precision: 0.25 }),
  unit: faker.helpers.arrayElement(['cup', 'tbsp', 'tsp', 'oz', 'lb', 'g', 'ml', 'piece']),
  notes: faker.helpers.maybe(() => faker.food.adjective()),
  ...overrides,
});

// fixtures/recipes.fixtures.ts
export const SCALING_TEST_RECIPES = {
  simple: createRecipe({ servings: 4, ingredients: [...] }),
  fractional: createRecipe({ /* recipe with 1/3 cup, etc */ }),
  mixedUnits: createRecipe({ /* recipe with cups, grams, pieces */ }),
  descriptive: createRecipe({ /* recipe with "pinch", "to taste" */ }),
};
```

### 3.3 Database Testing Infrastructure

```typescript
// helpers/db.helper.ts
export const setupTestDatabase = async () => {
  // Create isolated test database or use transactions
};

export const seedTestData = async (scenario: 'empty' | 'basic' | 'full') => {
  // Seed appropriate test data
};

export const cleanupTestDatabase = async () => {
  // Rollback or truncate
};

// Use transactions for isolation
export const withTestTransaction = async (fn: () => Promise<void>) => {
  const tx = await db.transaction();
  try {
    await fn();
  } finally {
    await tx.rollback();
  }
};
```

### 3.4 Service Mocking

```typescript
// mocks/services/ai-import.mock.ts
export const mockVideoImportService = {
  extractRecipe: vi.fn().mockResolvedValue({
    title: 'Extracted Recipe',
    ingredients: [...],
    instructions: [...],
    confidence: 0.92,
  }),
  
  extractRecipeWithError: vi.fn().mockRejectedValue(
    new Error('Failed to process video')
  ),
  
  extractRecipePartial: vi.fn().mockResolvedValue({
    title: 'Partial Recipe',
    ingredients: [...],
    instructions: null, // Missing instructions
    confidence: 0.65,
  }),
};

// mocks/handlers.ts (MSW)
export const handlers = [
  http.post('/api/import/video', async ({ request }) => {
    // Return mock response
  }),
  http.get('/api/recipes/:id', async ({ params }) => {
    // Return mock recipe
  }),
];
```

---

## Phase 4: Heirloom Test Suites

### 4.1 Recipe Scaling Tests (Critical)

```typescript
// tests/unit/scaling/recipe-scaler.test.ts
describe('Recipe Scaler', () => {
  describe('Basic Scaling', () => {
    it('doubles all ingredients when scaling 4 servings to 8', () => {});
    it('halves all ingredients when scaling 4 servings to 2', () => {});
    it('handles fractional scaling (4 to 6 servings)', () => {});
  });
  
  describe('Ingredient Type Handling', () => {
    it('scales volumetric measurements (cups, tbsp)', () => {});
    it('scales weight measurements (oz, lb, g)', () => {});
    it('scales count ingredients (2 eggs → 4 eggs)', () => {});
    it('preserves descriptive amounts ("pinch of salt")', () => {});
    it('handles "to taste" ingredients unchanged', () => {});
  });
  
  describe('Fraction Display', () => {
    it('displays 0.5 as 1/2', () => {});
    it('displays 0.25 as 1/4', () => {});
    it('displays 0.33 as 1/3', () => {});
    it('displays 1.5 as 1 1/2', () => {});
    it('rounds to nearest displayable fraction', () => {});
  });
  
  describe('Unit Conversion', () => {
    it('converts 4 tbsp to 1/4 cup when scaling up', () => {});
    it('converts 1/8 cup to 2 tbsp when scaling down', () => {});
    it('suggests unit changes for readability', () => {});
  });
  
  describe('Edge Cases', () => {
    it('handles range quantities ("2-3 cups")', () => {});
    it('handles zero or null quantities gracefully', () => {});
    it('handles recipes with 1 serving base', () => {});
    it('prevents scaling to 0 servings', () => {});
    it('handles very large scale factors (10x)', () => {});
  });
});
```

### 4.2 Social Sharing & Lineage Tests

```typescript
// tests/unit/sharing/lineage.test.ts
describe('Recipe Lineage', () => {
  describe('Attribution Chain', () => {
    it('tracks original creator through multiple shares', () => {});
    it('maintains intermediate sharers in chain', () => {});
    it('preserves lineage when recipe is edited after share', () => {});
  });
  
  describe('Privacy Propagation', () => {
    it('respects private recipe share restrictions', () => {});
    it('allows public recipes to be reshared', () => {});
    it('updates downstream visibility when source goes private', () => {});
  });
  
  describe('Lineage Tree', () => {
    it('builds accurate family tree for recipe', () => {});
    it('handles forked recipes (edited after sharing)', () => {});
    it('prevents circular references', () => {});
    it('calculates share depth correctly', () => {});
  });
});

// tests/integration/sharing/share-flow.test.ts
describe('Share Flow Integration', () => {
  it('creates share record with correct attribution', () => {});
  it('sends notification to recipient', () => {});
  it('recipient can view shared recipe', () => {});
  it('recipient can save copy to their collection', () => {});
  it('share count increments on original recipe', () => {});
});
```

### 4.3 Video Import Tests

```typescript
// tests/unit/import/video-parser.test.ts
describe('Video Import Parser', () => {
  it('extracts recipe title from AI response', () => {});
  it('parses ingredients list correctly', () => {});
  it('orders instructions sequentially', () => {});
  it('extracts timing information when available', () => {});
  it('handles missing fields gracefully', () => {});
});

// tests/integration/import/video-import.test.ts
describe('Video Import Pipeline', () => {
  beforeEach(() => {
    // Setup MSW handlers for AI service
  });
  
  it('accepts video URL and queues processing', () => {});
  it('returns extracted recipe on success', () => {});
  it('handles AI service timeout gracefully', () => {});
  it('reports confidence score to user', () => {});
  it('allows user to edit extracted recipe before saving', () => {});
  it('rate limits import requests per user', () => {});
});
```

### 4.4 Multilingual Import Tests

```typescript
// tests/unit/import/multilingual.test.ts
describe('Multilingual Import', () => {
  describe('Character Encoding', () => {
    it('handles UTF-8 encoded recipes', () => {});
    it('handles special characters (é, ñ, ü)', () => {});
    it('handles CJK characters', () => {});
  });
  
  describe('Measurement Localization', () => {
    it('converts metric to imperial (optional)', () => {});
    it('recognizes localized unit names (cucharada, tasse)', () => {});
    it('preserves original units when requested', () => {});
  });
  
  describe('Language Detection', () => {
    it('auto-detects recipe language', () => {});
    it('handles mixed-language recipes', () => {});
  });
});
```

### 4.5 Heritage Collections Tests

```typescript
// tests/integration/collections/heritage.test.ts
describe('Heritage Recipe Collections', () => {
  it('seeds new user with heritage collection access', () => {});
  it('heritage recipes have correct attribution to Heirloom', () => {});
  it('users can save heritage recipes to personal collection', () => {});
  it('saving heritage recipe creates proper lineage', () => {});
  it('heritage collections are read-only', () => {});
});
```

### 4.6 Database Tests

```typescript
// tests/database/recipes.db.test.ts
describe('Recipe Database Operations', () => {
  describe('CRUD', () => {
    it('creates recipe with all fields', () => {});
    it('reads recipe by ID', () => {});
    it('updates recipe preserving unchanged fields', () => {});
    it('soft deletes recipe', () => {});
  });
  
  describe('Queries', () => {
    it('searches recipes by title', () => {});
    it('filters recipes by tag', () => {});
    it('paginates large result sets', () => {});
    it('sorts by multiple criteria', () => {});
  });
  
  describe('Constraints', () => {
    it('enforces unique recipe ID', () => {});
    it('requires recipe title', () => {});
    it('validates ingredient structure', () => {});
  });
  
  describe('Relationships', () => {
    it('cascades user deletion to recipes', () => {});
    it('maintains lineage integrity on recipe deletion', () => {});
    it('updates collection counts on recipe add/remove', () => {});
  });
});

// tests/database/migrations.test.ts
describe('Database Migrations', () => {
  it('applies all migrations in order', () => {});
  it('rollback reverses last migration', () => {});
  it('handles data migration for schema changes', () => {});
});
```

### 4.7 E2E Critical Flows

```typescript
// tests/e2e/recipes/create-recipe.e2e.ts
describe('Create Recipe Flow', () => {
  it('user can create recipe from scratch', async () => {
    // Login
    // Navigate to create
    // Fill form
    // Add ingredients
    // Add instructions
    // Save
    // Verify recipe appears in collection
  });
  
  it('user can import recipe from URL', async () => {});
  
  it('user can scale recipe and save scaled version', async () => {});
});

// tests/e2e/sharing/share-recipe.e2e.ts
describe('Share Recipe Flow', () => {
  it('user can share recipe with another user', async () => {
    // User A creates recipe
    // User A shares with User B
    // User B receives notification
    // User B views shared recipe
    // User B saves to collection
    // Verify lineage shows User A as origin
  });
});

// tests/e2e/auth/authentication.e2e.ts
describe('Authentication Flow', () => {
  it('new user can sign up', async () => {});
  it('existing user can log in', async () => {});
  it('user can reset password', async () => {});
  it('user session persists across app restart', async () => {});
});
```

---

## Phase 5: CI/CD & Documentation

### 5.1 CI Pipeline Configuration

```yaml
# .github/workflows/test.yml
name: Test Suite

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run test:unit -- --coverage
      - uses: codecov/codecov-action@v4

  integration-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: heirloom_test
        ports:
          - 5432:5432
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npm run test:integration
        env:
          DATABASE_URL: postgresql://postgres:test@localhost:5432/heirloom_test

  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npm run test:e2e
```

### 5.2 Package.json Scripts

```json
{
  "scripts": {
    "test": "vitest run",
    "test:unit": "vitest run --project unit",
    "test:integration": "vitest run --project integration",
    "test:e2e": "playwright test",
    "test:watch": "vitest --watch",
    "test:ui": "vitest --ui",
    "test:coverage": "vitest run --coverage",
    "test:ci": "vitest run --coverage --reporter=junit --outputFile=test-results.xml",
    "test:scaling": "vitest run tests/unit/scaling",
    "test:sharing": "vitest run tests/unit/sharing tests/integration/sharing",
    "test:import": "vitest run tests/unit/import tests/integration/import"
  }
}
```

### 5.3 Documentation

Create `tests/README.md`:

```markdown
# Heirloom Test Suite

## Quick Start
npm run test          # Run all tests
npm run test:watch    # Watch mode for development
npm run test:coverage # Generate coverage report

## Test Structure
- `unit/` - Fast, isolated tests for pure functions
- `integration/` - Tests crossing service boundaries
- `e2e/` - Full user flow tests
- `fixtures/` - Static test data
- `mocks/` - Mock implementations
- `helpers/` - Shared utilities

## Writing New Tests

### Factories
Use factories for test data:
const recipe = createRecipe({ servings: 4 });
const user = createUser({ email: 'test@example.com' });

### Database Tests
Always use transaction wrapper:
await withTestTransaction(async () => {
  // Your test here - auto-rollback
});

### Mocking External Services
Import handlers from `/mocks/handlers.ts`
```

---

## Deliverables Checklist

- [ ] Tech stack analysis document
- [ ] Test architecture diagram
- [ ] Configured test frameworks (Vitest/pytest + Playwright/Detox)
- [ ] Test database setup with migrations
- [ ] Factory functions for all models (Recipe, User, Ingredient, Collection, Share)
- [ ] MSW/mock handlers for AI import service
- [ ] Unit tests for recipe scaling (all edge cases)
- [ ] Unit tests for lineage/attribution logic
- [ ] Unit tests for import parsers
- [ ] Integration tests for all API endpoints
- [ ] Integration tests for share flow
- [ ] Integration tests for import pipeline
- [ ] E2E tests for recipe CRUD
- [ ] E2E tests for sharing flow
- [ ] E2E tests for authentication
- [ ] Database constraint and migration tests
- [ ] GitHub Actions CI configuration
- [ ] Coverage report with baseline (target: 80%+ for core modules)
- [ ] Test documentation

---

## Execution Instructions

1. **Start with Phase 1** using `ultrathink` - thorough analysis is critical
2. **Commit after each major milestone** for easy rollback
3. **Run tests frequently** during implementation
4. **Prioritize scaling tests** - this is a key differentiator feature
5. **Get unit tests green before integration tests**
6. **E2E tests last** - they're slowest and most brittle

Begin by exploring the codebase structure and reporting your findings before writing any test code.
