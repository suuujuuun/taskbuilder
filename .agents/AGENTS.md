# Agent Behavioral Rules

- **Auto-Build**: After making source code modifications and successfully verifying them with TypeScript (`npm run lint` or `tsc`), automatically proceed to clear the build caches (e.g. `dist`, `dist-electron`, `release` folders) and run `npm run build` without asking for permission.
