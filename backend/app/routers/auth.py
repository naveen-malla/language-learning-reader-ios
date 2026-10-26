from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..config import get_settings
from ..db import get_db
from ..models import User
from ..schemas import Credentials, Me, TokenResponse
from ..security import create_token, current_user, hash_password, verify_password

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(body: Credentials, db: Session = Depends(get_db)) -> TokenResponse:
    # Personal app: registration can be closed once your account exists. The very first
    # account is always allowed so a fresh deployment is usable.
    has_users = db.scalar(select(func.count()).select_from(User)) > 0
    if has_users and not get_settings().allow_registration:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Registration is closed")
    email = body.email.lower()
    if db.scalar(select(User).where(User.email == email)):
        raise HTTPException(status.HTTP_409_CONFLICT, "Account already exists")
    user = User(email=email, passwordHash=hash_password(body.password),
                createdAt=datetime.now(timezone.utc).isoformat(), syncVersion=0)
    db.add(user)
    db.commit()
    return TokenResponse(access_token=create_token(user.id))


@router.post("/login", response_model=TokenResponse)
def login(body: Credentials, db: Session = Depends(get_db)) -> TokenResponse:
    user = db.scalar(select(User).where(User.email == body.email.lower()))
    # Same message for "no such user" and "wrong password": don't reveal which emails exist.
    if user is None or not verify_password(body.password, user.passwordHash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Wrong email or password")
    return TokenResponse(access_token=create_token(user.id))


@router.get("/me", response_model=Me)
def me(user: User = Depends(current_user)) -> Me:
    return Me(id=user.id, email=user.email)
