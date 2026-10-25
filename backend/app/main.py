"""FastAPI application: wiring, middleware, logging, health check."""
import json
import logging
import time
import uuid

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from .config import get_settings
from .db import Base, SessionLocal, engine
from .routers import auth, sync, translate


class JsonFormatter(logging.Formatter):
    """One JSON object per log line: easy to search in any hosted log viewer."""
    RESERVED = set(vars(logging.LogRecord("", 0, "", 0, "", (), None)))

    def format(self, record: logging.LogRecord) -> str:
        data = {"level": record.levelname, "logger": record.name, "msg": record.getMessage()}
        data.update({k: v for k, v in vars(record).items() if k not in self.RESERVED})
        if record.exc_info:
            data["exc"] = self.formatException(record.exc_info)
        return json.dumps(data, default=str)


def setup_logging(level: str) -> None:
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(level)


def create_app() -> FastAPI:
    settings = get_settings()
    setup_logging(settings.log_level)
    log = logging.getLogger("app")

    # Creates missing tables on startup. Fine for v1; schema *changes* will need migrations (Alembic).
    Base.metadata.create_all(engine)

    app = FastAPI(title="Language Reader API", version="0.1.0")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_methods=["GET", "POST"],
        allow_headers=["Authorization", "Content-Type"],
    )

    @app.middleware("http")
    async def access_log(request: Request, call_next):
        request_id = request.headers.get("x-request-id") or uuid.uuid4().hex[:12]
        start = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            log.exception("unhandled error", extra={"request_id": request_id, "path": request.url.path})
            response = JSONResponse({"detail": "Internal server error", "request_id": request_id}, status_code=500)
        response.headers["x-request-id"] = request_id
        log.info("request", extra={
            "request_id": request_id, "method": request.method, "path": request.url.path,
            "status": response.status_code, "ms": round((time.perf_counter() - start) * 1000, 1),
        })
        return response

    @app.get("/health", tags=["ops"])
    def health() -> dict:
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))
        return {"status": "ok", "environment": settings.environment}

    app.include_router(auth.router)
    app.include_router(sync.router)
    app.include_router(translate.router)
    return app


app = create_app()
