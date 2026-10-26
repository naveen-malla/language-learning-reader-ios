from tests.conftest import signup

T0 = "2026-10-25T10:00:00.000Z"
T1 = "2026-10-25T11:00:00.000Z"


def vocab(word="straße", status="level1", updated=T0, meaning="street"):
    return {
        "scopedKey": f"de|{word}", "id": "11111111-1111-4111-8111-111111111111", "normalizedKey": word,
        "languageCodeRaw": "de", "word": word.capitalize(), "meaning": meaning, "status": status,
        "createdAt": T0, "lastSeenAt": T0, "encounterCount": 1, "updatedAt": updated, "deletedAt": None,
    }


def push(client, auth, **changes):
    r = client.post("/api/v1/sync/push", json=changes, headers=auth)
    assert r.status_code == 200, r.text
    return r.json()


def pull(client, auth, since=0):
    r = client.get(f"/api/v1/sync/pull?since={since}", headers=auth)
    assert r.status_code == 200, r.text
    return r.json()


def test_push_then_pull_roundtrip(client, auth):
    res = push(client, auth, vocab=[vocab()])
    assert res == {"applied": 1, "stale": 0, "cursor": 1}
    data = pull(client, auth)
    assert data["changes"]["vocab"][0]["meaning"] == "street"
    assert "userId" not in data["changes"]["vocab"][0]
    assert pull(client, auth, since=data["cursor"])["changes"]["vocab"] == []


def test_last_write_wins(client, auth):
    push(client, auth, vocab=[vocab(status="known", updated=T1)])
    res = push(client, auth, vocab=[vocab(status="level2", updated=T0)])  # older edit arrives late
    assert res["stale"] == 1
    assert pull(client, auth)["changes"]["vocab"][0]["status"] == "known"


def test_users_cannot_see_each_others_rows(client, auth):
    push(client, auth, vocab=[vocab()])
    other = signup(client, email="eve@example.com")
    assert pull(client, other)["changes"]["vocab"] == []
    # Same primary key from another user is a separate row, not an overwrite.
    push(client, other, vocab=[vocab(meaning="HACKED", updated=T1)])
    assert pull(client, auth)["changes"]["vocab"][0]["meaning"] == "street"


def test_tombstones_sync(client, auth):
    push(client, auth, vocab=[vocab()])
    deleted = vocab(updated=T1) | {"deletedAt": T1}
    push(client, auth, vocab=[deleted])
    assert pull(client, auth)["changes"]["vocab"][0]["deletedAt"] == T1


def test_validation_rejects_bad_rows(client, auth):
    bad_status = vocab(status="mastered")
    assert client.post("/api/v1/sync/push", json={"vocab": [bad_status]}, headers=auth).status_code == 422
    bad_time = vocab(updated="yesterday")
    assert client.post("/api/v1/sync/push", json={"vocab": [bad_time]}, headers=auth).status_code == 422
    extra = vocab() | {"isAdmin": True}
    assert client.post("/api/v1/sync/push", json={"vocab": [extra]}, headers=auth).status_code == 422


def test_pull_pages_large_changesets(client, auth):
    for start in range(0, 2500, 1000):
        rows = [vocab(word=f"w{i}") for i in range(start, min(start + 1000, 2500))]
        push(client, auth, vocab=rows)
    seen, since, pages = set(), 0, 0
    while True:
        data = pull(client, auth, since)
        seen |= {r["scopedKey"] for r in data["changes"]["vocab"]}
        since, pages = data["cursor"], pages + 1
        if not data["hasMore"]:
            break
    assert len(seen) == 2500 and pages == 3


def test_health(client):
    assert client.get("/health").json()["status"] == "ok"
