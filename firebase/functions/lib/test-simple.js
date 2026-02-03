"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.testSimple = void 0;
const https_1 = require("firebase-functions/v2/https");
/**
 * Simple test function
 */
exports.testSimple = (0, https_1.onCall)({ region: 'us-central1' }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'User must be authenticated');
    }
    return {
        message: 'Hello from testSimple function!',
        timestamp: new Date().toISOString(),
    };
});
//# sourceMappingURL=test-simple.js.map