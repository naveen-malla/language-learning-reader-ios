# AGENTS.md

## Project Intent
Build a language reader iOS app (initial scope: Kannada) with fast, offline-friendly word lookup, vocabulary tracking, and flashcards. Keep the UX clean and focused on reading.

## Non-Goals
- No cloud sync in V1.
- No hard dependency on online translation APIs.
- No reliance on Apple Translation framework for core functionality.

## Workflow
- Ship a basic working function first, then scale.
- Challenge assumptions and suggest better approaches.
- Prefer small, inspectable changes and clear structure.
- Keep commits small and focused.
- Build with learning psychology in mind: reduce friction, reinforce recall, and keep the reading flow smooth.

## Quality Bar
- Deterministic behavior where possible.
- Clean separation of UI, data, and domain logic.
- Add tests for tokenization and vocab status logic.

## Testing
- Use iOS Simulator for all runs.
- Prefer iPhone 14 Pro if available; otherwise use a recent iPhone runtime.
- Build/run from CLI with `xcodebuild` after each milestone.

## Data & Secrets
- Never commit secrets.
- Store optional API keys in Keychain only.
- Avoid assistant/tool branding or AI references in code or UI.

## UI/UX Principles
- Reading-first layout.
- Tappable tokens must feel responsive.
- Color coding for vocab status should be consistent and unobtrusive.
