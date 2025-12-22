"""API routes for learning exercises."""
from datetime import datetime
from typing import List, Dict, Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import get_current_user, require_role
from app.models.learning import LearningSession, LearningProgress
from app.models.ledger import TanLedger
from app.schemas.learning import (
    SubjectInfo, DifficultyInfo, SessionStart, SessionResponse,
    AnswerSubmit, AnswerResult, SessionComplete, LearningSessionRead, ProgressRead
)
from app.services.question_bank import (
    SUBJECTS, DIFFICULTIES, get_questions, check_answer
)

router = APIRouter()

# In-memory storage for active sessions (questions)
# In production, use Redis or similar
active_sessions: Dict[int, Dict[str, Any]] = {}


@router.get("/subjects", response_model=List[SubjectInfo])
def list_subjects():
    """List available subjects."""
    return [
        SubjectInfo(id=key, name=val["name"], icon=val["icon"])
        for key, val in SUBJECTS.items()
    ]


@router.get("/difficulties", response_model=List[DifficultyInfo])
def list_difficulties():
    """List available difficulty levels."""
    return [
        DifficultyInfo(id=key, name=val["name"], reward_minutes=val["reward_minutes"])
        for key, val in DIFFICULTIES.items()
    ]


@router.post("/sessions", response_model=SessionResponse, dependencies=[Depends(require_role("child"))])
def start_session(
    payload: SessionStart,
    db: Session = Depends(get_db_session),
    user=Depends(get_current_user),
):
    """Start a new learning session."""
    reward_minutes = DIFFICULTIES[payload.difficulty]["reward_minutes"]

    # Create session in database
    session = LearningSession(
        child_id=user.id,
        subject=payload.subject,
        difficulty=payload.difficulty,
        total_questions=payload.question_count,
        correct_answers=0,
        wrong_answers=0,
        completed=False,
        created_at=datetime.utcnow(),
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    # Generate questions and store in memory
    questions = get_questions(payload.subject, payload.difficulty, payload.question_count)
    active_sessions[session.id] = {
        "questions": questions,
        "current_index": 0,
        "answers": [],
        "start_time": datetime.utcnow(),
    }

    return SessionResponse(
        session_id=session.id,
        subject=payload.subject,
        difficulty=payload.difficulty,
        total_questions=payload.question_count,
        reward_minutes=reward_minutes,
    )


@router.get("/sessions/{session_id}/question", dependencies=[Depends(require_role("child"))])
def get_current_question(
    session_id: int,
    db: Session = Depends(get_db_session),
    user=Depends(get_current_user),
):
    """Get the current question for a session."""
    session = db.get(LearningSession, session_id)
    if not session or session.child_id != user.id:
        raise HTTPException(status_code=404, detail="Session not found")

    if session.completed:
        raise HTTPException(status_code=400, detail="Session already completed")

    if session_id not in active_sessions:
        raise HTTPException(status_code=400, detail="Session expired, please start a new one")

    session_data = active_sessions[session_id]
    current_index = session_data["current_index"]

    if current_index >= len(session_data["questions"]):
        raise HTTPException(status_code=400, detail="No more questions")

    question = session_data["questions"][current_index]

    return {
        "question_index": current_index,
        "total_questions": session.total_questions,
        "type": question["type"],
        "question": question["question"],
        "hint": question.get("hint"),
        "correct_so_far": session.correct_answers,
        "wrong_so_far": session.wrong_answers,
    }


@router.post("/sessions/{session_id}/answer", response_model=AnswerResult, dependencies=[Depends(require_role("child"))])
def submit_answer(
    session_id: int,
    payload: AnswerSubmit,
    db: Session = Depends(get_db_session),
    user=Depends(get_current_user),
):
    """Submit an answer to the current question."""
    session = db.get(LearningSession, session_id)
    if not session or session.child_id != user.id:
        raise HTTPException(status_code=404, detail="Session not found")

    if session.completed:
        raise HTTPException(status_code=400, detail="Session already completed")

    if session_id not in active_sessions:
        raise HTTPException(status_code=400, detail="Session expired")

    session_data = active_sessions[session_id]

    if payload.question_index != session_data["current_index"]:
        raise HTTPException(status_code=400, detail="Invalid question index")

    question = session_data["questions"][payload.question_index]
    is_correct = check_answer(question, payload.answer)

    # Update session
    if is_correct:
        session.correct_answers += 1
    else:
        session.wrong_answers += 1

    session_data["current_index"] += 1
    session_data["answers"].append({
        "question_index": payload.question_index,
        "user_answer": payload.answer,
        "correct": is_correct,
    })

    db.add(session)
    db.commit()

    return AnswerResult(
        correct=is_correct,
        correct_answer=question["answer"],
        current_score=session.correct_answers,
        total_answered=session.correct_answers + session.wrong_answers,
        total_questions=session.total_questions,
    )


@router.post("/sessions/{session_id}/complete", response_model=SessionComplete, dependencies=[Depends(require_role("child"))])
def complete_session(
    session_id: int,
    db: Session = Depends(get_db_session),
    user=Depends(get_current_user),
):
    """Complete a learning session and get rewards."""
    session = db.get(LearningSession, session_id)
    if not session or session.child_id != user.id:
        raise HTTPException(status_code=404, detail="Session not found")

    if session.completed:
        raise HTTPException(status_code=400, detail="Session already completed")

    if session_id not in active_sessions:
        raise HTTPException(status_code=400, detail="Session expired")

    session_data = active_sessions[session_id]

    # Calculate time
    start_time = session_data["start_time"]
    time_seconds = int((datetime.utcnow() - start_time).total_seconds())

    # Calculate reward (need at least 70% correct)
    total_answered = session.correct_answers + session.wrong_answers
    accuracy = session.correct_answers / total_answered if total_answered > 0 else 0
    passed = accuracy >= 0.7

    base_reward = DIFFICULTIES[session.difficulty]["reward_minutes"]
    tan_reward = base_reward if passed else 0

    # Update session
    session.completed = True
    session.completed_at = datetime.utcnow()
    session.time_seconds = time_seconds
    session.tan_reward = tan_reward

    # Update progress
    progress = db.execute(
        select(LearningProgress).where(
            LearningProgress.child_id == user.id,
            LearningProgress.subject == session.subject,
            LearningProgress.difficulty == session.difficulty,
        )
    ).scalar_one_or_none()

    if progress:
        progress.total_attempted += total_answered
        progress.total_correct += session.correct_answers
        progress.sessions_completed += 1
        progress.last_session_at = datetime.utcnow()
    else:
        progress = LearningProgress(
            child_id=user.id,
            subject=session.subject,
            difficulty=session.difficulty,
            total_attempted=total_answered,
            total_correct=session.correct_answers,
            sessions_completed=1,
            last_session_at=datetime.utcnow(),
        )
        db.add(progress)

    # Create ledger entry if passed
    if passed and tan_reward > 0:
        ledger_entry = TanLedger(
            child_id=user.id,
            minutes=tan_reward,
            reason=f"Lernaufgabe: {SUBJECTS[session.subject]['name']} ({DIFFICULTIES[session.difficulty]['name']})",
            paid_out=False,
            created_at=datetime.utcnow(),
        )
        db.add(ledger_entry)

    db.add(session)
    db.commit()

    # Clean up memory
    del active_sessions[session_id]

    return SessionComplete(
        session_id=session.id,
        subject=session.subject,
        difficulty=session.difficulty,
        correct_answers=session.correct_answers,
        wrong_answers=session.wrong_answers,
        total_questions=session.total_questions,
        time_seconds=time_seconds,
        tan_reward=tan_reward,
        passed=passed,
    )


@router.get("/progress", response_model=List[ProgressRead], dependencies=[Depends(require_role("child"))])
def get_my_progress(
    db: Session = Depends(get_db_session),
    user=Depends(get_current_user),
):
    """Get learning progress for the current child."""
    stmt = select(LearningProgress).where(LearningProgress.child_id == user.id)
    progress_list = db.execute(stmt).scalars().all()

    return [
        ProgressRead(
            subject=p.subject,
            difficulty=p.difficulty,
            total_attempted=p.total_attempted,
            total_correct=p.total_correct,
            sessions_completed=p.sessions_completed,
            accuracy_percent=round(p.total_correct / p.total_attempted * 100, 1) if p.total_attempted > 0 else 0,
        )
        for p in progress_list
    ]


@router.get("/history", response_model=List[LearningSessionRead], dependencies=[Depends(require_role("child"))])
def get_session_history(
    db: Session = Depends(get_db_session),
    user=Depends(get_current_user),
):
    """Get learning session history for the current child."""
    stmt = (
        select(LearningSession)
        .where(LearningSession.child_id == user.id, LearningSession.completed == True)
        .order_by(LearningSession.created_at.desc())
        .limit(20)
    )
    return db.execute(stmt).scalars().all()


@router.get("/stats/{child_id}", dependencies=[Depends(require_role("parent"))])
def get_child_learning_stats(
    child_id: int,
    db: Session = Depends(get_db_session),
):
    """Get learning statistics for a child (parent-only)."""
    # Get progress
    stmt = select(LearningProgress).where(LearningProgress.child_id == child_id)
    progress_list = db.execute(stmt).scalars().all()

    # Get recent sessions
    stmt = (
        select(LearningSession)
        .where(LearningSession.child_id == child_id, LearningSession.completed == True)
        .order_by(LearningSession.created_at.desc())
        .limit(10)
    )
    recent_sessions = db.execute(stmt).scalars().all()

    return {
        "progress": [
            {
                "subject": p.subject,
                "subject_name": SUBJECTS.get(p.subject, {}).get("name", p.subject),
                "difficulty": p.difficulty,
                "difficulty_name": DIFFICULTIES.get(p.difficulty, {}).get("name", p.difficulty),
                "sessions_completed": p.sessions_completed,
                "total_correct": p.total_correct,
                "total_attempted": p.total_attempted,
                "accuracy_percent": round(p.total_correct / p.total_attempted * 100, 1) if p.total_attempted > 0 else 0,
            }
            for p in progress_list
        ],
        "recent_sessions": [
            {
                "id": s.id,
                "subject": s.subject,
                "subject_name": SUBJECTS.get(s.subject, {}).get("name", s.subject),
                "difficulty": s.difficulty,
                "correct": s.correct_answers,
                "total": s.total_questions,
                "tan_reward": s.tan_reward,
                "completed_at": s.completed_at,
            }
            for s in recent_sessions
        ],
    }
