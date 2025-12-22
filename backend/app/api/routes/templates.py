"""Task template API routes."""
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import require_role
from app.models.task import TaskTemplate
from app.schemas.task import TaskTemplateCreate, TaskTemplateRead

router = APIRouter()


@router.get("", response_model=List[TaskTemplateRead])
def list_templates(
    db: Session = Depends(get_db_session),
):
    """List all task templates."""
    stmt = select(TaskTemplate).order_by(TaskTemplate.sort_order)
    templates = db.execute(stmt).scalars().all()
    return templates


@router.get("/{template_id}", response_model=TaskTemplateRead)
def get_template(
    template_id: int,
    db: Session = Depends(get_db_session),
):
    """Get a specific template."""
    template = db.get(TaskTemplate, template_id)
    if not template:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    return template


@router.post("", response_model=TaskTemplateRead, status_code=status.HTTP_201_CREATED,
             dependencies=[Depends(require_role("parent"))])
def create_template(
    payload: TaskTemplateCreate,
    db: Session = Depends(get_db_session),
):
    """Create a custom task template."""
    template = TaskTemplate(
        **payload.model_dump(),
        is_system=False,
    )
    db.add(template)
    db.commit()
    db.refresh(template)
    return template


@router.delete("/{template_id}", status_code=status.HTTP_204_NO_CONTENT,
               dependencies=[Depends(require_role("parent"))])
def delete_template(
    template_id: int,
    db: Session = Depends(get_db_session),
):
    """Delete a custom template. System templates cannot be deleted."""
    template = db.get(TaskTemplate, template_id)
    if not template:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    if template.is_system:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="System templates cannot be deleted")
    db.delete(template)
    db.commit()
