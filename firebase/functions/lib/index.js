"use strict";
/**
 * Firebase Cloud Functions - API Gateway
 * Secure proxy for all external API requests
 *
 * Setup:
 * 1. cd functions
 * 2. npm install
 * 3. firebase functions:config:set \
 *      anthropic.key="sk-ant-..." \
 *      openai.key="sk-proj-..." \
 *      google.vision_key="..." \
 *      brave.search_key="..."
 * 4. firebase deploy --only functions
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getUserUsageStats = exports.checkUserRateLimit = exports.dalleGenerateImage = exports.braveSearch = exports.googleVisionOCR = exports.aiCompleteWithVision = exports.aiCompleteStructured = exports.aiComplete = void 0;
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
// Export AI gateway functions
var ai_gateway_1 = require("./ai-gateway");
Object.defineProperty(exports, "aiComplete", { enumerable: true, get: function () { return ai_gateway_1.aiComplete; } });
Object.defineProperty(exports, "aiCompleteStructured", { enumerable: true, get: function () { return ai_gateway_1.aiCompleteStructured; } });
Object.defineProperty(exports, "aiCompleteWithVision", { enumerable: true, get: function () { return ai_gateway_1.aiCompleteWithVision; } });
// Export Google Vision functions
var google_vision_1 = require("./google-vision");
Object.defineProperty(exports, "googleVisionOCR", { enumerable: true, get: function () { return google_vision_1.googleVisionOCR; } });
// Export Brave Search functions
var brave_search_1 = require("./brave-search");
Object.defineProperty(exports, "braveSearch", { enumerable: true, get: function () { return brave_search_1.braveSearch; } });
// Export DALL-E image generation
var dalle_image_1 = require("./dalle-image");
Object.defineProperty(exports, "dalleGenerateImage", { enumerable: true, get: function () { return dalle_image_1.dalleGenerateImage; } });
// Export utility functions
var rate_limiter_1 = require("./rate-limiter");
Object.defineProperty(exports, "checkUserRateLimit", { enumerable: true, get: function () { return rate_limiter_1.checkUserRateLimit; } });
Object.defineProperty(exports, "getUserUsageStats", { enumerable: true, get: function () { return rate_limiter_1.getUserUsageStats; } });
//# sourceMappingURL=index.js.map