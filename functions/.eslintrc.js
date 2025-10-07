module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    "ecmaVersion": 2020,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "linebreak-style": "off",         // ไม่เช็ค CRLF/LF
    "max-len": ["warn", { "code": 120 }],
    "quotes": ["warn", "double", { "allowTemplateLiterals": true }],
    "object-curly-spacing": "off",
    "no-multi-spaces": "off",
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
