/**
 * Firestore utilities
 * Helper functions for working with Firestore data
 */

/**
 * Remove undefined values from an object for Firestore storage
 * Firestore doesn't support undefined - fields must be null or omitted
 *
 * This function recursively removes all undefined values from an object:
 * - Undefined values are removed (field will not exist in Firestore)
 * - Null values are preserved (field will exist with null value)
 * - Nested objects are recursively cleaned
 * - Arrays are preserved with their undefined values removed
 *
 * @param obj - Object to clean
 * @returns Cleaned object with no undefined values
 */
export function removeUndefined<T extends Record<string, any>>(obj: T): Partial<T> {
  const result: any = {};

  for (const key in obj) {
    if (obj.hasOwnProperty(key)) {
      const value = obj[key];

      // Skip undefined values entirely (don't add to result)
      if (value === undefined) {
        continue;
      }

      // Recursively clean nested objects
      if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
        result[key] = removeUndefined(value);
      }
      // Clean arrays by filtering out undefined values
      else if (Array.isArray(value)) {
        result[key] = value
            .filter((item: any) => item !== undefined)
            .map((item: any) =>
              item !== null && typeof item === 'object' ?
                removeUndefined(item) :
                item
            );
      }
      // Keep all other values (including null, strings, numbers, booleans)
      else {
        result[key] = value;
      }
    }
  }

  return result;
}
