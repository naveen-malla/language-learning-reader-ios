import os
import tempfile

# Configure before the app is imported: tests use a throwaway SQLite file, never your real DB.
_tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
# Tests DROP all tables, so they only ever use TEST_DATABASE_URL (CI sets it to a Postgres service), never DATABASE_URL.
os.environ["DATABASE_URL"] = os.environ.get("TEST_DATABASE_URL", f"sqlite:///{_tmp.name}")
os.environ["JWT_SECRET"] = "test-secret"
os.environ["ALLOW_REGISTRATION"] = "true"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.db import Base, engine  # noqa: E402
from app.main import app  # noqa: E402


@pytest.fixture(autouse=True)
def clean_db():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    yield


@pytest.fixture
def client():
    return TestClient(app)


def signup(client, email="naveen@example.com", password="correct horse battery"):
    r = client.post("/api/v1/auth/register", json={"email": email, "password": password})
    assert r.status_code == 201, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def auth(client):
    return signup(client)
