import pytest

from app.routers import translate as tr


def test_parse_gtx():
    assert tr.parse_gtx([[["Hello ", "Hallo ", None], ["world", "Welt", None]], None, "de"]) == "Hello world"
    with pytest.raises(ValueError):
        tr.parse_gtx({"error": 1})


def test_translate_uses_cache_and_maps_failures(client, auth, monkeypatch):
    calls = []

    async def fake(q, sl, tl):
        calls.append(q)
        return "street"

    monkeypatch.setattr(tr, "fetch_translation", fake)
    tr._CACHE.clear()
    for _ in range(2):
        assert client.get("/api/v1/translate?q=Straße", headers=auth).json() == {"text": "street"}
    assert calls == ["Straße"]

    async def broken(q, sl, tl):
        raise ValueError("boom")

    monkeypatch.setattr(tr, "fetch_translation", broken)
    assert client.get("/api/v1/translate?q=Haus", headers=auth).status_code == 502
