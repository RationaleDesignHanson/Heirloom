/**
 * AI Gateway - Secure proxy for AI service requests
 * All API keys stay server-side, clients use Firebase Auth tokens
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import Anthropic from '@anthropic-ai/sdk';
import OpenAI from 'openai';
import { checkRateLimit, logAIUsage } from './rate-limiter';

const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === 'true';

// Lazy-initialize AI clients (deferred so module loads without env vars during analysis)
const getAnthropicClient = () => new Anthropic({ apiKey: process.env.ANTHROPIC_KEY });
const getOpenAIClient = () => new OpenAI({ apiKey: process.env.OPENAI_KEY });

// MARK: - Text Completion

/**
 * Complete a text prompt with AI
 * Maps to: AIServiceProtocol.complete(prompt:options:)
 */
export const aiComplete = onCall(async (request) => {
  // 1. Verify authentication
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }
  if (ENFORCE_APP_CHECK && !request.app) {
    throw new HttpsError('failed-precondition', 'App Check verification failed.');
  }

  const userId = request.auth.uid;

  try {
    // 2. Rate limiting check
    await checkRateLimit(userId, 'ai_complete');

    // 3. Validate input
    const { prompt, provider, model, temperature, maxTokens, systemMessage } = request.data;

    if (!prompt || typeof prompt !== 'string') {
      throw new HttpsError('invalid-argument', 'Invalid prompt');
    }

    if (!provider || !['anthropic', 'openai'].includes(provider)) {
      throw new HttpsError('invalid-argument', 'Invalid provider');
    }

    // 4. Call appropriate AI service
    let response;
    if (provider === 'anthropic') {
      response = await completeWithAnthropic(prompt, {
        model: model || 'claude-3-haiku-20240307',
        temperature: temperature || 0.7,
        maxTokens: maxTokens || 1024,
        systemMessage,
      });
    } else {
      response = await completeWithOpenAI(prompt, {
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
    } catch (e) { logger.warn('logAIUsage failed', { error: e }); }

    // 6. Return response
    return {
      content: response.content,
      model: response.model,
      usage: response.usage,
      metadata: response.metadata,
    };
  } catch (error: any) {
    logger.error('AI Complete Error', { userId, error: error.message });

    if (error instanceof HttpsError) throw error;

    if (error.status === 429) {
      throw new HttpsError('resource-exhausted', 'AI service rate limit exceeded');
    }
    if (error.status === 400) {
      throw new HttpsError('invalid-argument', error.message || 'Invalid request to AI service');
    }

    throw new HttpsError('internal', 'Failed to complete AI request');
  }
});

// MARK: - Structured Completion

/**
 * Complete with structured JSON output
 * Maps to: AIServiceProtocol.completeStructured(prompt:schema:options:)
 */
export const aiCompleteStructured = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }
  if (ENFORCE_APP_CHECK && !request.app) {
    throw new HttpsError('failed-precondition', 'App Check verification failed.');
  }

  const userId = request.auth.uid;

  try {
    await checkRateLimit(userId, 'ai_complete');

    const { prompt, provider, model, temperature, maxTokens, systemMessage } = request.data;

    if (!prompt || typeof prompt !== 'string') {
      throw new HttpsError('invalid-argument', 'Invalid prompt');
    }

    // Add JSON formatting instructions
    const structuredPrompt = `${prompt}\n\nIMPORTANT: Respond ONLY with valid JSON. No markdown, no explanations, just raw JSON.`;

    // Call AI service
    let response;
    if (provider === 'anthropic') {
      response = await completeWithAnthropic(structuredPrompt, {
        model: model || 'claude-3-haiku-20240307',
        temperature: temperature || 0.7,
        maxTokens: maxTokens || 1024,
        systemMessage,
      });
    } else {
      response = await completeWithOpenAI(structuredPrompt, {
        model: model || 'gpt-4o-mini',
        temperature: temperature || 0.7,
        maxTokens: maxTokens || 1024,
        systemMessage,
      });
    }

    // Clean JSON from markdown if present
    const cleanedJSON = cleanJSONFromMarkdown(response.content);

    // Log usage
    try {
      await logAIUsage(userId, 'ai_complete_structured', {
        provider,
        model: response.model,
        inputTokens: response.usage.input_tokens,
        outputTokens: response.usage.output_tokens,
        totalTokens: response.usage.total_tokens,
      });
    } catch (e) { logger.warn('logAIUsage failed', { error: e }); }

    return {
      content: cleanedJSON,
      model: response.model,
      usage: response.usage,
    };
  } catch (error: any) {
    logger.error('AI Complete Structured Error', { userId, error: error.message });

    if (error instanceof HttpsError) throw error;

    if (error.status === 429) {
      throw new HttpsError('resource-exhausted', 'AI service rate limit exceeded');
    }
    if (error.status === 400) {
      throw new HttpsError('invalid-argument', error.message || 'Invalid request to AI service');
    }

    throw new HttpsError('internal', 'Failed to complete structured AI request');
  }
});

