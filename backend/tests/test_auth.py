from app.config import get_settings
from tests.conftest import signup


def test_register_login_me(client):
    signup(client)
    r = client.post("/api/v1/auth/login", json={"email": "Naveen@Example.com", "password": "correct horse battery"})
    assert r.status_code == 200
    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {r.json()['access_token']}"})
    assert me.json()["email"] == "naveen@example.com"


def test_wrong_password_and_unknown_user_look_the_same(client):
    signup(client)
    a = client.post("/api/v1/auth/login", json={"email": "naveen@example.com", "password": "wrong password!"})
    b = client.post("/api/v1/auth/login", json={"email": "nobody@example.com", "password": "wrong password!"})
    assert a.status_code == b.status_code == 401
    assert a.json() == b.json()


def test_duplicate_and_short_password(client):
    signup(client)
    assert client.post("/api/v1/auth/register", json={"email": "naveen@example.com", "password": "x" * 10}).status_code == 409
    assert client.post("/api/v1/auth/register", json={"email": "b@example.com", "password": "short"}).status_code == 422


def test_registration_can_be_closed(client, monkeypatch):
    signup(client)
    monkeypatch.setattr(get_settings(), "allow_registration", False)
    r = client.post("/api/v1/auth/register", json={"email": "other@example.com", "password": "x" * 10})
    assert r.status_code == 403


def test_protected_routes_need_a_valid_token(client):
    assert client.get("/api/v1/sync/pull").status_code == 401
    assert client.get("/api/v1/sync/pull", headers={"Authorization": "Bearer garbage"}).status_code == 401
