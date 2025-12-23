"""Admin API routes for comprehensive system management."""

import logging
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query, status, Body
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import get_current_user, hash_password, verify_password
from app.models.user import User
from app.models.task import Task
from app.models.submission import Submission
from app.models.ledger import TanLedger
from app.models.family import Family, FamilyMember
from app.models.tan_pool import TanPool

router = APIRouter()
logger = logging.getLogger(__name__)


# --- Schemas ---

class UserAdminRead(BaseModel):
    id: int
    name: str
    email: Optional[str]
    role: str
    email_verified: bool
    is_active: bool
    created_at: datetime
    families: List[dict] = []

    class Config:
        from_attributes = True


class UserUpdateRequest(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    role: Optional[str] = None


class PasswordChangeRequest(BaseModel):
    new_password: str = Field(..., min_length=8)


class OwnPasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=8)


class FamilyAdminRead(BaseModel):
    id: int
    name: str
    invite_code: Optional[str]
    is_active: bool
    created_at: datetime
    member_count: int = 0
    members: List[dict] = []

    class Config:
        from_attributes = True


class FamilyCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)


class FamilyMemberAddRequest(BaseModel):
    user_id: int
    role_in_family: str = "parent"


class TaskAdminRead(BaseModel):
    id: int
    title: str
    description: Optional[str]
    tan_reward: int
    target_device: Optional[str]
    is_active: bool
    family_id: Optional[int]
    family_name: Optional[str] = None
    assigned_children: List[int] = []

    class Config:
        from_attributes = True


class SubmissionAdminRead(BaseModel):
    id: int
    task_id: int
    task_title: str
    child_id: int
    child_name: str
    status: str
    photo_path: Optional[str]
    note: Optional[str]
    created_at: datetime
    family_id: Optional[int]

    class Config:
        from_attributes = True


class TanPoolAdminRead(BaseModel):
    id: int
    tan_code: str
    minutes: int
    target_device: str
    is_used: bool
    valid_until: Optional[datetime]
    family_id: Optional[int]
    family_name: Optional[str] = None

    class Config:
        from_attributes = True


class TanPoolCreateRequest(BaseModel):
    tan_code: str
    minutes: int
    target_device: str
    family_id: Optional[int] = None
    valid_until: Optional[datetime] = None


class StatsResponse(BaseModel):
    users_total: int
    users_parents: int
    users_children: int
    users_pending_verification: int
    families_total: int
    tasks_total: int
    tasks_active: int
    submissions_total: int
    submissions_pending: int
    submissions_approved: int
    tan_pool_available: int
    tan_pool_used: int
    minutes_earned_total: int


class LogEntry(BaseModel):
    timestamp: datetime
    type: str
    message: str
    user_id: Optional[int] = None
    user_name: Optional[str] = None


class MessageResponse(BaseModel):
    message: str
    success: bool = True


# --- Helper ---

def require_admin(user: User = Depends(get_current_user)) -> User:
    """Require admin role (currently any parent is admin)."""
    if user.role != "parent":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin-Rechte erforderlich"
        )
    return user


# --- User Endpoints ---

