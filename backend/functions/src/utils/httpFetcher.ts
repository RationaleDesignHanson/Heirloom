/**
 * HTTP fetcher with retry logic, timeout, and circuit breaker
 */

import fetch from 'node-fetch';
import {UrlUtils} from './urlUtils';
import {ImportError} from '../types';

interface FetchOptions {
  maxRetries?: number;
  timeout?: number;
  headers?: Record<string, string>;
}

interface CircuitBreakerState {
  failures: number;
  lastFailure?: Date;
  isOpen: boolean;
}

export class HttpFetcher {
  private static circuitBreakers = new Map<string, CircuitBreakerState>();
  private static readonly CIRCUIT_BREAKER_THRESHOLD = 5;
  private static readonly CIRCUIT_BREAKER_RESET_TIME = 60 * 1000; // 1 minute

  /**
   * Fetch URL with retries and circuit breaker
   */
  static async fetch(
      url: string,
      options: FetchOptions = {}
  ): Promise<{ html: string; success: boolean; error?: ImportError }> {
    const {
      maxRetries = 3,
      timeout = 15000,
      headers = {},
    } = options;

    const domain = UrlUtils.extractDomain(url);

    // Check circuit breaker
    if (this.isCircuitOpen(domain)) {
      return {
        html: '',
        success: false,
        error: {
          type: 'network',
          message: `Circuit breaker open for ${domain}. Too many recent failures.`,
        },
      };
    }

    // Attempt fetch with retries
    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), timeout);

        const response = await fetch(url, {
          headers: {
            'User-Agent': UrlUtils.getUserAgent(),
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'en-US,en;q=0.9',
            ...headers,
          },
          signal: controller.signal,
        });

        clearTimeout(timeoutId);

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const html = await response.text();

        // Success - reset circuit breaker
        this.recordSuccess(domain);

        return {html, success: true};
      } catch (error: any) {
        console.warn(`Fetch attempt ${attempt + 1} failed for ${url}:`, error.message);

        // If last retry, record failure and return error
        if (attempt === maxRetries - 1) {
          this.recordFailure(domain);

          const importError: ImportError = {
            type: error.name === 'AbortError' ? 'timeout' : 'network',
            message: error.message,
            details: {attempt, maxRetries},
          };

          return {html: '', success: false, error: importError};
        }

        // Exponential backoff before retry
        await this.sleep(Math.pow(2, attempt) * 1000);
      }
    }

    // Should never reach here
    return {
      html: '',
      success: false,
      error: {type: 'network', message: 'Unknown error'},
    };
  }

  /**
   * Check if circuit breaker is open for domain
   */
  private static isCircuitOpen(domain: string): boolean {
    const state = this.circuitBreakers.get(domain);
    if (!state || !state.isOpen) return false;

    // Check if enough time has passed to reset
    if (state.lastFailure) {
      const timeSinceFailure = Date.now() - state.lastFailure.getTime();
      if (timeSinceFailure > this.CIRCUIT_BREAKER_RESET_TIME) {
        // Reset circuit breaker
        state.isOpen = false;
        state.failures = 0;
        return false;
      }
    }

    return true;
  }

  /**
   * Record successful fetch
   */
  private static recordSuccess(domain: string): void {
    const state = this.circuitBreakers.get(domain);
    if (state) {
      state.failures = 0;
      state.isOpen = false;
    }
  }

  /**
   * Record failed fetch
   */
  private static recordFailure(domain: string): void {
    let state = this.circuitBreakers.get(domain);
    if (!state) {
      state = {failures: 0, isOpen: false};
      this.circuitBreakers.set(domain, state);
    }

    state.failures++;
    state.lastFailure = new Date();

    // Open circuit breaker if threshold reached
    if (state.failures >= this.CIRCUIT_BREAKER_THRESHOLD) {
      state.isOpen = true;
      console.warn(`Circuit breaker opened for ${domain} after ${state.failures} failures`);
    }
  }

  /**
   * Sleep for specified milliseconds
   */
  private static sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Get circuit breaker stats (for debugging)
   */
  static getCircuitBreakerStats(): Map<string, CircuitBreakerState> {
    return this.circuitBreakers;
  }

  /**
   * Reset circuit breaker for domain (for testing)
   */
  static resetCircuitBreaker(domain: string): void {
    this.circuitBreakers.delete(domain);
  }
}
