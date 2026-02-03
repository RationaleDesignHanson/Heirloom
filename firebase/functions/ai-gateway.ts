/**
 * AI Gateway - Secure proxy for AI service requests
 * All API keys stay server-side, clients use Firebase Auth tokens
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';
import Anthropic from '@anthropic-ai/sdk';
import OpenAI from 'openai';
import { checkRateLimit, logAIUsage } from './rate-limiter';

// Define secrets for API keys (stored in Google Secret Manager)
const anthropicKey = defineSecret('ANTHROPIC_API_KEY');
const openaiKey = defineSecret('OPENAI_API_KEY');

// Initialize AI clients with server-side API keys
const getAnthropicClient = () => new Anthropic({
  apiKey: anthropicKey.value(),
});

const getOpenAIClient = () => new OpenAI({
  apiKey: openaiKey.value(),
});

// MARK: - Text Completion

/**
 * Complete a text prompt with AI
 * Maps to: AIServiceProtocol.complete(prompt:options:)
 */
export const aiComplete = onCall({ secrets: [anthropicKey, openaiKey] }, async (request) => {
  // 1. Verify authentication
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }

  const userId = request.auth.uid;
  const { prompt, provider, model, temperature, maxTokens, systemMessage } = request.data;

  try {
    // 2. Rate limiting check
    try {
      await checkRateLimit(userId, 'ai_complete');
    } catch (rateLimitError: any) {
      logger.error('Rate limit check failed', { userId, operation: 'ai_complete', error: rateLimitError.message, stack: rateLimitError.stack });
      throw rateLimitError;
    }

    // 3. Validate input
    if (!prompt || typeof prompt !== 'string') {
      throw new HttpsError('invalid-argument', 'Invalid prompt');
    }

    if (!provider || !['anthropic', 'openai'].includes(provider)) {
      throw new HttpsError('invalid-argument', 'Invalid provider');
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
    } else {
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
      await logAIUsage(userId, 'ai_complete', {
        provider,
        model: response.model,
        inputTokens: response.usage.input_tokens,
        outputTokens: response.usage.output_tokens,
        totalTokens: response.usage.total_tokens,
      });
    } catch (logError: any) {
      // Don't fail the request if logging fails
      logger.error('AI usage logging failed', { userId, operation: 'ai_complete', error: logError.message });
    }

    // 6. Return response
    return {
      content: response.content,
      model: response.model,
      usage: response.usage,
      metadata: response.metadata,
    };
  } catch (error: any) {
    logger.error('AI Complete Error', { userId, error: error.message });

    // Handle specific errors
    if (error.status === 429) {
      throw new HttpsError('resource-exhausted', 'AI service rate limit exceeded');
    }
    if (error.status === 401) {
      throw new HttpsError('internal', 'AI service authentication failed');
    }

    throw new HttpsError('internal', 'Failed to complete AI request');
  }
});

// MARK: - Structured Completion

/**
 * Complete with structured JSON output
 * Maps to: AIServiceProtocol.completeStructured(prompt:schema:options:)
 */
export const aiCompleteStructured = onCall({ secrets: [anthropicKey, openaiKey] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }

  const userId = request.auth.uid;
  const { prompt, provider, model, temperature, maxTokens, systemMessage } = request.data;

  try {
    try {
      await checkRateLimit(userId, 'ai_complete');
    } catch (rateLimitError: any) {
      logger.error('Rate limit check failed (structured)', { userId, operation: 'ai_complete', error: rateLimitError.message, stack: rateLimitError.stack });
      throw rateLimitError;
    }

    if (!prompt || typeof prompt !== 'string') {
      throw new HttpsError('invalid-argument', 'Invalid prompt');
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
        model: model || 'claude-3-haiku-20240307',
        temperature: temperature || 0.3, // Lower temperature for more consistent JSON
        maxTokens: maxTokens || 1024,
        systemMessage,
      });
    } else {
      const openai = getOpenAIClient();
      response = await completeWithOpenAI(openai, structuredPrompt, {
        model: model || 'gpt-4o-mini',
        temperature: temperature || 0.3, // Lower temperature for more consistent JSON
        maxTokens: maxTokens || 1024,
        systemMessage,
      });
    }

    // Clean JSON from markdown if present
    const cleanedJSON = cleanJSONFromMarkdown(response.content);

    // VALIDATE JSON on server before sending to client
    try {
      JSON.parse(cleanedJSON);
      logger.info('JSON validation successful', { userId, jsonLength: cleanedJSON.length });
    } catch (parseError: any) {
      logger.error('Invalid JSON from AI', {
        userId,
        provider,
        model: response.model,
        error: parseError.message,
        rawContent: response.content.substring(0, 500), // First 500 chars for debugging
        cleanedContent: cleanedJSON.substring(0, 500),
      });

      // Return user-friendly error message
      throw new HttpsError(
        'invalid-argument',
        'The AI returned invalid data. Please try again. If this persists, try simplifying your request.',
        {
          technicalDetails: parseError.message,
          hint: 'JSON parsing failed',
        }
      );
    }

    // Log usage
    try {
      await logAIUsage(userId, 'ai_complete_structured', {
        provider,
        model: response.model,
        inputTokens: response.usage.input_tokens,
        outputTokens: response.usage.output_tokens,
        totalTokens: response.usage.total_tokens,
      });
    } catch (logError: any) {
      // Don't fail the request if logging fails
      logger.error('AI usage logging failed (structured)', { userId, operation: 'ai_complete_structured', error: logError.message });
    }

    return {
      content: cleanedJSON,
      model: response.model,
      usage: response.usage,
    };
  } catch (error: any) {
    // Pass through user-friendly errors
    if (error instanceof HttpsError) {
      throw error;
    }

    // Log unexpected errors
    logger.error('AI Complete Structured Error', { userId, error: error.message, stack: error.stack });
    throw new HttpsError(
      'internal',
      'Something went wrong while processing your request. Please try again.',
      { technicalDetails: error.message }
    );
  }
});

