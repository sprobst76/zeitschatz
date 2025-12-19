from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi import BackgroundTasks
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import get_current_user, require_role
from app.models.ledger import TanLedger
from app.models.submission import Submission
from app.models.task import Task
from app.schemas.submission import SubmissionCreate, SubmissionDecision, SubmissionRead
from app.services.notifications import send_push, get_parent_tokens

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
    submission = Submission(
        task_id=payload.task_id,
        child_id=user["id"],
        status="pending",
        comment=payload.comment,
        photo_path=payload.photo_path,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(submission)
    db.commit()
    db.refresh(submission)
    # Push an Eltern
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


@router.get("/pending", response_model=List[SubmissionRead], dependencies=[Depends(require_role("parent"))])
def list_pending(db: Session = Depends(get_db_session)):
    stmt = select(Submission).where(Submission.status == "pending")
    return db.execute(stmt).scalars().all()


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
    minutes = decision.minutes or (task.duration_minutes if task else 0)
    target_device = decision.target_device or (task.target_device if task else None)
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
    db.commit()
    db.refresh(submission)
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
