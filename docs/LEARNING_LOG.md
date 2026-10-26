# Learning Log

One line per concept. Status: `seen` (explained), `practiced` (did the exercise), `solid` (can explain it without notes).

| Date | Concept | Status | Where in the app | Still unclear |
|---|---|---|---|---|
| 2026-10-25 | Offline-first sync, logical clock, last-write-wins | seen | `web/src/lib/sync.ts`, `backend/app/routers/sync.py` | |
| 2026-10-25 | Authentication vs authorization (JWT + per-user row filter) | seen | `backend/app/security.py`, `test_users_cannot_see_each_others_rows` | |
| 2026-10-25 | Validation at the API edge (Pydantic, 422) | seen | `backend/app/schemas.py` | |
| 2026-10-25 | Testing levels: unit / API / E2E | seen | `web/src/lib/*.test.ts`, `backend/tests/`, two-device Playwright run | |
| 2026-10-25 | Docker image basics (layers, non-root, healthcheck) | seen | `backend/Dockerfile` | |
| 2026-10-25 | CI on SQLite and Postgres | seen | `.github/workflows/web-backend-ci.yml` | |

## Course progress
| Module | Lessons done | Applied in app |
|---|---|---|
| 1 AI-native workflow | | |
| 2 Full-stack app | | |
| 3 Test, containerize, deploy | | |
| 4 DevOps and observability | | |
| 5 Agent building blocks | | |