// MARK: - Vision Completion

/**
 * Complete with vision (image + text prompt)
 * Maps to: AIServiceProtocol.completeWithVisionStructured(image:prompt:schema:options:)
 */
export const aiCompleteWithVision = onCall(
  { memory: '1GiB', timeoutSeconds: 120 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be logged in');
    }
    if (ENFORCE_APP_CHECK && !request.app) {
      throw new HttpsError('failed-precondition', 'App Check verification failed.');
    }

    const userId = request.auth.uid;

    try {
      await checkRateLimit(userId, 'ai_vision');

      const { imageBase64, prompt, provider, model, temperature, maxTokens, systemMessage, structured } = request.data;

      if (!imageBase64 || typeof imageBase64 !== 'string') {
        throw new HttpsError('invalid-argument', 'Invalid image data');
      }

      if (!prompt || typeof prompt !== 'string') {
        throw new HttpsError('invalid-argument', 'Invalid prompt');
      }

      // Add structured formatting if requested
      const finalPrompt = structured
        ? `${prompt}\n\nIMPORTANT: Respond ONLY with valid JSON. No markdown, no explanations, just raw JSON.`
        : prompt;

      // Call AI service with vision
      let response;
      if (provider === 'anthropic') {
        response = await completeWithAnthropicVision(imageBase64, finalPrompt, {
          model: model || 'claude-sonnet-4-5-20250929',
          temperature: temperature || 0.7,
          maxTokens: maxTokens || 1500,
          systemMessage,
        });
      } else {
        response = await completeWithOpenAIVision(imageBase64, finalPrompt, {
          model: model || 'gpt-4o',
          temperature: temperature || 0.7,
          maxTokens: maxTokens || 1500,
        });
      }

      // Clean JSON if structured
      const content = structured ? cleanJSONFromMarkdown(response.content) : response.content;

      // Log usage
      try {
        await logAIUsage(userId, 'ai_vision', {
          provider,
          model: response.model,
          inputTokens: response.usage.input_tokens,
          outputTokens: response.usage.output_tokens,
          totalTokens: response.usage.total_tokens,
        });
      } catch (e) { logger.warn('logAIUsage failed', { error: e }); }

      return {
        content,
        model: response.model,
        usage: response.usage,
      };
    } catch (error: any) {
      logger.error('AI Vision Error', { userId, error: error.message });

      if (error instanceof HttpsError) throw error;

      if (error.status === 429) {
        throw new HttpsError('resource-exhausted', 'AI service rate limit exceeded');
      }
      if (error.status === 400) {
        throw new HttpsError('invalid-argument', error.message || 'Invalid request to AI service');
      }

      throw new HttpsError('internal', 'Failed to complete vision AI request');
    }
  }
);

// MARK: - Helper Functions

async function completeWithAnthropic(
  prompt: string,
  options: { model: string; temperature: number; maxTokens: number; systemMessage?: string }
): Promise<any> {
  const response = await getAnthropicClient().messages.create({
    model: options.model,
    max_tokens: options.maxTokens,
    temperature: options.temperature,
    system: options.systemMessage,
    messages: [{ role: 'user', content: prompt }],
  });

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
  prompt: string,
  options: { model: string; temperature: number; maxTokens: number; systemMessage?: string }
): Promise<any> {
  const messages: any[] = [];

  if (options.systemMessage) {
    messages.push({ role: 'system', content: options.systemMessage });
  }

  messages.push({ role: 'user', content: prompt });

  const response = await getOpenAIClient().chat.completions.create({
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
  imageBase64: string,
  prompt: string,
  options: { model: string; temperature: number; maxTokens: number; systemMessage?: string }
): Promise<any> {
  const response = await getAnthropicClient().messages.create({
    model: options.model,
    max_tokens: options.maxTokens,
    temperature: options.temperature,
    system: options.systemMessage,
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
  });

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
  imageBase64: string,
  prompt: string,
  options: { model: string; temperature: number; maxTokens: number }
): Promise<any> {
  const response = await getOpenAIClient().chat.completions.create({
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
