module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/test/**/*.test.ts'],
  moduleFileExtensions: ['ts', 'js', 'json'],
  globals: {
    'ts-jest': {
      diagnostics: false,
    },
  },
  modulePathIgnorePatterns: ['<rootDir>/functions/', '<rootDir>/backend/'],
};
