"use strict";
/**
 * AI Gateway - Secure proxy for AI service requests
 * All API keys stay server-side, clients use Firebase Auth tokens
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.aiCompleteWithVision = exports.aiCompleteStructured = exports.aiComplete = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const params_1 = require("firebase-functions/params");
const sdk_1 = __importDefault(require("@anthropic-ai/sdk"));
const openai_1 = __importDefault(require("openai"));
const rate_limiter_1 = require("./rate-limiter");
// Define secrets for API keys (stored in Google Secret Manager)
const anthropicKey = (0, params_1.defineSecret)('ANTHROPIC_API_KEY');
const openaiKey = (0, params_1.defineSecret)('OPENAI_API_KEY');
// Initialize AI clients with server-side API keys
const getAnthropicClient = () => new sdk_1.default({
    apiKey: anthropicKey.value(),
});
const getOpenAIClient = () => new openai_1.default({
    apiKey: openaiKey.value(),
});
// MARK: - Text Completion
/**
 * Complete a text prompt with AI
 * Maps to: AIServiceProtocol.complete(prompt:options:)
 */
exports.aiComplete = (0, https_1.onCall)({ secrets: [anthropicKey, openaiKey] }, async (request) => {
    // 1. Verify authentication
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Must be logged in');
    }
    const userId = request.auth.uid;
    const { prompt, provider, model, temperature, maxTokens, systemMessage } = request.data;
    try {
        // 2. Rate limiting check
        try {
            await (0, rate_limiter_1.checkRateLimit)(userId, 'ai_complete');
        }
        catch (rateLimitError) {
            firebase_functions_1.logger.error('Rate limit check failed', { userId, operation: 'ai_complete', error: rateLimitError.message, stack: rateLimitError.stack });
            throw rateLimitError;
        }
        // 3. Validate input
        if (!prompt || typeof prompt !== 'string') {
            throw new https_1.HttpsError('invalid-argument', 'Invalid prompt');
        }
        if (!provider || !['anthropic', 'openai'].includes(provider)) {
            throw new https_1.HttpsError('invalid-argument', 'Invalid provider');
        }
        // 4. Call appropriate AI service
        let response;
        if (provider === 'anthropic') {
            const anthropic = getAnthropicClient();
            response = await completeWithAnthropic(anthropic, prompt, {
                model: model || 'claude-3-haiku-20240307',
                temperature: temperature || 0.7,
                maxTokens: maxTokens || 1024,
                systemMessage,
            });
        }
        else {
            const openai = getOpenAIClient();
            response = await completeWithOpenAI(openai, prompt, {
                model: model || 'gpt-4o-mini',
                temperature: temperature || 0.7,
                maxTokens: maxTokens || 1024,
                systemMessage,
            });
        }
        // 5. Log usage for billing/analytics
        try {
            await (0, rate_limiter_1.logAIUsage)(userId, 'ai_complete', {
                provider,
                model: response.model,
                inputTokens: response.usage.input_tokens,
                outputTokens: response.usage.output_tokens,
                totalTokens: response.usage.total_tokens,
            });
        }
        catch (logError) {
            // Don't fail the request if logging fails
            firebase_functions_1.logger.error('AI usage logging failed', { userId, operation: 'ai_complete', error: logError.message });
        }
        // 6. Return response
        return {
            content: response.content,
            model: response.model,
            usage: response.usage,
            metadata: response.metadata,
        };
    }
    catch (error) {
        firebase_functions_1.logger.error('AI Complete Error', { userId, error: error.message });
        // Handle specific errors
        if (error.status === 429) {
            throw new https_1.HttpsError('resource-exhausted', 'AI service rate limit exceeded');
        }
        if (error.status === 401) {
            throw new https_1.HttpsError('internal', 'AI service authentication failed');
        }
        throw new https_1.HttpsError('internal', 'Failed to complete AI request');
    }
});
// MARK: - Structured Completion
/**
 * Complete with structured JSON output
 * Maps to: AIServiceProtocol.completeStructured(prompt:schema:options:)
 */
