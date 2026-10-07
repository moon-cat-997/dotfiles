# Package Manager

## New JS/TS projects use pnpm, not npm

When starting a new project that would otherwise use npm, use **pnpm**:

| Instead of | Use |
|---|---|
| `npm install` | `pnpm install` |
| `npm install <pkg>` | `pnpm add <pkg>` (`-D` for dev) |
| `npm run <script>` | `pnpm <script>` |
| `npx <tool>` (one-off) | `pnpm dlx <tool>` |
| `npx <tool>` (installed bin) | `pnpm exec <tool>` |

- Scaffolders: pass the pnpm flag when one exists (`create-next-app --use-pnpm`, `create-expo-app` run via `pnpm create expo-app`), so the first lockfile is `pnpm-lock.yaml`.
- Commit `pnpm-lock.yaml`; never also commit `package-lock.json`.
- If a tool breaks under pnpm's strict `node_modules` layout (common with React Native / Expo), add `node-linker=hoisted` to `.npmrc` — do not fall back to npm.

## Existing projects keep their package manager

The lockfile decides: `package-lock.json` → npm, `bun.lock` → bun, `yarn.lock` → yarn, `pnpm-lock.yaml` → pnpm. Do not migrate an existing project to pnpm unless asked.
