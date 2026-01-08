/**
 * Type definitions for Heirloom recipe import system
 */

// Import request from iOS app
export interface ImportRequest {
  url: string;
  userId?: string; // Optional for anonymous imports
}

// Import status
export type ImportStatus = 'success' | 'partial' | 'failed';

// Parser types
export type ParserType = 'schemaOrg' | 'heuristic' | 'none';

// Extracted recipe data
export interface ExtractedRecipe {
  title: string;
  ingredients: string[];
  instructions: string[];
  servings?: string;
  prepTime?: string;
  cookTime?: string;
  totalTime?: string;
  imageUrl?: string;
  rating?: number;
  ratingCount?: number;
  description?: string;
  author?: string;
  category?: string;
  cuisine?: string;
  keywords?: string[];
  nutrition?: NutritionInfo;
}

export interface NutritionInfo {
  calories?: string;
  protein?: string;
  carbohydrates?: string;
  fat?: string;
  fiber?: string;
  sugar?: string;
  sodium?: string;
}

// Import response sent back to iOS
export interface ImportResponse {
  status: ImportStatus;
  importId: string; // Firestore document ID for tracking
  confidence: number; // 0-1 score
  recipe?: ExtractedRecipe;
  warnings?: string[];
  errors?: ImportError[];
  metadata: ImportMetadata;
}

export interface ImportMetadata {
  parserUsed: ParserType;
  parseTimeMs: number;
  hasSchemaOrg: boolean;
  needsFeedback: boolean; // Prompt user for review
  domain: string;
  sourceUrl: string; // Original URL for attribution/linking back
  timestamp: Date;
}

export interface ImportError {
  type: 'network' | 'parsing' | 'validation' | 'timeout' | 'unsupported';
  message: string;
  field?: string; // Which field failed
  details?: any;
}

// Stored in Firestore: import_attempts collection
export interface ImportAttempt {
  id: string;
  url: string;
  domain: string;
  timestamp: Date;
  userId?: string;
  status: ImportStatus;
  extracted: Partial<ExtractedRecipe>;
  parserUsed: ParserType;
  confidence: number;
  rawHTML?: string; // For retraining (only store for failed/low confidence)
  htmlStructure: HtmlStructure;
  errors?: ImportError[];
  userFeedback?: UserFeedback;
  parseTimeMs: number;
}

export interface HtmlStructure {
  hasSchemaOrg: boolean;
  hasRecipeCard: boolean;
  dominantTags: string[];
  headingCount: number;
  listCount: number;
  imageCount: number;
}

export interface UserFeedback {
  wasAccurate: boolean;
  corrections?: {
    field: string;
    correctValue: string;
  }[];
  timestamp: Date;
  rating?: number; // 1-5 stars
  comment?: string;
}

// Stored in Firestore: site_patterns collection
export interface SitePattern {
  domain: string;
  successRate: number;
  totalAttempts: number;
  successfulAttempts: number;
  lastSuccessful?: Date;
  lastFailed?: Date;
  bestParser: ParserType;
  commonIssues: string[];
  htmlPatterns?: {
    ingredientSelectors?: string[];
    instructionSelectors?: string[];
    titleSelectors?: string[];
  };
  updatedAt: Date;
}

// Stored in Firestore: training_queue collection
export interface TrainingQueueItem {
  url: string;
  domain: string;
  priority: number; // Higher = more important
  attemptCount: number;
  lastAttempted: Date;
  status: 'pending' | 'reviewed' | 'training';
  extractedData?: Partial<ExtractedRecipe>;
  groundTruth?: ExtractedRecipe; // Human-labeled correct data
  createdAt: Date;
  reviewedAt?: Date;
  reviewedBy?: string;
}

// Parser result internal type
export interface ParserResult {
  success: boolean;
  recipe?: ExtractedRecipe;
  confidence: number;
  errors?: ImportError[];
  parserUsed: ParserType;
}