exports.aiCompleteStructured = (0, https_1.onCall)({ secrets: [anthropicKey, openaiKey] }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Must be logged in');
    }
    const userId = request.auth.uid;
    const { prompt, provider, model, temperature, maxTokens, systemMessage } = request.data;
    try {
        try {
            await (0, rate_limiter_1.checkRateLimit)(userId, 'ai_complete');
        }
        catch (rateLimitError) {
            firebase_functions_1.logger.error('Rate limit check failed (structured)', { userId, operation: 'ai_complete', error: rateLimitError.message, stack: rateLimitError.stack });
            throw rateLimitError;
        }
        if (!prompt || typeof prompt !== 'string') {
            throw new https_1.HttpsError('invalid-argument', 'Invalid prompt');
        }
        // Add JSON formatting instructions with explicit schema requirements
        const structuredPrompt = `${prompt}\n\nCRITICAL REQUIREMENTS:
1. Respond with ONLY valid, parseable JSON
2. Do NOT wrap in markdown code blocks
3. Do NOT include any explanatory text before or after the JSON
4. Ensure all strings are properly escaped
5. Ensure all brackets and braces are balanced
6. Do NOT use trailing commas
7. Use null for missing values, not undefined

Your response must be parseable by JSON.parse() without any modifications.`;
        // Call AI service
        let response;
        if (provider === 'anthropic') {
            const anthropic = getAnthropicClient();
            response = await completeWithAnthropic(anthropic, structuredPrompt, {
                model: model || 'claude-haiku-4-5-20251001',
                temperature: temperature || 0.3,
                maxTokens: maxTokens || 1024,
                systemMessage,
            });
        }
        else {
            const openai = getOpenAIClient();
            response = await completeWithOpenAI(openai, structuredPrompt, {
                model: model || 'gpt-4o-mini',
                temperature: temperature || 0.3,
                maxTokens: maxTokens || 1024,
                systemMessage,
            });
        }
        // Clean JSON from markdown if present
        let cleanedJSON = cleanJSONFromMarkdown(response.content);
        // VALIDATE JSON on server before sending to client
        try {
            JSON.parse(cleanedJSON);
            firebase_functions_1.logger.info('JSON validation successful', { userId, jsonLength: cleanedJSON.length });
        }
        catch (parseError) {
            firebase_functions_1.logger.warn('Invalid JSON from AI, retrying with lower temperature', {
                userId,
                provider,
                model: response.model,
                error: parseError.message,
                rawContent: response.content.substring(0, 500),
            });
            // Retry once with lower temperature for more deterministic output
            try {
                const retryTemp = Math.min(temperature || 0.3, 0.2);
                let retryResponse;
                if (provider === 'anthropic') {
                    const anthropic = getAnthropicClient();
                    retryResponse = await completeWithAnthropic(anthropic, structuredPrompt, {
                        model: model || 'claude-haiku-4-5-20251001',
                        temperature: retryTemp,
                        maxTokens: maxTokens || 1024,
                        systemMessage,
                    });
                }
                else {
                    const openai = getOpenAIClient();
                    retryResponse = await completeWithOpenAI(openai, structuredPrompt, {
                        model: model || 'gpt-4o-mini',
                        temperature: retryTemp,
                        maxTokens: maxTokens || 1024,
                        systemMessage,
                    });
                }
                cleanedJSON = cleanJSONFromMarkdown(retryResponse.content);
                JSON.parse(cleanedJSON); // Validate retry result
                response = retryResponse;
                firebase_functions_1.logger.info('JSON retry successful', { userId, jsonLength: cleanedJSON.length });
            }
            catch (retryError) {
                firebase_functions_1.logger.error('Invalid JSON from AI after retry', {
                    userId,
                    provider,
                    model: response.model,
                    error: retryError.message,
                    rawContent: response.content.substring(0, 500),
                    cleanedContent: cleanedJSON.substring(0, 500),
                });
                throw new https_1.HttpsError('invalid-argument', 'The AI returned invalid data. Please try again. If this persists, try simplifying your request.', {
                    technicalDetails: retryError.message,
                    hint: 'JSON parsing failed after retry',
                });
            }
        }
        // Log usage
        try {
            await (0, rate_limiter_1.logAIUsage)(userId, 'ai_complete_structured', {
                provider,
                model: response.model,
                inputTokens: response.usage.input_tokens,
                outputTokens: response.usage.output_tokens,
                totalTokens: response.usage.total_tokens,
            });
        }
        catch (logError) {
            // Don't fail the request if logging fails
            firebase_functions_1.logger.error('AI usage logging failed (structured)', { userId, operation: 'ai_complete_structured', error: logError.message });
        }
        return {
            content: cleanedJSON,
            model: response.model,
            usage: response.usage,
        };
    }
    catch (error) {
        // Pass through user-friendly errors
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        // Log unexpected errors
        firebase_functions_1.logger.error('AI Complete Structured Error', { userId, error: error.message, stack: error.stack });
        throw new https_1.HttpsError('internal', 'Something went wrong while processing your request. Please try again.', { technicalDetails: error.message });
    }
});
// MARK: - Vision Completion
/**
 * Complete with vision (image + text prompt)
 * Maps to: AIServiceProtocol.completeWithVisionStructured(image:prompt:schema:options:)
 */
