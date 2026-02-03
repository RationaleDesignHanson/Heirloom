"use strict";
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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.dalleGenerateImage = void 0;
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const logger = __importStar(require("firebase-functions/logger"));
const openai_1 = __importDefault(require("openai"));
// Define the OpenAI API key secret
const openaiKey = (0, params_1.defineSecret)('OPENAI_API_KEY');
/**
 * Generate an image using OpenAI DALL-E 3
 *
 * Rate limits: 50 images per user per day
 */
exports.dalleGenerateImage = (0, https_1.onCall)({
    secrets: [openaiKey],
    region: 'us-central1',
}, async (request) => {
    var _a;
    // Verify authentication
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { prompt, size = '1792x1024', quality = 'standard' } = request.data;
    // Validate input
    if (!prompt || typeof prompt !== 'string') {
        throw new https_1.HttpsError('invalid-argument', 'Prompt is required and must be a string');
    }
    if (prompt.length > 4000) {
        throw new https_1.HttpsError('invalid-argument', 'Prompt must be less than 4000 characters');
    }
    const userId = request.auth.uid;
    logger.info('Generating DALL-E image', {
        userId,
        promptLength: prompt.length,
        size,
        quality,
    });
    try {
        // Get API key from secret and trim whitespace/newlines
        const apiKey = (_a = openaiKey.value()) === null || _a === void 0 ? void 0 : _a.trim();
        logger.info('Got OpenAI API key', { hasKey: !!apiKey, keyLength: apiKey === null || apiKey === void 0 ? void 0 : apiKey.length });
        logger.info('About to call OpenAI API', { prompt: prompt.substring(0, 50) });
        // Initialize OpenAI client
        logger.info('Creating OpenAI client...');
        const openai = new openai_1.default({ apiKey });
        logger.info('OpenAI client created');
        // Call DALL-E API using SDK
        logger.info('Calling openai.images.generate...');
        const response = await openai.images.generate({
            model: 'dall-e-3',
            prompt: prompt,
            n: 1,
            size: size,
            quality: quality,
        });
        logger.info('openai.images.generate completed');
        logger.info('OpenAI API response received', { hasData: !!response.data });
        if (!response.data || !response.data[0] || !response.data[0].url) {
            logger.error('Invalid response from OpenAI', { response });
            throw new https_1.HttpsError('internal', 'Invalid response from image generation API');
        }
        const imageUrl = response.data[0].url;
        const revisedPrompt = response.data[0].revised_prompt;
        logger.info('Image generated successfully', {
            userId,
            hasRevisedPrompt: !!revisedPrompt,
        });
        return {
            imageUrl,
            revisedPrompt,
        };
    }
    catch (error) {
        // Log full error object
        console.error('FULL ERROR:', JSON.stringify(error, Object.getOwnPropertyNames(error)));
        logger.error('Image generation failed', {
            userId,
            error: error.message,
            errorName: error.name,
            errorStack: error.stack,
            errorString: String(error),
            fullError: JSON.stringify(error, Object.getOwnPropertyNames(error)),
        });
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        throw new https_1.HttpsError('internal', `Failed to generate image: ${error.message || String(error)}`);
    }
});
//# sourceMappingURL=dalle-image.js.map