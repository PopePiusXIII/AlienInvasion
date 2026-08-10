---
applyTo: "**/*.luau"
description: "Luau error-handling rules. Use when creating or editing Luau code."
---

Never add fallback behavior.

Do not substitute default values for missing, invalid, or unexpected data. Do not silently return empty strings, empty tables, placeholder assets, default configuration entries, or alternate values.

Do not catch, suppress, or convert errors into successful-looking behavior. Let invalid state and missing dependencies fail visibly so the root cause can be fixed.

When an invariant is required, validate it explicitly and raise an error with useful context rather than continuing with a fallback.
