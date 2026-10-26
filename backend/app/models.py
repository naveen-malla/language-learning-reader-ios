"""Database tables.

Column names deliberately match the Swift/TypeScript field names (camelCase) so one name is used
end to end: iOS model -> web model -> JSON -> Postgres column. Two columns are server-only:
  userId         every row belongs to exactly one user (authorization boundary)
  serverVersion  per-user logical clock, bumped on every accepted write; clients pull "> cursor"
Timestamps are stored as ISO-8601 UTC strings exactly as the client sent them, because the
last-write-wins comparison and the client's own comparisons must agree byte for byte.
"""
import uuid

from sqlalchemy import Boolean, Float, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base

ISO = String(32)


class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    passwordHash: Mapped[str] = mapped_column(String(255))
    createdAt: Mapped[str] = mapped_column(ISO)
    syncVersion: Mapped[int] = mapped_column(Integer, default=0)


class SyncedRow:
    """Columns shared by all synced tables (mixin)."""
    updatedAt: Mapped[str] = mapped_column(ISO)
    deletedAt: Mapped[str | None] = mapped_column(ISO, nullable=True)
    serverVersion: Mapped[int] = mapped_column(Integer, index=True)


def user_fk() -> Mapped[str]:
    return mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)


class Document(SyncedRow, Base):
    __tablename__ = "documents"
    userId: Mapped[str] = user_fk()
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    title: Mapped[str] = mapped_column(Text)
    body: Mapped[str] = mapped_column(Text)
    languageCodeRaw: Mapped[str | None] = mapped_column(String(8), nullable=True)
    createdAt: Mapped[str] = mapped_column(ISO)
    sourceTypeRaw: Mapped[str | None] = mapped_column(String(16), nullable=True)
    sourceURL: Mapped[str | None] = mapped_column(Text, nullable=True)
    sourceVideoID: Mapped[str | None] = mapped_column(String(64), nullable=True)
    sourceChannel: Mapped[str | None] = mapped_column(Text, nullable=True)
    sourceChannelID: Mapped[str | None] = mapped_column(String(64), nullable=True)
    sourceCategory: Mapped[str | None] = mapped_column(Text, nullable=True)
    sourceDurationSeconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    thumbnailURL: Mapped[str | None] = mapped_column(Text, nullable=True)
    subtitleCuesRaw: Mapped[str | None] = mapped_column(Text, nullable=True)
    translatedSubtitleCuesRaw: Mapped[str | None] = mapped_column(Text, nullable=True)
    importModeRaw: Mapped[str | None] = mapped_column(String(32), nullable=True)
    autoBatchID: Mapped[str | None] = mapped_column(String(64), nullable=True)
    firstOpenedAt: Mapped[str | None] = mapped_column(ISO, nullable=True)
    lastOpenedAt: Mapped[str | None] = mapped_column(ISO, nullable=True)
    readingProgress: Mapped[float | None] = mapped_column(Float, nullable=True)

    __table_args__ = (Index("ix_documents_user_version", "userId", "serverVersion"),)


class VocabEntry(SyncedRow, Base):
    __tablename__ = "vocab_entries"
    userId: Mapped[str] = user_fk()
    scopedKey: Mapped[str] = mapped_column(String(300), primary_key=True)
    id: Mapped[str] = mapped_column(String(36))
    normalizedKey: Mapped[str] = mapped_column(String(290))
    languageCodeRaw: Mapped[str | None] = mapped_column(String(8), nullable=True)
    word: Mapped[str] = mapped_column(Text)
    meaning: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(8))
    createdAt: Mapped[str] = mapped_column(ISO)
    lastSeenAt: Mapped[str] = mapped_column(ISO)
    encounterCount: Mapped[int] = mapped_column(Integer)
    dueAt: Mapped[str | None] = mapped_column(ISO, nullable=True)
    srsIntervalDays: Mapped[float | None] = mapped_column(Float, nullable=True)
    srsEaseFactor: Mapped[float | None] = mapped_column(Float, nullable=True)
    srsRepetition: Mapped[int | None] = mapped_column(Integer, nullable=True)
    srsLapseCount: Mapped[int | None] = mapped_column(Integer, nullable=True)
    isSuspended: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    srsStability: Mapped[float | None] = mapped_column(Float, nullable=True)
    srsDifficulty: Mapped[float | None] = mapped_column(Float, nullable=True)
    srsAlgorithm: Mapped[str | None] = mapped_column(String(32), nullable=True)

    __table_args__ = (Index("ix_vocab_user_version", "userId", "serverVersion"),)


class IgnoredWord(SyncedRow, Base):
    __tablename__ = "ignored_words"
    userId: Mapped[str] = user_fk()
    scopedKey: Mapped[str] = mapped_column(String(300), primary_key=True)
    languageCodeRaw: Mapped[str] = mapped_column(String(8))
    normalizedKey: Mapped[str] = mapped_column(String(290))


class FlashcardDailyStat(SyncedRow, Base):
    __tablename__ = "flashcard_daily_stats"
    userId: Mapped[str] = user_fk()
    scopedKey: Mapped[str] = mapped_column(String(32), primary_key=True)
    languageCodeRaw: Mapped[str] = mapped_column(String(8))
    day: Mapped[str] = mapped_column(String(10))
    reviewed: Mapped[int] = mapped_column(Integer)
    correct: Mapped[int] = mapped_column(Integer)


# Sync table name (as used by the client) -> (ORM class, primary-key attribute)
SYNC_TABLES: dict[str, tuple[type, str]] = {
    "documents": (Document, "id"),
    "vocab": (VocabEntry, "scopedKey"),
    "ignored": (IgnoredWord, "scopedKey"),
    "stats": (FlashcardDailyStat, "scopedKey"),
}
