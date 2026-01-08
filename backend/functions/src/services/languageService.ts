/**
 * Language Detection and Translation Service
 * Routes to Claude API (Anthropic) for multilingual recipe processing
 */

import {
  DetectLanguageResponse,
  TranslateTextResponse,
} from '../types';

// Language code to name mapping
const LANGUAGE_NAMES: Record<string, string> = {
  'en': 'English',
  'fr': 'French',
  'es': 'Spanish',
  'de': 'German',
  'ja': 'Japanese',
  'zh': 'Chinese',
  'ko': 'Korean',
};

// Regional unit system defaults
const UNIT_SYSTEM_DEFAULTS: Record<string, 'metric' | 'imperial'> = {
  'en': 'imperial', // US default
  'fr': 'metric',
  'es': 'metric',
  'de': 'metric',
  'ja': 'metric',
  'zh': 'metric',
  'ko': 'metric',
};

export class LanguageService {
  private claudeApiKey: string;
  private claudeApiUrl = 'https://api.anthropic.com/v1/messages';

  constructor(claudeApiKey: string) {
    this.claudeApiKey = claudeApiKey;
  }

  /**
   * Detect language of recipe text using Claude
   */
  async detectLanguage(
      text: string,
      hints?: { url?: string; domain?: string }
  ): Promise<DetectLanguageResponse> {
    try {
      // Prepare prompt for Claude
      const prompt = this.buildDetectionPrompt(text, hints);

      // Call Claude API
      const response = await this.callClaude(prompt);

      // Parse Claude's response
      const detection = this.parseDetectionResponse(response);

      return detection;
    } catch (error: any) {
      console.error('Language detection error:', error);
      // Fallback to English with low confidence
      return {
        language: 'en',
        confidence: 0.5,
        languageName: 'English',
        detectedUnitSystem: 'imperial',
        needsTranslation: false,
      };
    }
  }

  /**
   * Translate text using Claude
   */
  async translateText(
      text: string,
      sourceLanguage: string,
      targetLanguage: string = 'en',
      context?: 'title' | 'ingredient' | 'instruction' | 'note'
  ): Promise<TranslateTextResponse> {
    try {
      // Prepare prompt for Claude
      const prompt = this.buildTranslationPrompt(
          text,
          sourceLanguage,
          targetLanguage,
          context
      );

      // Call Claude API
      const response = await this.callClaude(prompt);

      // Parse Claude's response
      const translation = this.parseTranslationResponse(
          response,
          sourceLanguage,
          targetLanguage
      );

      return translation;
    } catch (error: any) {
      console.error('Translation error:', error);
      // Return original text with fallback indicator
      return {
        translatedText: text,
        sourceLanguage,
        targetLanguage,
        confidence: 0,
        engine: 'fallback',
      };
    }
  }

  /**
   * Build language detection prompt
   */
  private buildDetectionPrompt(
      text: string,
      hints?: { url?: string; domain?: string }
  ): string {
    let prompt = `Analyze the following recipe text and detect its language.

Recipe text:
${text}
`;

    if (hints?.url) {
      prompt += `\nSource URL: ${hints.url}`;
    }
    if (hints?.domain) {
      prompt += `\nDomain: ${hints.domain}`;
    }

    prompt += `

Respond ONLY with a JSON object (no markdown, no explanation) in this exact format:
{
  "language": "ISO-639-1 code (e.g., en, fr, ja, zh, ko, es, de)",
  "confidence": 0.95,
  "languageName": "English",
  "detectedUnitSystem": "metric or imperial or mixed",
  "needsTranslation": false
}

Important:
- Use ISO 639-1 two-letter codes
- Confidence should be 0-1 (1.0 = certain)
- Detect unit system from units used (cups/oz = imperial, g/ml = metric)
- needsTranslation is true if language is NOT English
- Return ONLY the JSON, nothing else`;

    return prompt;
  }

  /**
   * Build translation prompt
   */
  private buildTranslationPrompt(
      text: string,
      sourceLanguage: string,
      targetLanguage: string,
      context?: string
  ): string {
    const contextHint = context ?
      `This is a recipe ${context}. ` :
      'This is recipe text. ';

    const prompt = `${contextHint}Translate the following text from ${LANGUAGE_NAMES[sourceLanguage] || sourceLanguage} to ${LANGUAGE_NAMES[targetLanguage] || targetLanguage}.

Source text:
${text}

Respond ONLY with a JSON object (no markdown, no explanation) in this exact format:
{
  "translatedText": "translated text here",
  "confidence": 0.95
}

Important:
- For ingredients: preserve quantities and units exactly
- For instructions: maintain cooking terminology accuracy
- For titles: keep it natural and appetizing
- Confidence should be 0-1 (1.0 = certain)
- Return ONLY the JSON, nothing else`;

    return prompt;
  }

  /**
   * Call Claude API
   */
  private async callClaude(prompt: string): Promise<string> {
    const response = await fetch(this.claudeApiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': this.claudeApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 1024,
        messages: [
          {
            role: 'user',
            content: prompt,
          },
        ],
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Claude API error (${response.status}): ${errorText}`);
    }

    const data = await response.json() as {
      content?: Array<{ text?: string }>;
    };

    // Extract text from Claude's response
    if (!data.content || !data.content[0] || !data.content[0].text) {
      throw new Error('Invalid Claude API response format');
    }

    return data.content[0].text;
  }

  /**
   * Parse language detection response from Claude
   */
  private parseDetectionResponse(response: string): DetectLanguageResponse {
    try {
      // Try to extract JSON from response (in case Claude added explanation)
      const jsonMatch = response.match(/\{[\s\S]*\}/);
      const jsonStr = jsonMatch ? jsonMatch[0] : response;

      const parsed = JSON.parse(jsonStr);

      // Validate required fields
      if (!parsed.language || !parsed.languageName) {
        throw new Error('Missing required fields in detection response');
      }

      return {
        language: parsed.language,
        confidence: parsed.confidence || 0.8,
        languageName: parsed.languageName,
        detectedUnitSystem: parsed.detectedUnitSystem ||
          UNIT_SYSTEM_DEFAULTS[parsed.language] ||
          'imperial',
        needsTranslation: parsed.needsTranslation !== undefined ?
          parsed.needsTranslation :
          parsed.language !== 'en',
      };
    } catch (error: any) {
      console.error('Failed to parse detection response:', error);
      console.error('Response was:', response);
      // Fallback to English
      return {
        language: 'en',
        confidence: 0.5,
        languageName: 'English',
        detectedUnitSystem: 'imperial',
        needsTranslation: false,
      };
    }
  }

  /**
   * Parse translation response from Claude
   */
  private parseTranslationResponse(
      response: string,
      sourceLanguage: string,
      targetLanguage: string
  ): TranslateTextResponse {
    try {
      // Try to extract JSON from response
      const jsonMatch = response.match(/\{[\s\S]*\}/);
      const jsonStr = jsonMatch ? jsonMatch[0] : response;

      const parsed = JSON.parse(jsonStr);

      // Validate required fields
      if (!parsed.translatedText) {
        throw new Error('Missing translatedText in response');
      }

      return {
        translatedText: parsed.translatedText,
        sourceLanguage,
        targetLanguage,
        confidence: parsed.confidence || 0.8,
        engine: 'claude',
      };
    } catch (error: any) {
      console.error('Failed to parse translation response:', error);
      console.error('Response was:', response);
      throw error;
    }
  }
}
