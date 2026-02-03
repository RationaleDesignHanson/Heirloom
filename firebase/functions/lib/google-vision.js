"use strict";
/**
 * Google Vision API Gateway
 * Secure proxy for handwriting OCR requests
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.googleVisionOCR = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const rate_limiter_1 = require("./rate-limiter");
/**
 * Google Vision OCR for handwritten recipes
 * Maps to: GoogleVisionService in iOS app
 */
exports.googleVisionOCR = (0, https_1.onCall)(async (request) => {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    // 1. Verify authentication
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Must be logged in');
    }
    const userId = request.auth.uid;
    const { imageBase64 } = request.data;
    try {
        // 2. Rate limiting check
        await (0, rate_limiter_1.checkRateLimit)(userId, 'google_vision');
        // 3. Validate input
        if (!imageBase64 || typeof imageBase64 !== 'string') {
            throw new https_1.HttpsError('invalid-argument', 'Invalid image data');
        }
        // 4. Get API key
        const apiKey = process.env.GOOGLE_VISION_KEY;
        if (!apiKey) {
            throw new https_1.HttpsError('failed-precondition', 'Google Vision API not configured');
        }
        // 5. Call Google Vision API
        const response = await fetch(`https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                requests: [
                    {
                        image: {
                            content: imageBase64,
                        },
                        features: [
                            {
                                type: 'DOCUMENT_TEXT_DETECTION',
                                maxResults: 1,
                            },
                        ],
                        imageContext: {
                            languageHints: ['en'],
                        },
                    },
                ],
            }),
        });
        if (!response.ok) {
            const errorText = await response.text();
            firebase_functions_1.logger.error('Google Vision API Error', { status: response.status, error: errorText });
            throw new https_1.HttpsError('internal', 'Google Vision API request failed');
        }
        const result = await response.json();
        // 6. Extract text
        const textAnnotations = (_b = (_a = result.responses) === null || _a === void 0 ? void 0 : _a[0]) === null || _b === void 0 ? void 0 : _b.textAnnotations;
        const fullText = ((_c = textAnnotations === null || textAnnotations === void 0 ? void 0 : textAnnotations[0]) === null || _c === void 0 ? void 0 : _c.description) || '';
        // 7. Log usage (estimate cost - $1.50 per 1000 images)
        await (0, rate_limiter_1.logAIUsage)(userId, 'google_vision_ocr', {
            provider: 'google',
            model: 'vision-api-v1',
            inputTokens: 0,
            outputTokens: 0,
            totalTokens: 0,
        });
        return {
            text: fullText,
            confidence: ((_d = textAnnotations === null || textAnnotations === void 0 ? void 0 : textAnnotations[0]) === null || _d === void 0 ? void 0 : _d.confidence) || 0,
            locale: (_h = (_g = (_f = (_e = result.responses) === null || _e === void 0 ? void 0 : _e[0]) === null || _f === void 0 ? void 0 : _f.textAnnotations) === null || _g === void 0 ? void 0 : _g[0]) === null || _h === void 0 ? void 0 : _h.locale,
        };
    }
    catch (error) {
        firebase_functions_1.logger.error('Google Vision OCR Error', { userId, error: error.message });
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        throw new https_1.HttpsError('internal', 'Failed to process OCR request');
    }
});
//# sourceMappingURL=google-vision.js.map