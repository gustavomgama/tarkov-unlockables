// ESLint is the only linter the JavaScript side of the app had; the Stimulus
// controllers under app/javascript were previously unchecked. Kept to the
// recommended rule set plus browser globals — no plugin zoo.
import js from "@eslint/js"
import globals from "globals"

export default [
  {
    ignores: ["app/assets/builds/**", "node_modules/**", "tmp/**", "vendor/**", "coverage/**"],
  },
  js.configs.recommended,
  {
    files: ["app/javascript/**/*.js"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: {
        ...globals.browser,
      },
    },
    rules: {
      // The controllers already satisfy these; keeping them on prevents
      // regressions rather than reformatting anything today.
      eqeqeq: "error",
      "no-console": ["warn", { allow: ["warn", "error"] }],
      "no-implicit-globals": "error",
      "no-var": "error",
      "prefer-const": "error",
    },
  },
]