// MARK: - Vision Completion

/**
 * Complete with vision (image + text prompt)
 * Maps to: AIServiceProtocol.completeWithVisionStructured(image:prompt:schema:options:)
 */
export const aiCompleteWithVision = onCall(
  {
    memory: '1GiB',
    timeoutSeconds: 120,
    secrets: [anthropicKey, openaiKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be logged in');
    }

    const userId = request.auth.uid;
    const { imageBase64, prompt, provider, model, temperature, maxTokens, systemMessage, structured } = request.data;

    try {
      try {
        await checkRateLimit(userId, 'ai_vision');
      } catch (rateLimitError: any) {
        logger.error('Rate limit check failed (vision)', { userId, operation: 'ai_vision', error: rateLimitError.message, stack: rateLimitError.stack });
        throw rateLimitError;
      }

      if (!imageBase64 || typeof imageBase64 !== 'string') {
        throw new HttpsError('invalid-argument', 'Invalid image data');
      }

      if (!prompt || typeof prompt !== 'string') {
        throw new HttpsError('invalid-argument', 'Invalid prompt');
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
          temperature: structured ? 0.3 : (temperature || 0.7), // Lower temp for structured output
          maxTokens: maxTokens || 1500,
          systemMessage,
        });
      } else {
        const openai = getOpenAIClient();
        response = await completeWithOpenAIVision(openai, imageBase64, finalPrompt, {
          model: model || 'gpt-4o',
          temperature: structured ? 0.3 : (temperature || 0.7), // Lower temp for structured output
          maxTokens: maxTokens || 1500,
        });
      }

      // Clean JSON if structured and validate
      let content = structured ? cleanJSONFromMarkdown(response.content) : response.content;

      if (structured) {
        try {
          JSON.parse(content);
          logger.info('Vision JSON validation successful', { userId, jsonLength: content.length });
        } catch (parseError: any) {
          logger.error('Invalid JSON from vision AI', {
            userId,
            provider,
            model: response.model,
            error: parseError.message,
            rawContent: response.content.substring(0, 500),
            cleanedContent: content.substring(0, 500),
          });

          throw new HttpsError(
            'invalid-argument',
            'Unable to extract valid data from the image. Please try again with a clearer image or simpler content.',
            {
              technicalDetails: parseError.message,
              hint: 'JSON parsing failed',
            }
          );
        }
      }

      // Log usage
      try {
        await logAIUsage(userId, 'ai_vision', {
          provider,
          model: response.model,
          inputTokens: response.usage.input_tokens,
          outputTokens: response.usage.output_tokens,
          totalTokens: response.usage.total_tokens,
        });
      } catch (logError: any) {
        // Don't fail the request if logging fails
        logger.error('AI usage logging failed (vision)', { userId, operation: 'ai_vision', error: logError.message });
      }

      return {
        content,
        model: response.model,
        usage: response.usage,
      };
    } catch (error: any) {
      // Pass through user-friendly errors
      if (error instanceof HttpsError) {
        throw error;
      }

      logger.error('AI Vision Error', { userId, error: error.message, stack: error.stack });
      throw new HttpsError(
        'internal',
        'Something went wrong while analyzing the image. Please try again.',
        { technicalDetails: error.message }
      );
    }
  }
);

// MARK: - Helper Functions

async function completeWithAnthropic(
  anthropic: Anthropic,
  prompt: string,
  options: { model: string; temperature: number; maxTokens: number; systemMessage?: string }
): Promise<any> {
  const requestParams: any = {
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

async function completeWithOpenAI(
  openai: OpenAI,
  prompt: string,
  options: { model: string; temperature: number; maxTokens: number; systemMessage?: string }
): Promise<any> {
  const messages: any[] = [];

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
      input_tokens: response.usage?.prompt_tokens || 0,
      output_tokens: response.usage?.completion_tokens || 0,
      total_tokens: response.usage?.total_tokens || 0,
    },
    metadata: {
      finish_reason: response.choices[0].finish_reason,
      id: response.id,
    },
  };
}

async function completeWithAnthropicVision(
  anthropic: Anthropic,
  imageBase64: string,
  prompt: string,
  options: { model: string; temperature: number; maxTokens: number; systemMessage?: string }
): Promise<any> {
  const requestParams: any = {
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

async function completeWithOpenAIVision(
  openai: OpenAI,
  imageBase64: string,
  prompt: string,
  options: { model: string; temperature: number; maxTokens: number }
): Promise<any> {
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
      input_tokens: response.usage?.prompt_tokens || 0,
      output_tokens: response.usage?.completion_tokens || 0,
      total_tokens: response.usage?.total_tokens || 0,
    },
    metadata: {
      finish_reason: response.choices[0].finish_reason,
      id: response.id,
    },
  };
}

function cleanJSONFromMarkdown(text: string): string {
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
