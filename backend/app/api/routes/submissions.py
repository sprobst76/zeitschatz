from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi import BackgroundTasks
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import get_current_user, require_role
from app.models.ledger import TanLedger
from app.models.submission import Submission
from app.models.task import Task
from app.schemas.submission import SubmissionCreate, SubmissionDecision, SubmissionRead, SubmissionReadExtended
from app.models.user import User
from app.services.notifications import send_push, get_parent_tokens
from app.services.achievements import check_and_award_achievements

router = APIRouter()


@router.post("", response_model=SubmissionRead, status_code=status.HTTP_201_CREATED, dependencies=[Depends(require_role("child"))])
def create_submission(
    payload: SubmissionCreate,
    db: Session = Depends(get_db_session),
    user=Depends(get_current_user),
    background_tasks: BackgroundTasks = None,
):
    task = db.get(Task, payload.task_id)
    if not task or not task.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not available")

    # Check if task is auto-approve
    is_auto_approve = getattr(task, 'auto_approve', False)

    submission = Submission(
        task_id=payload.task_id,
        child_id=user.id,
        status="approved" if is_auto_approve else "pending",
        selected_device=payload.selected_device,
        comment=payload.comment,
        photo_path=payload.photo_path,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(submission)
    db.commit()
    db.refresh(submission)

    if is_auto_approve:
        # Auto-approve: create TAN ledger entry
        ledger_entry = TanLedger(
            child_id=submission.child_id,
            submission_id=submission.id,
            minutes=task.tan_reward,
            target_device=submission.selected_device,
            reason=f"Auto: {task.title}",
            paid_out=False,
            created_at=datetime.utcnow(),
        )
        db.add(ledger_entry)
        db.commit()

        # Check for achievements
        newly_unlocked = check_and_award_achievements(db, submission.child_id)

        # Push to child about auto-approval
        if background_tasks:
            from app.services.notifications import get_child_tokens
            tokens = get_child_tokens(db, submission.child_id)
            background_tasks.add_task(
                send_push,
                tokens,
                {
                    "type": "submission_auto_approved",
                    "submission_id": submission.id,
                    "minutes": task.tan_reward,
                    "task_title": task.title,
                    "new_achievements": [a.name for a in newly_unlocked] if newly_unlocked else [],
                },
            )
    else:
        # Normal flow: notify parents
        if background_tasks:
            tokens = get_parent_tokens(db)
            background_tasks.add_task(
                send_push,
                tokens,
                {
                    "type": "submission_pending",
                    "child_id": submission.child_id,
                    "task_id": submission.task_id,
                    "submission_id": submission.id,
                },
            )
    return submission


@router.get("/history", response_model=List[SubmissionRead])
def list_history(
    child_id: int | None = Query(default=None, description="Filter auf Kind-ID (parent-only)"),
    db: Session = Depends(get_db_session),
    user=Depends(get_current_user),
):
    stmt = select(Submission).order_by(Submission.created_at.desc())
    if user.role == "child":
        stmt = stmt.where(Submission.child_id == user.id)
    else:
        if child_id is not None:
            stmt = stmt.where(Submission.child_id == child_id)
    return db.execute(stmt).scalars().all()


def _extend_submission(sub: Submission, db: Session) -> SubmissionReadExtended:
    """Helper to add task and child info to a submission."""
    task = db.get(Task, sub.task_id)
    child = db.get(User, sub.child_id)
    return SubmissionReadExtended(
        id=sub.id,
        task_id=sub.task_id,
        child_id=sub.child_id,
        status=sub.status,
        selected_device=sub.selected_device,
        comment=sub.comment,
        photo_path=sub.photo_path,
        created_at=sub.created_at,
        updated_at=sub.updated_at,
        task_title=task.title if task else None,
        task_description=task.description if task else None,
        child_name=child.name if child else None,
        tan_reward=task.tan_reward if task else None,
        target_devices=task.target_devices if task else None,
    )


@router.get("/pending", response_model=List[SubmissionReadExtended], dependencies=[Depends(require_role("parent"))])
def list_pending(db: Session = Depends(get_db_session)):
    stmt = select(Submission).where(Submission.status == "pending").order_by(Submission.created_at.desc())
    submissions = db.execute(stmt).scalars().all()
    return [_extend_submission(sub, db) for sub in submissions]


@router.get("/completed", response_model=List[SubmissionReadExtended], dependencies=[Depends(require_role("parent"))])
def list_completed(
    child_id: int | None = Query(default=None, description="Filter by child ID"),
    limit: int = Query(default=50, ge=1, le=200, description="Max results"),
    db: Session = Depends(get_db_session),
):
    stmt = select(Submission).where(Submission.status == "approved").order_by(Submission.updated_at.desc()).limit(limit)
    if child_id is not None:
        stmt = stmt.where(Submission.child_id == child_id)
    submissions = db.execute(stmt).scalars().all()
    return [_extend_submission(sub, db) for sub in submissions]


@router.post("/{submission_id}/approve", response_model=SubmissionRead, dependencies=[Depends(require_role("parent"))])
def approve_submission(
    submission_id: int,
    decision: SubmissionDecision,
    db: Session = Depends(get_db_session),
    background_tasks: BackgroundTasks = None,
):
    submission = db.get(Submission, submission_id)
    if not submission:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Submission not found")
    task = db.get(Task, submission.task_id)
    minutes = decision.minutes or (task.tan_reward if task else 0)
    # Use selected_device from submission (child's choice)
    target_device = submission.selected_device
    submission.status = "approved"
    submission.comment = decision.comment or submission.comment
    submission.updated_at = datetime.utcnow()
    ledger_entry = TanLedger(
        child_id=submission.child_id,
        submission_id=submission.id,
        minutes=minutes,
        target_device=target_device,
        tan_code=decision.tan_code,
        valid_until=decision.valid_until,
        reason=f"Task {submission.task_id}",
        paid_out=False,
        created_at=datetime.utcnow(),
    )
    db.add(ledger_entry)
    db.add(submission)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="TAN code already exists",
        )
    db.refresh(submission)

    # Check for newly unlocked achievements
    newly_unlocked = check_and_award_achievements(db, submission.child_id)

    # Push an Kind
    if background_tasks:
        from app.services.notifications import get_child_tokens

        tokens = get_child_tokens(db, submission.child_id)
        background_tasks.add_task(
            send_push,
            tokens,
            {
                "type": "submission_approved",
                "submission_id": submission.id,
                "minutes": ledger_entry.minutes,
                "target_device": ledger_entry.target_device,
                "new_achievements": [a.name for a in newly_unlocked] if newly_unlocked else [],
            },
        )
    return submission


@router.post("/{submission_id}/retry", response_model=SubmissionRead, dependencies=[Depends(require_role("parent"))])
def retry_submission(
    submission_id: int,
    decision: SubmissionDecision,
    db: Session = Depends(get_db_session),
):
    submission = db.get(Submission, submission_id)
    if not submission:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Submission not found")
    submission.status = "retry"
    submission.comment = decision.comment or "Bitte noch einmal erledigen."
    submission.updated_at = datetime.utcnow()
    db.add(submission)
    db.commit()
    db.refresh(submission)
    return submission