// Schema.org Recipe type (from JSON-LD)
export interface SchemaOrgRecipe {
  '@type'?: string;
  name?: string;
  description?: string;
  image?: string | string[] | { url: string }[];
  recipeIngredient?: string[];
  recipeInstructions?: string | string[] | HowToStep[];
  recipeYield?: string | number | string[] | number[];
  prepTime?: string;
  cookTime?: string;
  totalTime?: string;
  aggregateRating?: {
    ratingValue: number;
    ratingCount?: number;
  };
  author?: string | { name: string };
  recipeCategory?: string | string[];
  recipeCuisine?: string | string[];
  keywords?: string | string[];
  nutrition?: {
    calories?: string;
    proteinContent?: string;
    carbohydrateContent?: string;
    fatContent?: string;
    fiberContent?: string;
    sugarContent?: string;
    sodiumContent?: string;
  };
}

export interface HowToStep {
  '@type': 'HowToStep';
  text?: string;
  name?: string;
}

// Feedback submission from iOS
export interface FeedbackRequest {
  importId: string;
  userId?: string;
  wasAccurate: boolean;
  corrections?: {
    field: string;
    correctValue: string;
  }[];
  rating?: number;
  comment?: string;
}

export interface FeedbackResponse {
  success: boolean;
  message: string;
}

// ===== URL Shortening Types =====

// Request to shorten a URL
export interface ShortenURLRequest {
  url: string; // CloudKit share URL to shorten
  customCode?: string; // Optional custom short code
  recipeId?: string; // For analytics tracking
  userId?: string; // For ownership tracking
}

// Response from shortenURL endpoint
export interface ShortenURLResponse {
  success: boolean;
  shortUrl: string; // Full short URL (https://heirloom.app/r/abc123)
  code: string; // Just the code part (abc123)
  longUrl: string; // Original URL
  expiresAt?: Date; // Optional expiration
  error?: string; // Error message if success = false
}

// Stored in Firestore: short_urls collection
export interface ShortURL {
  code: string; // Primary key / document ID
  longUrl: string; // Original CloudKit URL
  recipeId?: string;
  userId?: string;
  createdAt: Date;
  expiresAt?: Date;
  clicks: number;
  lastAccessed?: Date;
  // Analytics
  clicksByDay?: Record<string, number>; // { "2024-12-26": 5, ... }
  referrers?: Record<string, number>; // { "twitter.com": 3, ... }
}

// Click tracking event
export interface URLClickEvent {
  code: string;
  timestamp: Date;
  userAgent?: string;
  referrer?: string;
  ipHash?: string; // Hashed for privacy
}

// ===== Language Detection & Translation Types =====

// Request to detect language of recipe text
export interface DetectLanguageRequest {
  text: string; // Recipe text to analyze (title + ingredients + instructions)
  hints?: {
    url?: string; // Source URL for additional context
    domain?: string; // Domain for regional hints
  };
}

// Response from detectLanguage endpoint
export interface DetectLanguageResponse {
  language: string; // ISO 639-1 code (e.g., 'en', 'fr', 'ja')
  confidence: number; // 0-1 confidence score
  languageName: string; // Human-readable name (e.g., 'English', 'French')
  detectedUnitSystem?: 'metric' | 'imperial' | 'mixed'; // Unit system hint
  needsTranslation: boolean; // True if not English
}

// Request to translate recipe text
export interface TranslateTextRequest {
  text: string; // Text to translate
  sourceLanguage: string; // ISO 639-1 source language code
  targetLanguage?: string; // Target language (defaults to 'en')
  context?: 'title' | 'ingredient' | 'instruction' | 'note'; // Type of text for better translation
}

// Response from translateText endpoint
export interface TranslateTextResponse {
  translatedText: string;
  sourceLanguage: string;
  targetLanguage: string;
  confidence: number; // Translation confidence 0-1
  engine: 'claude' | 'fallback'; // Which translation engine was used
}
