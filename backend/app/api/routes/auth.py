import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from jose import JWTError
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user,
    hash_password,
    verify_password,
    verify_pin,
)
from app.models.user import User
from app.models.family import Family, FamilyMember
from app.schemas.auth import (
    EmailLoginRequest,
    ForgotPasswordRequest,
    LoginRequest,
    MessageResponse,
    PinLoginRequest,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
    VerifyEmailRequest,
)
from app.schemas.user import UserRead
from app.core.rate_limit import limiter
from app.core.config import get_settings
from app.services.email import get_email_service

router = APIRouter()


def generate_token(length: int = 32) -> str:
    """Generate a secure random token."""
    return secrets.token_urlsafe(length)


@router.post("/register", response_model=MessageResponse)
@limiter.limit("3/minute")
def register(request: Request, payload: RegisterRequest, db: Session = Depends(get_db_session)):
    """Register a new parent account with email/password."""
    # Check if email already exists
    existing = db.query(User).filter(User.email == payload.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ein Konto mit dieser Email existiert bereits",
        )

    # Check if we should auto-verify in dev mode
    settings = get_settings()
    auto_verify = settings.dev_bypass_auth

    # Create user with verification token
    verification_token = generate_token() if not auto_verify else None
    user = User(
        name=payload.name,
        email=payload.email,
        password_hash=hash_password(payload.password),
        pin_hash="",  # Empty for email-only parents (SQLite NOT NULL constraint)
        role="parent",
        email_verified=auto_verify,  # Auto-verify in dev mode
        verification_token=verification_token,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # Send verification email (skip in dev mode)
    if not auto_verify:
        email_service = get_email_service()
        email_service.send_verification_email(
            to=payload.email,
            name=payload.name,
            token=verification_token,
        )
        return MessageResponse(
            message="Registrierung erfolgreich. Bitte bestätige deine Email-Adresse.",
            success=True,
        )
    else:
        return MessageResponse(
            message="Registrierung erfolgreich. (Dev-Mode: Email automatisch verifiziert)",
            success=True,
        )


@router.post("/verify-email", response_model=TokenResponse)
def verify_email(payload: VerifyEmailRequest, db: Session = Depends(get_db_session)):
    """Verify email address with token."""
    user = db.query(User).filter(User.verification_token == payload.token).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ungültiger oder abgelaufener Verifizierungslink",
        )

    # Mark email as verified
    user.email_verified = True
    user.verification_token = None
    db.commit()

    # Return tokens to auto-login
    access_token = create_access_token({"sub": user.id, "role": user.role})
    refresh_token = create_refresh_token({"sub": user.id, "role": user.role})
    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/login/email", response_model=TokenResponse)
@limiter.limit("5/minute")
def login_email(request: Request, payload: EmailLoginRequest, db: Session = Depends(get_db_session)):
    """Login with email and password (for parents)."""
    user = db.query(User).filter(User.email == payload.email).first()
    if not user or not user.password_hash:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Ungültige Anmeldedaten")

    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Ungültige Anmeldedaten")

    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Konto deaktiviert")

    if not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bitte bestätige zuerst deine Email-Adresse",
        )

    # Get user's families for token
    memberships = db.query(FamilyMember).filter(FamilyMember.user_id == user.id).all()
    family_ids = [m.family_id for m in memberships]

    token_data = {"sub": user.id, "role": user.role}
    if family_ids:
        token_data["families"] = family_ids

    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)
    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/login/pin", response_model=TokenResponse)
