"""Request/response schemas: this file *is* the API contract (FastAPI turns it into OpenAPI).

Validation happens here, at the edge, so the database layer can trust its input.
"""
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, StringConstraints

# JS Date.toISOString() format. Enforced so string comparison == time comparison.
IsoUtc = Annotated[str, StringConstraints(pattern=r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$")]
VocabStatus = Literal["level1", "level2", "level3", "level4", "known"]
Lang = Annotated[str, StringConstraints(min_length=2, max_length=8)]


class Row(BaseModel):
    # extra="forbid": unknown fields are a client bug, not something to silently store
    model_config = ConfigDict(extra="forbid")
    updatedAt: IsoUtc
    deletedAt: IsoUtc | None = None


class DocumentRow(Row):
    id: Annotated[str, StringConstraints(min_length=1, max_length=36)]
    title: Annotated[str, StringConstraints(max_length=500)]
    body: Annotated[str, StringConstraints(max_length=2_000_000)]
    languageCodeRaw: Lang | None = None
    createdAt: IsoUtc
    sourceTypeRaw: Literal["text", "youtube", "sample"] | None = None
    sourceURL: str | None = None
    sourceVideoID: str | None = None
    sourceChannel: str | None = None
    sourceChannelID: str | None = None
    sourceCategory: str | None = None
    sourceDurationSeconds: int | None = None
    thumbnailURL: str | None = None
    subtitleCuesRaw: str | None = None
    translatedSubtitleCuesRaw: str | None = None
    importModeRaw: str | None = None
    autoBatchID: str | None = None
    firstOpenedAt: IsoUtc | None = None
    lastOpenedAt: IsoUtc | None = None
    readingProgress: float | None = Field(default=None, ge=0, le=1)


class VocabRow(Row):
    scopedKey: Annotated[str, StringConstraints(min_length=3, max_length=300)]
    id: str
    normalizedKey: Annotated[str, StringConstraints(min_length=1, max_length=290)]
    languageCodeRaw: Lang | None = None
    word: str
    meaning: str
    status: VocabStatus
    createdAt: IsoUtc
    lastSeenAt: IsoUtc
    encounterCount: int = Field(ge=0)
    dueAt: IsoUtc | None = None
    srsIntervalDays: float | None = None
    srsEaseFactor: float | None = None
    srsRepetition: int | None = None
    srsLapseCount: int | None = None
    isSuspended: bool | None = None
    srsStability: float | None = None
    srsDifficulty: float | None = None
    srsAlgorithm: str | None = None


class IgnoredRow(Row):
    scopedKey: Annotated[str, StringConstraints(min_length=3, max_length=300)]
    languageCodeRaw: Lang
    normalizedKey: str


class StatsRow(Row):
    scopedKey: Annotated[str, StringConstraints(min_length=3, max_length=32)]
    languageCodeRaw: Lang
    day: Annotated[str, StringConstraints(pattern=r"^\d{4}-\d{2}-\d{2}$")]
    reviewed: int = Field(ge=0)
    correct: int = Field(ge=0)


MAX_BATCH = 1000


class Changes(BaseModel):
    model_config = ConfigDict(extra="forbid")
    documents: list[DocumentRow] = Field(default_factory=list, max_length=MAX_BATCH)
    vocab: list[VocabRow] = Field(default_factory=list, max_length=MAX_BATCH)
    ignored: list[IgnoredRow] = Field(default_factory=list, max_length=MAX_BATCH)
    stats: list[StatsRow] = Field(default_factory=list, max_length=MAX_BATCH)


class PushResponse(BaseModel):
    applied: int
    stale: int
    cursor: int


class PullResponse(BaseModel):
    changes: Changes
    cursor: int
    hasMore: bool


class Credentials(BaseModel):
    email: EmailStr
    password: Annotated[str, StringConstraints(min_length=8, max_length=256)]


class TokenResponse(BaseModel):
    access_token: str
    token_type: Literal["bearer"] = "bearer"


class Me(BaseModel):
    id: str
    email: str


class TranslateResponse(BaseModel):
    text: str
