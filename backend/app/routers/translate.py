"""Translation proxy.

Why proxy through our backend instead of calling the translator from the browser?
1. CORS: the translator does not allow browser calls from our origin.
2. Secrets: if we switch to Azure, the API key stays on the server.
3. Control: we can cache, rate-limit and log in one place.
Requires sign-in so the endpoint cannot be used as a free open proxy.
"""
import logging
from collections import OrderedDict

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query

from ..models import User
from ..schemas import TranslateResponse
from ..security import current_user

router = APIRouter(prefix="/api/v1", tags=["translate"])
log = logging.getLogger("app.translate")

_CACHE: "OrderedDict[tuple[str, str, str], str]" = OrderedDict()
_CACHE_MAX = 5000
GTX_URL = "https://translate.googleapis.com/translate_a/single"


def parse_gtx(payload: object) -> str:
    """Same parsing as PublicWebTranslatorClient.parseTranslation in the iOS app."""
    if not isinstance(payload, list) or not payload or not isinstance(payload[0], list):
        raise ValueError("unexpected response shape")
    text = "".join(chunk[0] for chunk in payload[0] if isinstance(chunk, list) and chunk and isinstance(chunk[0], str))
    if not text.strip():
        raise ValueError("empty translation")
    return text.strip()


async def fetch_translation(q: str, sl: str, tl: str) -> str:
    params = {"client": "gtx", "dt": "t", "sl": sl or "auto", "tl": tl, "q": q}
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(GTX_URL, params=params)
        r.raise_for_status()
        return parse_gtx(r.json())


@router.get("/translate", response_model=TranslateResponse)
async def translate(
    q: str = Query(min_length=1, max_length=2000),
    sl: str = Query("de", max_length=8),
    tl: str = Query("en", max_length=8),
    _user: User = Depends(current_user),
) -> TranslateResponse:
    key = (q.strip(), sl, tl)
    if key in _CACHE:
        _CACHE.move_to_end(key)
        return TranslateResponse(text=_CACHE[key])
    try:
        text = await fetch_translation(*key)
    except (httpx.HTTPError, ValueError) as e:
        log.warning("translate failed", extra={"error": str(e)})
        raise HTTPException(502, "Translation service unavailable") from e
    _CACHE[key] = text
    if len(_CACHE) > _CACHE_MAX:
        _CACHE.popitem(last=False)
    return TranslateResponse(text=text)
