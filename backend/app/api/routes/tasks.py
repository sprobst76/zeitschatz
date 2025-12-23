from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.dependencies import get_db_session, get_user_family_ids, verify_family_access
from app.core.security import get_current_user, require_role
from app.models.task import Task
from app.models.user import User
from app.schemas.task import TaskCreate, TaskRead, TaskUpdate

router = APIRouter()
settings = get_settings()


@router.get("", response_model=List[TaskRead])
def list_tasks(
    family_id: int | None = Query(default=None, description="Filter auf Familie"),
    child_id: int | None = Query(default=None, description="Filter auf zugewiesene Kind-ID"),
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    """List tasks. Filters by family_id if provided, otherwise returns tasks from all user's families."""
    stmt = select(Task).where(Task.is_active.is_(True))

    # Family filtering
    if family_id is not None:
        # Verify access
        if not verify_family_access(db, user.id, family_id):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Kein Zugriff auf diese Familie")
        stmt = stmt.where(Task.family_id == family_id)
    else:
        # Return tasks from all user's families
        user_family_ids = get_user_family_ids(db, user.id)
        if user_family_ids:
            stmt = stmt.where(Task.family_id.in_(user_family_ids))
        else:
            # Fallback for legacy data without family_id
            stmt = stmt.where(Task.family_id.is_(None))

    if child_id is not None:
        stmt = stmt.where(Task.assigned_children.contains([child_id]))

    tasks = db.execute(stmt).scalars().all()
    return tasks


def is_task_due_today(recurrence: dict | list | None, day_key: str) -> bool:
    if not recurrence:
        return True
    if isinstance(recurrence, dict):
        return bool(recurrence.get(day_key, False))
    if isinstance(recurrence, list):
        return day_key in recurrence
    return True


@router.get("/today", response_model=List[TaskRead])
def list_tasks_today(
    family_id: int | None = Query(default=None, description="Filter auf Familie"),
    child_id: int | None = Query(default=None, description="Filter auf zugewiesene Kind-ID"),
    db: Session = Depends(get_db_session),
    user: User = Depends(get_current_user),
):
    """List tasks due today. Filters by family_id if provided."""
    stmt = select(Task).where(Task.is_active.is_(True))

    # Family filtering
    if family_id is not None:
        if not verify_family_access(db, user.id, family_id):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Kein Zugriff auf diese Familie")
        stmt = stmt.where(Task.family_id == family_id)
    else:
        user_family_ids = get_user_family_ids(db, user.id)
        if user_family_ids:
            stmt = stmt.where(Task.family_id.in_(user_family_ids))
        else:
            stmt = stmt.where(Task.family_id.is_(None))

    if child_id is not None:
        stmt = stmt.where(Task.assigned_children.contains([child_id]))

    tasks = db.execute(stmt).scalars().all()
    day_key = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"][datetime.utcnow().weekday()]
    return [task for task in tasks if is_task_due_today(task.recurrence, day_key)]


@router.post("", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
def create_task(
    payload: TaskCreate,
    family_id: int = Query(..., description="Familie für diese Aufgabe"),
    db: Session = Depends(get_db_session),
    user: User = Depends(require_role("parent")),
):
    """Create a new task in a family."""
    # Verify family access
    if not verify_family_access(db, user.id, family_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Kein Zugriff auf diese Familie")

    task = Task(**payload.model_dump(), family_id=family_id, created_at=datetime.utcnow())
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@router.patch("/{task_id}", response_model=TaskRead)
def update_task(
    task_id: int,
    payload: TaskUpdate,
    db: Session = Depends(get_db_session),
    user: User = Depends(require_role("parent")),
):
    """Update a task. User must have access to the task's family."""
    task = db.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")

    # Verify family access
    if task.family_id and not verify_family_access(db, user.id, task.family_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Kein Zugriff auf diese Aufgabe")

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(task, key, value)
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(
    task_id: int,
    db: Session = Depends(get_db_session),
    user: User = Depends(require_role("parent")),
):
    """Deactivate a task. User must have access to the task's family."""
    task = db.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")

    # Verify family access
    if task.family_id and not verify_family_access(db, user.id, task.family_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Kein Zugriff auf diese Aufgabe")

    task.is_active = False
    db.commit()
    return None
