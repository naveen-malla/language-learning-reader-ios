# Language Reader: backend (FastAPI)

REST API for auth, sync and translation. Contract: `openapi.json` (live docs at `/docs` when running).

## Run
```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env              # set JWT_SECRET; DATABASE_URL defaults to SQLite if unset
uvicorn app.main:app --reload     # http://localhost:8000/docs
pytest -q                         # tests (SQLite); TEST_DATABASE_URL=... for Postgres
```
Production-like, with Postgres in containers:
```bash
docker compose up --build         # API :8000, Postgres :5432
```

## Endpoints
| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | /health | no | liveness + DB check |
| POST | /api/v1/auth/register | no | create account (closable with ALLOW_REGISTRATION=false) |
| POST | /api/v1/auth/login | no | get a JWT |
| GET | /api/v1/auth/me | yes | who am I |
| POST | /api/v1/sync/push | yes | upload changed rows (last-write-wins) |
| GET | /api/v1/sync/pull?since=N | yes | rows changed after cursor N |
| GET | /api/v1/translate?q=&sl=&tl= | yes | machine translation proxy |

Regenerate the contract after changing schemas:
`python -c "import json; from app.main import app; json.dump(app.openapi(), open('openapi.json','w'), indent=2)"`
