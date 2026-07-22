# Global Codex Instructions

## Load Relevant Skills Before Specialized Work

Before starting specialized work, check the available Codex skills and load the relevant one before acting. Skills carry the canonical workflow and edge cases for recurring tasks.

Use this trigger map as a standing preference:

| Touching | Load before work |
|---|---|
| OpenAI or Codex behavior, APIs, models, docs, config, MCP, plugins, hooks, or skills | `openai-docs` |
| Creating or editing Codex skills | `skill-creator` or `superpowers:writing-skills` |
| Installing Codex skills | `skill-installer` |
| Figma URLs or Figma implementation | `figma-implement-design` |
| Expo or React Native UI | `building-native-ui` |
| Network requests, API calls, or data fetching | `native-data-fetching` |
| React Native performance, jank, memory, bundle size, or native modules | `react-native-best-practices` |
| TDD or bugfix implementation | `superpowers:test-driven-development` when available |
| Debugging unexpected behavior | `superpowers:systematic-debugging` when available |
| Verification before claiming completion | `superpowers:verification-before-completion` when available |

If a matching skill exists, read it before implementation. If no matching skill exists, proceed using the repository instructions and verified local context.

## Database Migrations And Seed Data

Whenever a new migration changes schema in a way that affects existing seed data, audit and update the seed files in the same change.

- For NOT NULL additions, add values to every affected seed insert.
- For CHECK constraints, verify seeded values pass.
- For renames or removals, update column lists.
- Run the project-specific reset or migration verification command before claiming the migration is ready.

## Supabase Migration Filenames

When creating a new Supabase migration, use the Supabase CLI generator and keep the generated timestamp prefix.

- Use `npx supabase migration new <name>`.
- Do not hand-edit timestamps.
- Do not rename applied migrations.
- Leave old already-applied numeric-prefix migrations alone.