@router.get("/users", response_model=list[UserAdminRead])
def list_users(
    role: Optional[str] = Query(None),
    verified: Optional[bool] = Query(None),
    family_id: Optional[int] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """List all users with their status and family memberships."""
    query = db.query(User)

    if role:
        query = query.filter(User.role == role)
    if verified is not None:
        query = query.filter(User.email_verified == verified)
    if search:
        query = query.filter(or_(
            User.name.ilike(f"%{search}%"),
            User.email.ilike(f"%{search}%")
        ))
    if family_id:
        member_ids = [m.user_id for m in db.query(FamilyMember).filter(FamilyMember.family_id == family_id).all()]
        query = query.filter(User.id.in_(member_ids))

    users = query.order_by(User.created_at.desc()).all()

    result = []
    for user in users:
        memberships = db.query(FamilyMember).filter(FamilyMember.user_id == user.id).all()
        families = []
        for m in memberships:
            family = db.get(Family, m.family_id)
            if family:
                families.append({
                    "id": family.id,
                    "name": family.name,
                    "role": m.role_in_family
                })

        result.append(UserAdminRead(
            id=user.id,
            name=user.name,
            email=user.email,
            role=user.role,
            email_verified=user.email_verified,
            is_active=user.is_active,
            created_at=user.created_at,
            families=families,
        ))

    return result


@router.get("/users/{user_id}", response_model=UserAdminRead)
def get_user(
    user_id: int,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Get single user details."""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User nicht gefunden")

    memberships = db.query(FamilyMember).filter(FamilyMember.user_id == user.id).all()
    families = []
    for m in memberships:
        family = db.get(Family, m.family_id)
        if family:
            families.append({
                "id": family.id,
                "name": family.name,
                "role": m.role_in_family
            })

    return UserAdminRead(
        id=user.id,
        name=user.name,
        email=user.email,
        role=user.role,
        email_verified=user.email_verified,
        is_active=user.is_active,
        created_at=user.created_at,
        families=families,
    )


@router.patch("/users/{user_id}", response_model=MessageResponse)
def update_user(
    user_id: int,
    data: UserUpdateRequest,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Update user details."""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User nicht gefunden")

    if data.name:
        user.name = data.name
    if data.email:
        user.email = data.email
    if data.role:
        user.role = data.role

    db.commit()
    logger.info(f"Admin {admin.id} updated user {user_id}")
    return MessageResponse(message=f"User {user.name} wurde aktualisiert")


@router.post("/users/{user_id}/verify", response_model=MessageResponse)
def verify_user(
    user_id: int,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Manually verify a user's email."""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User nicht gefunden")

    user.email_verified = True
    user.verification_token = None
    db.commit()

    logger.info(f"Admin {admin.id} verified user {user_id}")
    return MessageResponse(message=f"User {user.name} wurde verifiziert")


@router.post("/users/{user_id}/toggle-active", response_model=MessageResponse)
def toggle_user_active(
    user_id: int,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Toggle user active status."""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User nicht gefunden")

    if user.id == admin.id:
        raise HTTPException(status_code=400, detail="Kann eigenen Account nicht deaktivieren")

    user.is_active = not user.is_active
    db.commit()

    status_text = "aktiviert" if user.is_active else "deaktiviert"
    logger.info(f"Admin {admin.id} toggled user {user_id} to {status_text}")
    return MessageResponse(message=f"User {user.name} wurde {status_text}")


@router.post("/users/{user_id}/set-password", response_model=MessageResponse)
def set_user_password(
    user_id: int,
    data: PasswordChangeRequest,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Set a new password for a user (admin only)."""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User nicht gefunden")

    user.password_hash = hash_password(data.new_password)
    db.commit()

    logger.info(f"Admin {admin.id} changed password for user {user_id}")
    return MessageResponse(message=f"Passwort fuer {user.name} wurde geaendert")


@router.post("/change-password", response_model=MessageResponse)
def change_own_password(
    data: OwnPasswordChangeRequest,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Change own password (requires current password)."""
    if not admin.password_hash or not verify_password(data.current_password, admin.password_hash):
        raise HTTPException(status_code=400, detail="Aktuelles Passwort ist falsch")

    admin.password_hash = hash_password(data.new_password)
    db.commit()

    logger.info(f"Admin {admin.id} changed own password")
    return MessageResponse(message="Passwort wurde geaendert")


# --- Family Endpoints ---

@router.get("/families", response_model=list[FamilyAdminRead])
def list_families(
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """List all families."""
    families = db.query(Family).order_by(Family.created_at.desc()).all()

    result = []
    for family in families:
        members = db.query(FamilyMember).filter(FamilyMember.family_id == family.id).all()
        member_list = []
        for m in members:
            user = db.get(User, m.user_id)
            if user:
                member_list.append({
                    "user_id": user.id,
                    "name": user.name,
                    "role": user.role,
                    "role_in_family": m.role_in_family
                })

        result.append(FamilyAdminRead(
            id=family.id,
            name=family.name,
            invite_code=family.invite_code,
            is_active=family.is_active,
            created_at=family.created_at,
            member_count=len(members),
            members=member_list,
        ))

    return result


@router.post("/families", response_model=FamilyAdminRead)
def create_family(
    data: FamilyCreateRequest,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Create a new family."""
    invite_code = secrets.token_urlsafe(8)[:12].upper()

    family = Family(
        name=data.name,
        invite_code=invite_code,
        is_active=True,
    )
    db.add(family)
    db.commit()
    db.refresh(family)

    logger.info(f"Admin {admin.id} created family {family.id}")
    return FamilyAdminRead(
        id=family.id,
        name=family.name,
        invite_code=family.invite_code,
        is_active=family.is_active,
        created_at=family.created_at,
        member_count=0,
        members=[],
    )


@router.post("/families/{family_id}/members", response_model=MessageResponse)
def add_family_member(
    family_id: int,
    data: FamilyMemberAddRequest,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Add a user to a family."""
    family = db.get(Family, family_id)
    if not family:
        raise HTTPException(status_code=404, detail="Familie nicht gefunden")

    user = db.get(User, data.user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User nicht gefunden")

    # Check if already member
    existing = db.query(FamilyMember).filter(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == data.user_id
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="User ist bereits Mitglied")

    member = FamilyMember(
        family_id=family_id,
        user_id=data.user_id,
        role_in_family=data.role_in_family,
    )
    db.add(member)
    db.commit()

    logger.info(f"Admin {admin.id} added user {data.user_id} to family {family_id}")
    return MessageResponse(message=f"{user.name} wurde zur Familie hinzugefuegt")


@router.delete("/families/{family_id}/members/{user_id}", response_model=MessageResponse)
def remove_family_member(
    family_id: int,
    user_id: int,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Remove a user from a family."""
    member = db.query(FamilyMember).filter(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user_id
    ).first()
    if not member:
        raise HTTPException(status_code=404, detail="Mitgliedschaft nicht gefunden")

    user = db.get(User, user_id)
    db.delete(member)
    db.commit()

    logger.info(f"Admin {admin.id} removed user {user_id} from family {family_id}")
    return MessageResponse(message=f"{user.name if user else 'User'} wurde aus der Familie entfernt")


@router.post("/families/{family_id}/regenerate-code", response_model=MessageResponse)
def regenerate_invite_code(
    family_id: int,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Generate a new invite code for a family."""
    family = db.get(Family, family_id)
    if not family:
        raise HTTPException(status_code=404, detail="Familie nicht gefunden")

    family.invite_code = secrets.token_urlsafe(8)[:12].upper()
    db.commit()

    return MessageResponse(message=f"Neuer Code: {family.invite_code}")


# --- Task Endpoints ---

@router.get("/tasks", response_model=list[TaskAdminRead])
def list_tasks(
    family_id: Optional[int] = Query(None),
    active_only: bool = Query(False),
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """List all tasks."""
    query = db.query(Task)

    if family_id:
        query = query.filter(Task.family_id == family_id)
    if active_only:
        query = query.filter(Task.is_active == True)

    tasks = query.order_by(Task.created_at.desc()).all()

    result = []
    for task in tasks:
        family_name = None
        if task.family_id:
            family = db.get(Family, task.family_id)
            family_name = family.name if family else None

        result.append(TaskAdminRead(
            id=task.id,
            title=task.title,
            description=task.description,
            tan_reward=task.tan_reward,
            target_device=task.target_device,
            is_active=task.is_active,
            family_id=task.family_id,
            family_name=family_name,
            assigned_children=task.assigned_children or [],
        ))

    return result


@router.post("/tasks/{task_id}/toggle-active", response_model=MessageResponse)
def toggle_task_active(
    task_id: int,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Toggle task active status."""
    task = db.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task nicht gefunden")

    task.is_active = not task.is_active
    db.commit()

    status_text = "aktiviert" if task.is_active else "deaktiviert"
    return MessageResponse(message=f"Task '{task.title}' wurde {status_text}")


# --- Submission Endpoints ---

@router.get("/submissions", response_model=list[SubmissionAdminRead])
def list_submissions(
    status_filter: Optional[str] = Query(None, alias="status"),
    family_id: Optional[int] = Query(None),
    limit: int = Query(50, le=200),
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """List submissions."""
    query = db.query(Submission)

    if status_filter:
        query = query.filter(Submission.status == status_filter)
    if family_id:
        query = query.filter(Submission.family_id == family_id)

    submissions = query.order_by(Submission.created_at.desc()).limit(limit).all()

    result = []
    for sub in submissions:
        child = db.get(User, sub.child_id)
        task = db.get(Task, sub.task_id)

        result.append(SubmissionAdminRead(
            id=sub.id,
            task_id=sub.task_id,
            task_title=task.title if task else f"Task {sub.task_id}",
            child_id=sub.child_id,
            child_name=child.name if child else f"User {sub.child_id}",
            status=sub.status,
            photo_path=sub.photo_path,
            note=sub.note,
            created_at=sub.created_at,
            family_id=sub.family_id,
        ))

    return result


# --- TAN Pool Endpoints ---

@router.get("/tan-pool", response_model=list[TanPoolAdminRead])
def list_tan_pool(
    family_id: Optional[int] = Query(None),
    available_only: bool = Query(False),
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """List TAN pool entries."""
    query = db.query(TanPool)

    if family_id:
        query = query.filter(TanPool.family_id == family_id)
    if available_only:
        query = query.filter(TanPool.is_used == False)

    tans = query.order_by(TanPool.created_at.desc()).all()

    result = []
    for tan in tans:
        family_name = None
        if tan.family_id:
            family = db.get(Family, tan.family_id)
            family_name = family.name if family else None

        result.append(TanPoolAdminRead(
            id=tan.id,
            tan_code=tan.tan_code,
            minutes=tan.minutes,
            target_device=tan.target_device,
            is_used=tan.is_used,
            valid_until=tan.valid_until,
            family_id=tan.family_id,
            family_name=family_name,
        ))

    return result


@router.post("/tan-pool", response_model=MessageResponse)
def add_tan(
    data: TanPoolCreateRequest,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Add a TAN to the pool."""
    # Check for duplicate
    existing = db.query(TanPool).filter(TanPool.tan_code == data.tan_code).first()
    if existing:
        raise HTTPException(status_code=400, detail="TAN existiert bereits")

    tan = TanPool(
        tan_code=data.tan_code,
        minutes=data.minutes,
        target_device=data.target_device,
        family_id=data.family_id,
        valid_until=data.valid_until,
        is_used=False,
    )
    db.add(tan)
    db.commit()

    return MessageResponse(message=f"TAN {data.tan_code} hinzugefuegt")


@router.delete("/tan-pool/{tan_id}", response_model=MessageResponse)
def delete_tan(
    tan_id: int,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Delete a TAN from the pool."""
    tan = db.get(TanPool, tan_id)
    if not tan:
        raise HTTPException(status_code=404, detail="TAN nicht gefunden")

    if tan.is_used:
        raise HTTPException(status_code=400, detail="Verwendete TANs koennen nicht geloescht werden")

    db.delete(tan)
    db.commit()

    return MessageResponse(message="TAN geloescht")


# --- Stats & Logs ---

@router.get("/stats", response_model=StatsResponse)
def get_stats(
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Get system statistics."""
    users_total = db.query(User).count()
    users_parents = db.query(User).filter(User.role == "parent").count()
    users_children = db.query(User).filter(User.role == "child").count()
    users_pending = db.query(User).filter(
        User.email_verified == False,
        User.email.isnot(None)
    ).count()

    families_total = db.query(Family).filter(Family.is_active == True).count()

    tasks_total = db.query(Task).count()
    tasks_active = db.query(Task).filter(Task.is_active == True).count()

    submissions_total = db.query(Submission).count()
    submissions_pending = db.query(Submission).filter(Submission.status == "pending").count()
    submissions_approved = db.query(Submission).filter(Submission.status == "approved").count()

    tan_pool_available = db.query(TanPool).filter(TanPool.is_used == False).count()
    tan_pool_used = db.query(TanPool).filter(TanPool.is_used == True).count()

    minutes_result = db.query(func.sum(TanLedger.minutes)).scalar()
    minutes_earned_total = minutes_result or 0

    return StatsResponse(
        users_total=users_total,
        users_parents=users_parents,
        users_children=users_children,
        users_pending_verification=users_pending,
        families_total=families_total,
        tasks_total=tasks_total,
        tasks_active=tasks_active,
        submissions_total=submissions_total,
        submissions_pending=submissions_pending,
        submissions_approved=submissions_approved,
        tan_pool_available=tan_pool_available,
        tan_pool_used=tan_pool_used,
        minutes_earned_total=minutes_earned_total,
    )


@router.get("/logs", response_model=list[LogEntry])
def get_logs(
    limit: int = Query(50, le=200),
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Get recent activity logs."""
    logs = []

    recent_users = db.query(User).order_by(User.created_at.desc()).limit(limit // 2).all()
    for user in recent_users:
        logs.append(LogEntry(
            timestamp=user.created_at,
            type="registration",
            message=f"Neuer User: {user.name} ({user.role})",
            user_id=user.id,
            user_name=user.name,
        ))

    recent_subs = db.query(Submission).order_by(Submission.created_at.desc()).limit(limit // 2).all()
    for sub in recent_subs:
        child = db.get(User, sub.child_id)
        task = db.get(Task, sub.task_id)
        child_name = child.name if child else f"User {sub.child_id}"
        task_title = task.title if task else f"Task {sub.task_id}"

        if sub.status == "pending":
            msg = f"{child_name}: '{task_title}' eingereicht"
        elif sub.status == "approved":
            msg = f"'{task_title}' von {child_name} genehmigt"
        elif sub.status == "rejected":
            msg = f"'{task_title}' von {child_name} abgelehnt"
        else:
            msg = f"{child_name}: {sub.status}"

        logs.append(LogEntry(
            timestamp=sub.created_at,
            type=f"submission_{sub.status}",
            message=msg,
            user_id=sub.child_id,
            user_name=child_name,
        ))

    logs.sort(key=lambda x: x.timestamp, reverse=True)
    return logs[:limit]


# --- Admin UI ---

ADMIN_HTML = """
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ZeitSchatz Admin</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f0f1a; color: #e0e0e0; }
        .container { max-width: 1400px; margin: 0 auto; padding: 20px; }
        h1 { color: #4CAF50; margin-bottom: 20px; display: flex; align-items: center; gap: 15px; }
        h2 { color: #64b5f6; margin: 15px 0 10px; font-size: 1.2em; }
        h3 { color: #90caf9; margin: 10px 0; font-size: 1em; }

        /* Login */
        .login-form { background: #1a1a2e; padding: 40px; border-radius: 12px; max-width: 400px; margin: 80px auto; }
        .login-form h1 { justify-content: center; margin-bottom: 30px; }
        .login-form input { width: 100%; padding: 14px; margin: 8px 0; border: 1px solid #333; border-radius: 6px; background: #0f0f1a; color: #e0e0e0; font-size: 16px; }
        .login-form button { width: 100%; padding: 14px; background: #4CAF50; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 16px; margin-top: 15px; }
        .login-form button:hover { background: #45a049; }

        /* Header */
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; padding-bottom: 15px; border-bottom: 1px solid #333; }
        .header-actions { display: flex; gap: 10px; }

        /* Tabs */
        .tabs { display: flex; gap: 5px; margin-bottom: 20px; flex-wrap: wrap; background: #1a1a2e; padding: 8px; border-radius: 8px; }
        .tab { padding: 10px 18px; background: transparent; border: none; color: #888; cursor: pointer; border-radius: 6px; font-size: 14px; transition: all 0.2s; }
        .tab:hover { background: #252540; color: #e0e0e0; }
        .tab.active { background: #4CAF50; color: white; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }

        /* Stats Grid */
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; margin-bottom: 20px; }
        .stat-card { background: #1a1a2e; padding: 20px; border-radius: 10px; text-align: center; }
        .stat-value { font-size: 2.2em; font-weight: bold; color: #4CAF50; }
        .stat-label { color: #888; margin-top: 5px; font-size: 0.9em; }

        /* Tables */
        table { width: 100%; border-collapse: collapse; background: #1a1a2e; border-radius: 10px; overflow: hidden; }
        th, td { padding: 12px 15px; text-align: left; border-bottom: 1px solid #252540; }
        th { background: #252540; color: #64b5f6; font-weight: 600; position: sticky; top: 0; }
        tr:hover { background: #252540; }

        /* Badges */
        .badge { padding: 4px 10px; border-radius: 20px; font-size: 0.75em; font-weight: 500; }
        .badge-success { background: #1b5e20; color: #a5d6a7; }
        .badge-warning { background: #e65100; color: #ffcc80; }
        .badge-danger { background: #b71c1c; color: #ef9a9a; }
        .badge-info { background: #0d47a1; color: #90caf9; }
        .badge-secondary { background: #37474f; color: #b0bec5; }

        /* Buttons */
        .btn { padding: 6px 12px; border: none; border-radius: 4px; cursor: pointer; font-size: 13px; transition: opacity 0.2s; }
        .btn:hover { opacity: 0.85; }
        .btn-primary { background: #2196F3; color: white; }
        .btn-success { background: #4CAF50; color: white; }
        .btn-warning { background: #ff9800; color: black; }
        .btn-danger { background: #f44336; color: white; }
        .btn-secondary { background: #546e7a; color: white; }
        .btn-sm { padding: 4px 8px; font-size: 12px; }

        /* Forms */
        .form-group { margin-bottom: 15px; }
        .form-group label { display: block; margin-bottom: 5px; color: #90caf9; font-size: 0.9em; }
        .form-control { width: 100%; padding: 10px; border: 1px solid #333; border-radius: 6px; background: #0f0f1a; color: #e0e0e0; font-size: 14px; }
        .form-control:focus { outline: none; border-color: #4CAF50; }
        select.form-control { cursor: pointer; }

        /* Cards */
        .card { background: #1a1a2e; border-radius: 10px; padding: 20px; margin-bottom: 15px; }
        .card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; }

        /* Modal */
        .modal { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.7); z-index: 1000; }
        .modal.active { display: flex; align-items: center; justify-content: center; }
        .modal-content { background: #1a1a2e; padding: 25px; border-radius: 12px; max-width: 500px; width: 90%; max-height: 80vh; overflow-y: auto; }
        .modal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
        .modal-header h3 { margin: 0; }
        .modal-close { background: none; border: none; color: #888; font-size: 24px; cursor: pointer; }
        .modal-footer { margin-top: 20px; display: flex; gap: 10px; justify-content: flex-end; }

        /* Lists */
        .list-item { padding: 12px; border-bottom: 1px solid #252540; display: flex; justify-content: space-between; align-items: center; }
        .list-item:last-child { border-bottom: none; }

        /* Logs */
        .log-entry { padding: 10px 15px; border-bottom: 1px solid #252540; }
        .log-time { color: #666; font-size: 0.85em; margin-right: 10px; }

        /* Toolbar */
        .toolbar { display: flex; gap: 10px; margin-bottom: 15px; flex-wrap: wrap; align-items: center; }
        .toolbar .form-control { width: auto; min-width: 150px; }

        /* Utility */
        .hidden { display: none !important; }
        .error { color: #f44336; margin: 10px 0; padding: 10px; background: #2d1515; border-radius: 6px; }
        .success { color: #4CAF50; margin: 10px 0; padding: 10px; background: #1b2e1b; border-radius: 6px; }
        .text-muted { color: #666; }
        .text-small { font-size: 0.85em; }
        .mb-10 { margin-bottom: 10px; }
        .mt-10 { margin-top: 10px; }
        .flex { display: flex; }
        .gap-5 { gap: 5px; }
        .gap-10 { gap: 10px; }

        /* Family chips */
        .family-chip { display: inline-block; padding: 2px 8px; background: #37474f; border-radius: 12px; font-size: 0.75em; margin: 2px; }

        /* Responsive */
        @media (max-width: 768px) {
            .tabs { flex-direction: column; }
            .toolbar { flex-direction: column; align-items: stretch; }
            .toolbar .form-control { width: 100%; }
            th, td { padding: 8px; font-size: 0.9em; }
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Login -->
        <div id="loginSection" class="login-form">
            <h1>ZeitSchatz Admin</h1>
            <input type="email" id="email" placeholder="Email" autocomplete="email">
            <input type="password" id="password" placeholder="Passwort" autocomplete="current-password">
            <div id="loginError" class="error hidden"></div>
            <button onclick="login()">Anmelden</button>
        </div>

        <!-- Dashboard -->
        <div id="dashboard" class="hidden">
            <div class="header">
                <h1>ZeitSchatz Admin</h1>
                <div class="header-actions">
                    <button class="btn btn-secondary" onclick="showModal('settingsModal')">Einstellungen</button>
                    <button class="btn btn-primary" onclick="loadAll()">Aktualisieren</button>
                    <button class="btn btn-danger" onclick="logout()">Abmelden</button>
                </div>
            </div>

            <div class="tabs">
                <button class="tab active" onclick="showTab('stats')">Dashboard</button>
                <button class="tab" onclick="showTab('users')">Benutzer</button>
                <button class="tab" onclick="showTab('families')">Familien</button>
                <button class="tab" onclick="showTab('tasks')">Aufgaben</button>
                <button class="tab" onclick="showTab('submissions')">Einreichungen</button>
                <button class="tab" onclick="showTab('tanpool')">TAN-Pool</button>
                <button class="tab" onclick="showTab('logs')">Aktivitaeten</button>
            </div>

            <!-- Stats Tab -->
            <div id="statsTab" class="tab-content active">
                <div id="statsGrid" class="stats-grid"></div>
            </div>

            <!-- Users Tab -->
            <div id="usersTab" class="tab-content">
                <div class="toolbar">
                    <input type="text" class="form-control" id="userSearch" placeholder="Suchen..." onkeyup="loadUsers()">
                    <select class="form-control" id="userRoleFilter" onchange="loadUsers()">
                        <option value="">Alle Rollen</option>
                        <option value="parent">Eltern</option>
                        <option value="child">Kinder</option>
                    </select>
                    <select class="form-control" id="userFamilyFilter" onchange="loadUsers()">
                        <option value="">Alle Familien</option>
                    </select>
                </div>
                <table>
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Name</th>
                            <th>Email</th>
                            <th>Rolle</th>
                            <th>Familien</th>
                            <th>Status</th>
                            <th>Aktionen</th>
                        </tr>
                    </thead>
                    <tbody id="usersTable"></tbody>
                </table>
            </div>

            <!-- Families Tab -->
            <div id="familiesTab" class="tab-content">
                <div class="toolbar">
                    <button class="btn btn-success" onclick="showModal('createFamilyModal')">+ Neue Familie</button>
                </div>
                <div id="familiesList"></div>
            </div>

            <!-- Tasks Tab -->
            <div id="tasksTab" class="tab-content">
                <div class="toolbar">
                    <select class="form-control" id="taskFamilyFilter" onchange="loadTasks()">
                        <option value="">Alle Familien</option>
                    </select>
                    <label style="display:flex;align-items:center;gap:5px;color:#888;">
                        <input type="checkbox" id="taskActiveFilter" onchange="loadTasks()"> Nur aktive
                    </label>
                </div>
                <table>
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Titel</th>
                            <th>Belohnung</th>
                            <th>Geraet</th>
                            <th>Familie</th>
                            <th>Status</th>
                            <th>Aktionen</th>
                        </tr>
                    </thead>
                    <tbody id="tasksTable"></tbody>
                </table>
            </div>

            <!-- Submissions Tab -->
            <div id="submissionsTab" class="tab-content">
                <div class="toolbar">
                    <select class="form-control" id="submissionStatusFilter" onchange="loadSubmissions()">
                        <option value="">Alle Status</option>
                        <option value="pending">Ausstehend</option>
                        <option value="approved">Genehmigt</option>
                        <option value="rejected">Abgelehnt</option>
                    </select>
                </div>
                <table>
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Aufgabe</th>
                            <th>Kind</th>
                            <th>Status</th>
                            <th>Datum</th>
                            <th>Notiz</th>
                        </tr>
                    </thead>
                    <tbody id="submissionsTable"></tbody>
                </table>
            </div>

            <!-- TAN Pool Tab -->
            <div id="tanpoolTab" class="tab-content">
                <div class="toolbar">
                    <button class="btn btn-success" onclick="showModal('addTanModal')">+ TAN hinzufuegen</button>
                    <select class="form-control" id="tanFamilyFilter" onchange="loadTanPool()">
                        <option value="">Alle Familien</option>
                    </select>
                    <label style="display:flex;align-items:center;gap:5px;color:#888;">
                        <input type="checkbox" id="tanAvailableFilter" onchange="loadTanPool()"> Nur verfuegbare
                    </label>
                </div>
                <table>
                    <thead>
                        <tr>
                            <th>Code</th>
                            <th>Minuten</th>
                            <th>Geraet</th>
                            <th>Familie</th>
                            <th>Status</th>
                            <th>Gueltig bis</th>
                            <th>Aktionen</th>
                        </tr>
                    </thead>
                    <tbody id="tanPoolTable"></tbody>
                </table>
            </div>

            <!-- Logs Tab -->
            <div id="logsTab" class="tab-content">
                <div id="logsList"></div>
            </div>
        </div>

        <!-- Modals -->
        <div id="settingsModal" class="modal">
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Einstellungen</h3>
                    <button class="modal-close" onclick="closeModal('settingsModal')">&times;</button>
                </div>
                <h3>Passwort aendern</h3>
                <div class="form-group">
                    <label>Aktuelles Passwort</label>
                    <input type="password" class="form-control" id="currentPassword">
                </div>
                <div class="form-group">
                    <label>Neues Passwort</label>
                    <input type="password" class="form-control" id="newPassword">
                </div>
                <div class="form-group">
                    <label>Passwort bestaetigen</label>
                    <input type="password" class="form-control" id="confirmPassword">
                </div>
                <div id="settingsMessage"></div>
                <div class="modal-footer">
                    <button class="btn btn-secondary" onclick="closeModal('settingsModal')">Abbrechen</button>
                    <button class="btn btn-primary" onclick="changeOwnPassword()">Speichern</button>
                </div>
            </div>
        </div>

        <div id="userModal" class="modal">
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Benutzer bearbeiten</h3>
                    <button class="modal-close" onclick="closeModal('userModal')">&times;</button>
                </div>
                <div class="form-group">
                    <label>Name</label>
                    <input type="text" class="form-control" id="editUserName">
                </div>
                <div class="form-group">
                    <label>Email</label>
                    <input type="email" class="form-control" id="editUserEmail">
                </div>
                <div class="form-group">
                    <label>Rolle</label>
                    <select class="form-control" id="editUserRole">
                        <option value="parent">Eltern</option>
                        <option value="child">Kind</option>
                    </select>
                </div>
                <hr style="border-color:#333;margin:20px 0;">
                <h3>Neues Passwort setzen</h3>
                <div class="form-group">
                    <label>Neues Passwort (leer lassen um nicht zu aendern)</label>
                    <input type="password" class="form-control" id="editUserPassword">
                </div>
                <hr style="border-color:#333;margin:20px 0;">
                <h3>Familien-Zuordnung</h3>
                <div id="userFamilies" class="mb-10"></div>
                <div class="flex gap-5">
                    <select class="form-control" id="addToFamilySelect" style="flex:1;"></select>
                    <button class="btn btn-success btn-sm" onclick="addUserToFamily()">Hinzufuegen</button>
                </div>
                <div id="userModalMessage" class="mt-10"></div>
                <input type="hidden" id="editUserId">
                <div class="modal-footer">
                    <button class="btn btn-secondary" onclick="closeModal('userModal')">Schliessen</button>
                    <button class="btn btn-primary" onclick="saveUser()">Speichern</button>
                </div>
            </div>
        </div>

        <div id="createFamilyModal" class="modal">
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Neue Familie erstellen</h3>
                    <button class="modal-close" onclick="closeModal('createFamilyModal')">&times;</button>
                </div>
                <div class="form-group">
                    <label>Familienname</label>
                    <input type="text" class="form-control" id="newFamilyName">
                </div>
                <div id="createFamilyMessage"></div>
                <div class="modal-footer">
                    <button class="btn btn-secondary" onclick="closeModal('createFamilyModal')">Abbrechen</button>
                    <button class="btn btn-success" onclick="createFamily()">Erstellen</button>
                </div>
            </div>
        </div>

        <div id="addTanModal" class="modal">
            <div class="modal-content">
                <div class="modal-header">
                    <h3>TAN hinzufuegen</h3>
                    <button class="modal-close" onclick="closeModal('addTanModal')">&times;</button>
                </div>
                <div class="form-group">
                    <label>TAN Code</label>
                    <input type="text" class="form-control" id="newTanCode">
                </div>
                <div class="form-group">
                    <label>Minuten</label>
                    <input type="number" class="form-control" id="newTanMinutes" value="30">
                </div>
                <div class="form-group">
                    <label>Geraet</label>
                    <select class="form-control" id="newTanDevice">
                        <option value="phone">Handy</option>
                        <option value="pc">PC</option>
                        <option value="tablet">Tablet</option>
                        <option value="console">Konsole</option>
                    </select>
                </div>
                <div class="form-group">
                    <label>Familie (optional)</label>
                    <select class="form-control" id="newTanFamily">
                        <option value="">Keine Familie</option>
                    </select>
                </div>
                <div id="addTanMessage"></div>
                <div class="modal-footer">
                    <button class="btn btn-secondary" onclick="closeModal('addTanModal')">Abbrechen</button>
                    <button class="btn btn-success" onclick="addTan()">Hinzufuegen</button>
                </div>
            </div>
        </div>
    </div>

    <script>
        let token = localStorage.getItem('adminToken');
        const API = window.location.origin;
        let families = [];
        let users = [];
        let currentEditUser = null;

        if (token) showDashboard();

        async function login() {
            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;
            const errorDiv = document.getElementById('loginError');
            try {
                const res = await fetch(`${API}/auth/login/email`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email, password })
                });
                if (!res.ok) {
                    const err = await res.json();
                    throw new Error(err.detail || 'Login fehlgeschlagen');
                }
                const data = await res.json();
                token = data.access_token;
                localStorage.setItem('adminToken', token);
                showDashboard();
            } catch (e) {
                errorDiv.textContent = e.message;
                errorDiv.classList.remove('hidden');
            }
        }

        function logout() {
            localStorage.removeItem('adminToken');
            location.reload();
        }

        function showDashboard() {
            document.getElementById('loginSection').classList.add('hidden');
            document.getElementById('dashboard').classList.remove('hidden');
            loadAll();
        }

        async function api(endpoint, options = {}) {
            const res = await fetch(`${API}${endpoint}`, {
                ...options,
                headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json', ...options.headers }
            });
            if (res.status === 401) { logout(); return null; }
            return res.json();
        }

        async function loadAll() {
            await loadFamilies();
            await Promise.all([loadStats(), loadUsers(), loadTasks(), loadSubmissions(), loadTanPool(), loadLogs()]);
            populateFamilyFilters();
        }

        async function loadFamilies() {
            families = await api('/admin/families') || [];
            renderFamilies();
        }

        function populateFamilyFilters() {
            const selects = ['userFamilyFilter', 'taskFamilyFilter', 'tanFamilyFilter', 'addToFamilySelect', 'newTanFamily'];
            selects.forEach(id => {
                const el = document.getElementById(id);
                if (!el) return;
                const firstOpt = el.options[0]?.outerHTML || '';
                el.innerHTML = firstOpt + families.map(f => `<option value="${f.id}">${f.name}</option>`).join('');
            });
        }

        async function loadStats() {
            const stats = await api('/admin/stats');
            if (!stats) return;
            document.getElementById('statsGrid').innerHTML = `
                <div class="stat-card"><div class="stat-value">${stats.users_total}</div><div class="stat-label">Benutzer</div></div>
                <div class="stat-card"><div class="stat-value">${stats.users_parents}</div><div class="stat-label">Eltern</div></div>
                <div class="stat-card"><div class="stat-value">${stats.users_children}</div><div class="stat-label">Kinder</div></div>
                <div class="stat-card"><div class="stat-value">${stats.families_total}</div><div class="stat-label">Familien</div></div>
                <div class="stat-card"><div class="stat-value">${stats.tasks_active}</div><div class="stat-label">Aktive Aufgaben</div></div>
                <div class="stat-card"><div class="stat-value">${stats.submissions_pending}</div><div class="stat-label">Offene Einreichungen</div></div>
                <div class="stat-card"><div class="stat-value">${stats.tan_pool_available}</div><div class="stat-label">Verf. TANs</div></div>
                <div class="stat-card"><div class="stat-value">${stats.minutes_earned_total}</div><div class="stat-label">Minuten verdient</div></div>
            `;
        }

        async function loadUsers() {
            const search = document.getElementById('userSearch')?.value || '';
            const role = document.getElementById('userRoleFilter')?.value || '';
            const family = document.getElementById('userFamilyFilter')?.value || '';
            let url = '/admin/users?';
            if (search) url += `search=${encodeURIComponent(search)}&`;
            if (role) url += `role=${role}&`;
            if (family) url += `family_id=${family}&`;
            users = await api(url) || [];
            document.getElementById('usersTable').innerHTML = users.map(u => `
                <tr>
                    <td>${u.id}</td>
                    <td>${u.name}</td>
                    <td>${u.email || '<span class="text-muted">-</span>'}</td>
                    <td><span class="badge ${u.role === 'parent' ? 'badge-info' : 'badge-success'}">${u.role}</span></td>
                    <td>${u.families.map(f => `<span class="family-chip">${f.name}</span>`).join('') || '<span class="text-muted">-</span>'}</td>
                    <td>
                        ${u.email_verified ? '<span class="badge badge-success">Verifiziert</span>' : u.email ? '<span class="badge badge-warning">Ausstehend</span>' : ''}
                        ${!u.is_active ? '<span class="badge badge-danger">Inaktiv</span>' : ''}
                    </td>
                    <td>
                        <button class="btn btn-primary btn-sm" onclick="editUser(${u.id})">Bearbeiten</button>
                        ${!u.email_verified && u.email ? `<button class="btn btn-success btn-sm" onclick="verifyUser(${u.id})">Verifizieren</button>` : ''}
                        <button class="btn btn-warning btn-sm" onclick="toggleUser(${u.id})">${u.is_active ? 'Deaktiv.' : 'Aktivieren'}</button>
                    </td>
                </tr>
            `).join('');
        }

        function renderFamilies() {
            document.getElementById('familiesList').innerHTML = families.map(f => `
                <div class="card">
                    <div class="card-header">
                        <div>
                            <strong style="font-size:1.1em;">${f.name}</strong>
                            <span class="text-muted text-small" style="margin-left:10px;">ID: ${f.id}</span>
                            ${!f.is_active ? '<span class="badge badge-danger" style="margin-left:10px;">Inaktiv</span>' : ''}
                        </div>
                        <div class="flex gap-5">
                            <span class="text-muted">Code: <strong>${f.invite_code || '-'}</strong></span>
                            <button class="btn btn-secondary btn-sm" onclick="regenerateCode(${f.id})">Neuer Code</button>
                        </div>
                    </div>
                    <h3>Mitglieder (${f.member_count})</h3>
                    ${f.members.length ? f.members.map(m => `
                        <div class="list-item">
                            <span>${m.name} <span class="badge ${m.role === 'parent' ? 'badge-info' : 'badge-success'}">${m.role}</span> <span class="text-muted text-small">(${m.role_in_family})</span></span>
                            <button class="btn btn-danger btn-sm" onclick="removeMember(${f.id}, ${m.user_id})">Entfernen</button>
                        </div>
                    `).join('') : '<p class="text-muted" style="padding:10px;">Keine Mitglieder</p>'}
                </div>
            `).join('');
        }

        async function loadTasks() {
            const family = document.getElementById('taskFamilyFilter')?.value || '';
            const active = document.getElementById('taskActiveFilter')?.checked;
            let url = '/admin/tasks?';
            if (family) url += `family_id=${family}&`;
            if (active) url += 'active_only=true&';
            const tasks = await api(url) || [];
            document.getElementById('tasksTable').innerHTML = tasks.map(t => `
                <tr>
                    <td>${t.id}</td>
                    <td>${t.title}</td>
                    <td>${t.tan_reward} Min</td>
                    <td>${t.target_device || '-'}</td>
                    <td>${t.family_name || '<span class="text-muted">-</span>'}</td>
                    <td><span class="badge ${t.is_active ? 'badge-success' : 'badge-secondary'}">${t.is_active ? 'Aktiv' : 'Inaktiv'}</span></td>
                    <td><button class="btn btn-warning btn-sm" onclick="toggleTask(${t.id})">${t.is_active ? 'Deaktiv.' : 'Aktivieren'}</button></td>
                </tr>
            `).join('');
        }

        async function loadSubmissions() {
            const status = document.getElementById('submissionStatusFilter')?.value || '';
            let url = '/admin/submissions?';
            if (status) url += `status=${status}&`;
            const subs = await api(url) || [];
            document.getElementById('submissionsTable').innerHTML = subs.map(s => `
                <tr>
                    <td>${s.id}</td>
                    <td>${s.task_title}</td>
                    <td>${s.child_name}</td>
                    <td><span class="badge ${s.status === 'approved' ? 'badge-success' : s.status === 'rejected' ? 'badge-danger' : 'badge-warning'}">${s.status}</span></td>
                    <td>${new Date(s.created_at).toLocaleString('de-DE')}</td>
                    <td>${s.note || '-'}</td>
                </tr>
            `).join('');
        }

        async function loadTanPool() {
            const family = document.getElementById('tanFamilyFilter')?.value || '';
            const available = document.getElementById('tanAvailableFilter')?.checked;
            let url = '/admin/tan-pool?';
            if (family) url += `family_id=${family}&`;
            if (available) url += 'available_only=true&';
            const tans = await api(url) || [];
            document.getElementById('tanPoolTable').innerHTML = tans.map(t => `
                <tr>
                    <td><code>${t.tan_code}</code></td>
                    <td>${t.minutes}</td>
                    <td>${t.target_device}</td>
                    <td>${t.family_name || '-'}</td>
                    <td><span class="badge ${t.is_used ? 'badge-secondary' : 'badge-success'}">${t.is_used ? 'Verwendet' : 'Verfuegbar'}</span></td>
                    <td>${t.valid_until ? new Date(t.valid_until).toLocaleDateString('de-DE') : '-'}</td>
                    <td>${!t.is_used ? `<button class="btn btn-danger btn-sm" onclick="deleteTan(${t.id})">Loeschen</button>` : ''}</td>
                </tr>
            `).join('');
        }

        async function loadLogs() {
            const logs = await api('/admin/logs?limit=100') || [];
            document.getElementById('logsList').innerHTML = logs.map(log => {
                const cls = log.type.includes('approved') ? 'badge-success' : log.type.includes('rejected') ? 'badge-danger' : log.type.includes('registration') ? 'badge-info' : 'badge-warning';
                return `<div class="log-entry"><span class="log-time">${new Date(log.timestamp).toLocaleString('de-DE')}</span><span class="badge ${cls}">${log.type}</span> ${log.message}</div>`;
            }).join('');
        }

        // Actions
        async function verifyUser(id) { await api(`/admin/users/${id}/verify`, { method: 'POST' }); loadUsers(); }
        async function toggleUser(id) { await api(`/admin/users/${id}/toggle-active`, { method: 'POST' }); loadUsers(); }
        async function toggleTask(id) { await api(`/admin/tasks/${id}/toggle-active`, { method: 'POST' }); loadTasks(); }
        async function regenerateCode(id) { const r = await api(`/admin/families/${id}/regenerate-code`, { method: 'POST' }); if (r) alert(r.message); loadFamilies(); }
        async function removeMember(fid, uid) { if (confirm('Wirklich entfernen?')) { await api(`/admin/families/${fid}/members/${uid}`, { method: 'DELETE' }); loadFamilies(); } }
        async function deleteTan(id) { if (confirm('TAN loeschen?')) { await api(`/admin/tan-pool/${id}`, { method: 'DELETE' }); loadTanPool(); } }

        async function editUser(id) {
            currentEditUser = users.find(u => u.id === id);
            if (!currentEditUser) return;
            document.getElementById('editUserId').value = id;
            document.getElementById('editUserName').value = currentEditUser.name;
            document.getElementById('editUserEmail').value = currentEditUser.email || '';
            document.getElementById('editUserRole').value = currentEditUser.role;
            document.getElementById('editUserPassword').value = '';
            document.getElementById('userModalMessage').innerHTML = '';
            renderUserFamilies();
            showModal('userModal');
        }

        function renderUserFamilies() {
            if (!currentEditUser) return;
            const container = document.getElementById('userFamilies');
            container.innerHTML = currentEditUser.families.length ? currentEditUser.families.map(f => `
                <div class="list-item">
                    <span>${f.name} <span class="text-muted">(${f.role})</span></span>
                    <button class="btn btn-danger btn-sm" onclick="removeUserFromFamily(${f.id})">Entfernen</button>
                </div>
            `).join('') : '<p class="text-muted">Keine Familien zugeordnet</p>';
        }

        async function saveUser() {
            const id = document.getElementById('editUserId').value;
            const data = {
                name: document.getElementById('editUserName').value,
                email: document.getElementById('editUserEmail').value || null,
                role: document.getElementById('editUserRole').value
            };
            await api(`/admin/users/${id}`, { method: 'PATCH', body: JSON.stringify(data) });

            const newPw = document.getElementById('editUserPassword').value;
            if (newPw) {
                await api(`/admin/users/${id}/set-password`, { method: 'POST', body: JSON.stringify({ new_password: newPw }) });
            }

            closeModal('userModal');
            loadUsers();
        }

        async function addUserToFamily() {
            const familyId = document.getElementById('addToFamilySelect').value;
            const userId = document.getElementById('editUserId').value;
            if (!familyId) return;
            const r = await api(`/admin/families/${familyId}/members`, { method: 'POST', body: JSON.stringify({ user_id: parseInt(userId), role_in_family: currentEditUser.role === 'parent' ? 'parent' : 'child' }) });
            if (r && r.success !== false) {
                currentEditUser.families.push({ id: parseInt(familyId), name: families.find(f => f.id == familyId)?.name, role: currentEditUser.role === 'parent' ? 'parent' : 'child' });
                renderUserFamilies();
                document.getElementById('userModalMessage').innerHTML = '<div class="success">Hinzugefuegt!</div>';
            } else {
                document.getElementById('userModalMessage').innerHTML = `<div class="error">${r?.message || 'Fehler'}</div>`;
            }
        }

        async function removeUserFromFamily(familyId) {
            const userId = document.getElementById('editUserId').value;
            await api(`/admin/families/${familyId}/members/${userId}`, { method: 'DELETE' });
            currentEditUser.families = currentEditUser.families.filter(f => f.id !== familyId);
            renderUserFamilies();
        }

        async function createFamily() {
            const name = document.getElementById('newFamilyName').value.trim();
            if (!name) return;
            const r = await api('/admin/families', { method: 'POST', body: JSON.stringify({ name }) });
            if (r && r.id) {
                document.getElementById('createFamilyMessage').innerHTML = `<div class="success">Familie erstellt! Code: ${r.invite_code}</div>`;
                document.getElementById('newFamilyName').value = '';
                loadFamilies();
                setTimeout(() => closeModal('createFamilyModal'), 2000);
            }
        }

        async function addTan() {
            const data = {
                tan_code: document.getElementById('newTanCode').value,
                minutes: parseInt(document.getElementById('newTanMinutes').value),
                target_device: document.getElementById('newTanDevice').value,
                family_id: document.getElementById('newTanFamily').value ? parseInt(document.getElementById('newTanFamily').value) : null
            };
            const r = await api('/admin/tan-pool', { method: 'POST', body: JSON.stringify(data) });
            if (r && r.success !== false) {
                document.getElementById('addTanMessage').innerHTML = '<div class="success">TAN hinzugefuegt!</div>';
                document.getElementById('newTanCode').value = '';
                loadTanPool();
                setTimeout(() => closeModal('addTanModal'), 1500);
            } else {
                document.getElementById('addTanMessage').innerHTML = `<div class="error">${r?.detail || r?.message || 'Fehler'}</div>`;
            }
        }

        async function changeOwnPassword() {
            const current = document.getElementById('currentPassword').value;
            const newPw = document.getElementById('newPassword').value;
            const confirm = document.getElementById('confirmPassword').value;
            const msgDiv = document.getElementById('settingsMessage');

            if (newPw !== confirm) { msgDiv.innerHTML = '<div class="error">Passwoerter stimmen nicht ueberein</div>'; return; }
            if (newPw.length < 8) { msgDiv.innerHTML = '<div class="error">Passwort muss mind. 8 Zeichen haben</div>'; return; }

            const r = await api('/admin/change-password', { method: 'POST', body: JSON.stringify({ current_password: current, new_password: newPw }) });
            if (r && r.success !== false) {
                msgDiv.innerHTML = '<div class="success">Passwort geaendert!</div>';
                document.getElementById('currentPassword').value = '';
                document.getElementById('newPassword').value = '';
                document.getElementById('confirmPassword').value = '';
            } else {
                msgDiv.innerHTML = `<div class="error">${r?.detail || 'Fehler'}</div>`;
            }
        }

        // UI Helpers
        function showTab(name) {
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
            document.querySelector(`.tab[onclick="showTab('${name}')"]`)?.classList.add('active');
            document.getElementById(`${name}Tab`)?.classList.add('active');
        }

        function showModal(id) { document.getElementById(id)?.classList.add('active'); }
        function closeModal(id) { document.getElementById(id)?.classList.remove('active'); }

        // Close modal on outside click
        document.querySelectorAll('.modal').forEach(m => {
            m.addEventListener('click', e => { if (e.target === m) m.classList.remove('active'); });
        });
    </script>
</body>
</html>
"""


@router.get("/", response_class=HTMLResponse)
def admin_ui():
    """Serve the admin dashboard UI."""
    return ADMIN_HTML
