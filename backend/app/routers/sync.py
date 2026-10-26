"""Sync API: push local changes, pull remote changes.

Why one sync endpoint pair instead of classic REST CRUD (GET/POST/PUT/DELETE per resource)?
The client is offline-first: it batches many edits made without network and needs "everything
that changed since X" on reconnect. CRUD would need one request per row and has no notion of
"since". Trade-off: less self-describing than REST resources; conflict rules live here.

Conflict rule: last-write-wins per row, by the client-stamped updatedAt.
"""
import logging

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import SYNC_TABLES, User
from ..schemas import Changes, PullResponse, PushResponse
from ..security import current_user

router = APIRouter(prefix="/api/v1/sync", tags=["sync"])
log = logging.getLogger("app.sync")
PULL_LIMIT = 1000
SERVER_ONLY = {"userId", "serverVersion"}


@router.post("/push", response_model=PushResponse)
def push(changes: Changes, user: User = Depends(current_user), db: Session = Depends(get_db)) -> PushResponse:
    # Lock the user row so two devices pushing at once get distinct, ordered versions.
    # (FOR UPDATE on Postgres; SQLite serialises writes anyway.)
    locked = db.scalar(select(User).where(User.id == user.id).with_for_update())
    applied = stale = 0
    for table, (Model, pk) in SYNC_TABLES.items():
        rows = getattr(changes, table)
        if not rows:
            continue
        keys = [getattr(r, pk) for r in rows]
        existing = {
            getattr(m, pk): m
            for m in db.scalars(select(Model).where(Model.userId == user.id, getattr(Model, pk).in_(keys)))
        }
        for row in rows:
            data = row.model_dump()
            current = existing.get(data[pk])
            if current is not None and current.updatedAt > data["updatedAt"]:
                stale += 1  # server copy is newer; client will receive it on pull
                continue
            locked.syncVersion += 1
            if current is None:
                current = Model(userId=user.id, **data, serverVersion=locked.syncVersion)
                db.add(current)
                existing[data[pk]] = current
            else:
                for k, v in data.items():
                    setattr(current, k, v)
                current.serverVersion = locked.syncVersion
            applied += 1
    db.commit()
    log.info("push", extra={"user": user.id, "applied": applied, "stale": stale})
    return PushResponse(applied=applied, stale=stale, cursor=locked.syncVersion)


@router.get("/pull", response_model=PullResponse)
def pull(
    since: int = Query(0, ge=0),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
) -> PullResponse:
    out: dict[str, list[dict]] = {}
    truncated_at: list[int] = []
    for table, (Model, _pk) in SYNC_TABLES.items():
        rows = db.scalars(
            select(Model)
            .where(Model.userId == user.id, Model.serverVersion > since)  # authorization: only your rows
            .order_by(Model.serverVersion)
            .limit(PULL_LIMIT)
        ).all()
        out[table] = [{c.key: getattr(r, c.key) for c in Model.__table__.columns if c.key not in SERVER_ONLY} for r in rows]
        if len(rows) == PULL_LIMIT:
            truncated_at.append(rows[-1].serverVersion)
    # If any table was cut off, the cursor may only advance to the lowest cut-off point.
    # Rows above it may be sent again next time; applying a row twice is harmless (idempotent).
    cursor = min(truncated_at) if truncated_at else db.get(User, user.id).syncVersion
    return PullResponse(changes=Changes.model_validate(out), cursor=cursor, hasMore=bool(truncated_at))
