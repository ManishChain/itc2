module.exports = {
  parser: '@typescript-eslint/parser',
  parserOptions: {
    project: 'tsconfig.json',
    sourceType: 'module',
  },
  plugins: ['@typescript-eslint/eslint-plugin', 'jest'],
  extends: ['../../.eslintrc.js'],
  rules: {
    '@typescript-eslint/no-var-requires': 'off'
  }
};