@limiter.limit("5/minute")
def login_pin(request: Request, payload: PinLoginRequest, db: Session = Depends(get_db_session)):
    """Login with PIN within a family context (for children).

    If user_id is provided, verifies that specific user.
    If user_id is not provided, looks up child by PIN within the family.
    """
    # Find family by invite code
    family = db.query(Family).filter(
        Family.invite_code == payload.family_code,
        Family.is_active == True,
    ).first()
    if not family:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Ungültiger Familiencode")

    user = None
    membership = None

    if payload.user_id:
        # Specific user_id provided - verify that user
        membership = db.query(FamilyMember).filter(
            FamilyMember.family_id == family.id,
            FamilyMember.user_id == payload.user_id,
        ).first()
        if membership:
            user = db.get(User, payload.user_id)
    else:
        # No user_id - find child by PIN within the family
        # Get all family members (children)
        memberships = db.query(FamilyMember).filter(
            FamilyMember.family_id == family.id,
        ).all()

        for m in memberships:
            candidate = db.get(User, m.user_id)
            if candidate and candidate.pin_hash and verify_pin(payload.pin, candidate.pin_hash):
                user = candidate
                membership = m
                break

    if not membership or not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Ungültige Anmeldedaten")

    # Verify PIN (if user_id was provided, we still need to check PIN)
    if payload.user_id and (not user.pin_hash or not verify_pin(payload.pin, user.pin_hash)):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Ungültige Anmeldedaten")

    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Konto deaktiviert")

    access_token = create_access_token({
        "sub": user.id,
        "role": user.role,
        "family_id": family.id,
        "family_role": membership.role_in_family,
    })
    refresh_token = create_refresh_token({
        "sub": user.id,
        "role": user.role,
        "family_id": family.id,
    })
    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/login", response_model=TokenResponse)
@limiter.limit("5/minute")
def login(request: Request, payload: LoginRequest, db: Session = Depends(get_db_session)):
    """Legacy PIN-based login (for backward compatibility)."""
    user = db.get(User, payload.user_id)
    if not user or not user.pin_hash or not verify_pin(payload.pin, user.pin_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    access_token = create_access_token({"sub": user.id, "role": user.role})
    refresh_token = create_refresh_token({"sub": user.id, "role": user.role})
    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/forgot-password", response_model=MessageResponse)
@limiter.limit("3/minute")
def forgot_password(request: Request, payload: ForgotPasswordRequest, db: Session = Depends(get_db_session)):
    """Request password reset email."""
    user = db.query(User).filter(User.email == payload.email).first()

    # Always return success to prevent email enumeration
    if not user or not user.email_verified:
        return MessageResponse(
            message="Falls ein Konto mit dieser Email existiert, wurde ein Link zum Zurücksetzen gesendet.",
            success=True,
        )

    # Generate reset token (valid for 1 hour)
    reset_token = generate_token()
    user.reset_token = reset_token
    user.reset_expires_at = datetime.now(timezone.utc) + timedelta(hours=1)
    db.commit()

    # Send reset email
    email_service = get_email_service()
    email_service.send_password_reset_email(
        to=user.email,
        name=user.name,
        token=reset_token,
    )

    return MessageResponse(
        message="Falls ein Konto mit dieser Email existiert, wurde ein Link zum Zurücksetzen gesendet.",
        success=True,
    )


@router.post("/reset-password", response_model=MessageResponse)
def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db_session)):
    """Complete password reset with token."""
    user = db.query(User).filter(User.reset_token == payload.token).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ungültiger oder abgelaufener Reset-Link",
        )

    # Check expiration
    if user.reset_expires_at and user.reset_expires_at < datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Reset-Link ist abgelaufen",
        )

    # Update password
    user.password_hash = hash_password(payload.new_password)
    user.reset_token = None
    user.reset_expires_at = None
    db.commit()

    return MessageResponse(
        message="Passwort wurde erfolgreich geändert. Du kannst dich jetzt anmelden.",
        success=True,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh(payload: RefreshRequest, db: Session = Depends(get_db_session)):
    try:
        claims = decode_token(payload.refresh_token)
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
    if claims.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
    user_id_raw = claims.get("sub")
    if user_id_raw is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
    try:
        user_id = int(user_id_raw)
    except (TypeError, ValueError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
    user = db.get(User, user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    # Preserve family context if present in original token
    token_data = {"sub": user.id, "role": user.role}
    if "family_id" in claims:
        token_data["family_id"] = claims["family_id"]
    if "families" in claims:
        token_data["families"] = claims["families"]

    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)
    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.get("/me", response_model=UserRead)
def me(user: User = Depends(get_current_user)):
    return user