exports.aiCompleteWithVision = (0, https_1.onCall)({
    memory: '1GiB',
    timeoutSeconds: 120,
    secrets: [anthropicKey, openaiKey],
}, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Must be logged in');
    }
    const userId = request.auth.uid;
    const { imageBase64, prompt, provider, model, temperature, maxTokens, systemMessage, structured } = request.data;
    try {
        try {
            await (0, rate_limiter_1.checkRateLimit)(userId, 'ai_vision');
        }
        catch (rateLimitError) {
            firebase_functions_1.logger.error('Rate limit check failed (vision)', { userId, operation: 'ai_vision', error: rateLimitError.message, stack: rateLimitError.stack });
            throw rateLimitError;
        }
        if (!imageBase64 || typeof imageBase64 !== 'string') {
            throw new https_1.HttpsError('invalid-argument', 'Invalid image data');
        }
        if (!prompt || typeof prompt !== 'string') {
            throw new https_1.HttpsError('invalid-argument', 'Invalid prompt');
        }
        // Add structured formatting if requested with explicit requirements
        const finalPrompt = structured
            ? `${prompt}\n\nCRITICAL REQUIREMENTS:
1. Respond with ONLY valid, parseable JSON
2. Do NOT wrap in markdown code blocks
3. Do NOT include any explanatory text before or after the JSON
4. Ensure all strings are properly escaped
5. Ensure all brackets and braces are balanced
6. Do NOT use trailing commas
7. Use null for missing values, not undefined

Your response must be parseable by JSON.parse() without any modifications.`
            : prompt;
        // Call AI service with vision
        let response;
        if (provider === 'anthropic') {
            const anthropic = getAnthropicClient();
            response = await completeWithAnthropicVision(anthropic, imageBase64, finalPrompt, {
                model: model || 'claude-sonnet-4-5-20250929',
                temperature: structured ? 0.3 : (temperature || 0.7),
                maxTokens: maxTokens || 1500,
                systemMessage,
            });
        }
        else {
            const openai = getOpenAIClient();
            response = await completeWithOpenAIVision(openai, imageBase64, finalPrompt, {
                model: model || 'gpt-4o',
                temperature: structured ? 0.3 : (temperature || 0.7),
                maxTokens: maxTokens || 1500,
            });
        }
        // Clean JSON if structured and validate
        let content = structured ? cleanJSONFromMarkdown(response.content) : response.content;
        if (structured) {
            try {
                JSON.parse(content);
                firebase_functions_1.logger.info('Vision JSON validation successful', { userId, jsonLength: content.length });
            }
            catch (parseError) {
                firebase_functions_1.logger.error('Invalid JSON from vision AI', {
                    userId,
                    provider,
                    model: response.model,
                    error: parseError.message,
                    rawContent: response.content.substring(0, 500),
                    cleanedContent: content.substring(0, 500),
                });
                throw new https_1.HttpsError('invalid-argument', 'Unable to extract valid data from the image. Please try again with a clearer image or simpler content.', {
                    technicalDetails: parseError.message,
                    hint: 'JSON parsing failed',
                });
            }
        }
        // Log usage
        try {
            await (0, rate_limiter_1.logAIUsage)(userId, 'ai_vision', {
                provider,
                model: response.model,
                inputTokens: response.usage.input_tokens,
                outputTokens: response.usage.output_tokens,
                totalTokens: response.usage.total_tokens,
            });
        }
        catch (logError) {
            // Don't fail the request if logging fails
            firebase_functions_1.logger.error('AI usage logging failed (vision)', { userId, operation: 'ai_vision', error: logError.message });
        }
        return {
            content,
            model: response.model,
            usage: response.usage,
        };
    }
    catch (error) {
        // Pass through user-friendly errors
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        firebase_functions_1.logger.error('AI Vision Error', { userId, error: error.message, stack: error.stack });
        throw new https_1.HttpsError('internal', 'Something went wrong while analyzing the image. Please try again.', { technicalDetails: error.message });
    }
});
// MARK: - Helper Functions
async function completeWithAnthropic(anthropic, prompt, options) {
    const requestParams = {
        model: options.model,
        max_tokens: options.maxTokens,
        temperature: options.temperature,
        messages: [{ role: 'user', content: prompt }],
    };
    // Only include system if provided (not null, not undefined, not empty)
    if (options.systemMessage && options.systemMessage.trim().length > 0) {
        requestParams.system = options.systemMessage;
    }
    const response = await anthropic.messages.create(requestParams);
    const content = response.content[0].type === 'text' ? response.content[0].text : '';
    return {
        content,
        model: response.model,
        usage: {
            input_tokens: response.usage.input_tokens,
            output_tokens: response.usage.output_tokens,
            total_tokens: response.usage.input_tokens + response.usage.output_tokens,
        },
        metadata: {
            stop_reason: response.stop_reason,
            id: response.id,
        },
    };
}
async function completeWithOpenAI(openai, prompt, options) {
    var _a, _b, _c;
    const messages = [];
    if (options.systemMessage) {
        messages.push({ role: 'system', content: options.systemMessage });
    }
    messages.push({ role: 'user', content: prompt });
    const response = await openai.chat.completions.create({
        model: options.model,
        messages,
        temperature: options.temperature,
        max_tokens: options.maxTokens,
    });
    const content = response.choices[0].message.content || '';
    return {
        content,
        model: response.model,
        usage: {
            input_tokens: ((_a = response.usage) === null || _a === void 0 ? void 0 : _a.prompt_tokens) || 0,
            output_tokens: ((_b = response.usage) === null || _b === void 0 ? void 0 : _b.completion_tokens) || 0,
            total_tokens: ((_c = response.usage) === null || _c === void 0 ? void 0 : _c.total_tokens) || 0,
        },
        metadata: {
            finish_reason: response.choices[0].finish_reason,
            id: response.id,
        },
    };
}
async function completeWithAnthropicVision(anthropic, imageBase64, prompt, options) {
    const requestParams = {
        model: options.model,
        max_tokens: options.maxTokens,
        temperature: options.temperature,
        messages: [
            {
                role: 'user',
                content: [
                    {
                        type: 'image',
                        source: {
                            type: 'base64',
                            media_type: 'image/jpeg',
                            data: imageBase64,
                        },
                    },
                    {
                        type: 'text',
                        text: prompt,
                    },
                ],
            },
        ],
    };
    // Only include system if provided (not null, not undefined, not empty)
    if (options.systemMessage && options.systemMessage.trim().length > 0) {
        requestParams.system = options.systemMessage;
    }
    const response = await anthropic.messages.create(requestParams);
    const content = response.content[0].type === 'text' ? response.content[0].text : '';
    return {
        content,
        model: response.model,
        usage: {
            input_tokens: response.usage.input_tokens,
            output_tokens: response.usage.output_tokens,
            total_tokens: response.usage.input_tokens + response.usage.output_tokens,
        },
        metadata: {
            stop_reason: response.stop_reason,
            id: response.id,
        },
    };
}
async function completeWithOpenAIVision(openai, imageBase64, prompt, options) {
    var _a, _b, _c;
    const response = await openai.chat.completions.create({
        model: options.model,
        messages: [
            {
                role: 'user',
                content: [
                    {
                        type: 'image_url',
                        image_url: {
                            url: `data:image/jpeg;base64,${imageBase64}`,
                        },
                    },
                    {
                        type: 'text',
                        text: prompt,
                    },
                ],
            },
        ],
        temperature: options.temperature,
        max_tokens: options.maxTokens,
    });
    const content = response.choices[0].message.content || '';
    return {
        content,
        model: response.model,
        usage: {
            input_tokens: ((_a = response.usage) === null || _a === void 0 ? void 0 : _a.prompt_tokens) || 0,
            output_tokens: ((_b = response.usage) === null || _b === void 0 ? void 0 : _b.completion_tokens) || 0,
            total_tokens: ((_c = response.usage) === null || _c === void 0 ? void 0 : _c.total_tokens) || 0,
        },
        metadata: {
            finish_reason: response.choices[0].finish_reason,
            id: response.id,
        },
    };
}
function cleanJSONFromMarkdown(text) {
    let cleaned = text.trim();
    // Remove markdown code block wrapper if present
    if (cleaned.startsWith('```')) {
        const firstNewline = cleaned.indexOf('\n');
        if (firstNewline !== -1) {
            cleaned = cleaned.substring(firstNewline + 1);
        }
        if (cleaned.endsWith('```')) {
            cleaned = cleaned.substring(0, cleaned.length - 3);
        }
        cleaned = cleaned.trim();
    }
    return cleaned;
}
//# sourceMappingURL=ai-gateway.js.map