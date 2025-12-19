from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.dependencies import get_db_session
from app.core.security import require_role
from app.models.task import Task
from app.schemas.task import TaskCreate, TaskRead, TaskUpdate

router = APIRouter()
settings = get_settings()


@router.get("", response_model=List[TaskRead])
def list_tasks(
    child_id: int | None = Query(default=None, description="Filter auf zugewiesene Kind-ID"),
    db: Session = Depends(get_db_session),
):
    stmt = select(Task).where(Task.is_active.is_(True))
    if child_id is not None:
        stmt = stmt.where(Task.assigned_children.contains([child_id]))  # simple JSON array contains
    tasks = db.execute(stmt).scalars().all()
    return tasks


@router.post("", response_model=TaskRead, status_code=status.HTTP_201_CREATED, dependencies=[Depends(require_role("parent"))])
def create_task(payload: TaskCreate, db: Session = Depends(get_db_session)):
    task = Task(**payload.model_dump(), created_at=datetime.utcnow())
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@router.patch("/{task_id}", response_model=TaskRead, dependencies=[Depends(require_role("parent"))])
def update_task(task_id: int, payload: TaskUpdate, db: Session = Depends(get_db_session)):
    task = db.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(task, key, value)
    db.add(task)
    db.commit()
    db.refresh(task)
    return task
