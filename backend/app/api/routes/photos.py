from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import get_current_user, require_role
from app.models.submission import Submission
from app.services import photos

router = APIRouter()


@router.post("/upload")
def upload_photo(
    submission_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db_session),
    user=Depends(get_current_user),
):
    submission = db.get(Submission, submission_id)
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found")
    if submission.child_id != user.id and user.role != "parent":
        raise HTTPException(status_code=403, detail="Forbidden")

    path, expires_at = photos.save_photo(submission.child_id, submission.id, file)
    submission.photo_path = path
    submission.photo_expires_at = expires_at
    db.add(submission)
    db.commit()
    db.refresh(submission)
    return {"photo_path": submission.photo_path, "expires_at": submission.photo_expires_at}


@router.get("/{submission_id}")
def get_photo(
    submission_id: int,
    db: Session = Depends(get_db_session),
    user=Depends(get_current_user),
):
    submission = db.get(Submission, submission_id)
    if not submission or not submission.photo_path:
        raise HTTPException(status_code=404, detail="Photo not found")
    if submission.child_id != user.id and user.role != "parent":
        raise HTTPException(status_code=403, detail="Forbidden")
    content = photos.stream_photo(submission.photo_path)
    return Response(content=content, media_type="image/jpeg")
