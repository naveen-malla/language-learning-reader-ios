# Engineering Roadmap

Goal: ship the web app Naveen uses daily, and learn production software engineering on it, in line with the
[AI Dev Tools Zoomcamp](https://github.com/DataTalksClub/ai-dev-tools-zoomcamp).
Rule: only add a technology when this app needs it. Progress is tracked in `LEARNING_LOG.md`.

## Architecture (v0.1)

```
iPhone / Mac browser ── PWA (web/: React + Vite + TS)
   │  IndexedDB (Dexie) = local source of truth, works offline
   │  Service worker caches app shell + dictionary shards
   │  /dict/de/*.json   static files from the CDN (no backend involved)
   ▼  HTTPS + Bearer JWT
FastAPI (backend/) ── /api/v1/auth/*  /api/v1/sync/push|pull  /api/v1/translate
   ▼  SQLAlchemy
Postgres (local: docker compose; prod: managed Postgres)

iOS app (repo root) unchanged; it shares field names with web and backend.
```

Key decisions (details in `DECISIONS.md`):
- **Offline-first sync** with a per-user `serverVersion` counter and last-write-wins per row.
- **A sync API instead of CRUD endpoints** (a pull/push pair instead of one endpoint per resource): an offline client needs "everything since X" and batched writes.
- **Static dictionary shards** instead of a dictionary API: 382k entries are 18 MB split into 256 files of about 70 KB each, cached by the CDN and the service worker.
- **Same field names end to end** (camelCase, as in Swift) instead of mapping between naming styles.

## Course module mapping

| Course module | Concept | Where it lives here | State | Next exercise |
|---|---|---|---|---|
| 1 AI-native workflow | Spec, backlog, AGENTS.md, PM/engineer/QA roles | `AGENTS.md`, `PLAN.md`, `DECISIONS.md` | Strong on iOS; web/backend not yet in AGENTS.md | Write the spec for "YouTube import on web" as a backlog of 3–5 tasks before any code |
| 2 Full-stack app | Frontend ↔ API contract ↔ backend ↔ DB | `web/src/lib/api.ts`, `backend/app/schemas.py`, `backend/openapi.json` | Contract is generated, not designed first | Generate TS types from `openapi.json` (openapi-typescript) and delete the hand-written ones |
| 2 | Auth and authorization | `backend/app/security.py`, `userId` filter in `routers/sync.py` | Argon2 + JWT and per-user row scoping are tested | Explain why the JWT lives in localStorage and what an XSS bug would expose; add login rate limiting |
| 2 | Persistence | Dexie (client), SQLAlchemy + Postgres (server) | `create_all` only, no migrations | Add Alembic, then add a column through a migration |
| 3 | Testing pyramid | `web/src/lib/*.test.ts`, `backend/tests/` | Unit and API tests in place; the two-device E2E only runs by hand | Turn the two-device Playwright script into `web/e2e/` and run it in CI |
| 3 | Docker / Compose | `backend/Dockerfile`, `backend/docker-compose.yml` | Image is non-root and has a healthcheck | Run `docker compose up --build`, kill the API container, watch it restart |
| 3 | SQLite → Postgres | Tests run on both in CI | Done | Find one behaviour that differs between them (hint: row locking with `with_for_update`) |
| 3 | CI/CD | `.github/workflows/web-backend-ci.yml` | CI yes, CD no | Deploy only after CI passes (Render/Fly deploy hook) |
| 3 | Cloud deploy | Not yet | — | M2 below; choose a host (decision is yours) |
| 4 | Dev vs prod environments | `.env.example`, `ENVIRONMENT` setting | Single environment | Separate prod database + secret; preview deploys for web |
| 4 | Observability | JSON access logs with request_id, `/health` | Logs only | Add error tracking (Sentry free tier) before Prometheus/Grafana; the full stack is overkill for one user |
| 5 | Skills / subagents / worktrees | Your Claude Code setup | — | Make a `reviewer` subagent that checks every PR against this roadmap's rules |

## Milestones

1. **M1: local full stack (done in v0.1).** PWA, FastAPI, Postgres, sync, auth, unit, API and E2E checks.
2. **M2: deploy.** Web on Vercel or Cloudflare Pages, API container on Render or Fly.io, managed Postgres (Neon or Supabase as plain Postgres). Set secrets in the host, close registration, install on your iPhone.
3. **M3: contract-first and migrations.** Generated TS client, Alembic, E2E in CI.
4. **M4: feature parity.** YouTube import and Watch mode (server-side subtitle fetch), Kannada dictionary, LingQ-style "mark page known".
5. **M5: operate it.** Error tracking, uptime check, backups and a tested restore, dev and prod environments.

## What can go wrong in production (watch list)
- Device clocks that are far off decide last-write-wins conflicts (an edit timestamped by a wrong clock can "win").
- iOS can evict a PWA's storage if it isn't used for weeks; the server copy is the backup, so sync often.
- Machine-translation endpoint (`translate.googleapis.com`, unofficial) can rate-limit or change shape; the API maps that to a 502.
- A leaked `JWT_SECRET` lets anyone forge sessions. Rotate it in the host's secrets UI.
