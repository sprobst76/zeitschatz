"""Schemas for learning exercises."""
from datetime import datetime
from typing import List, Optional, Any
from pydantic import BaseModel, Field


class SubjectInfo(BaseModel):
    """Information about a subject."""
    id: str
    name: str
    icon: str


class DifficultyInfo(BaseModel):
    """Information about a difficulty level."""
    id: str
    name: str
    reward_minutes: int


class Question(BaseModel):
    """A single question."""
    type: str
    question: str
    hint: Optional[str] = None


class QuestionWithAnswer(Question):
    """A question with its answer (for checking)."""
    answer: str
    accept_alternatives: List[str] = []


class SessionStart(BaseModel):
    """Request to start a learning session."""
    subject: str = Field(..., pattern="^(math|english|german)$")
    difficulty: str = Field(..., pattern="^(grade1|grade2|grade3|grade4|grade5plus)$")
    question_count: int = Field(default=10, ge=5, le=20)


class SessionResponse(BaseModel):
    """Response when starting a session."""
    session_id: int
    subject: str
    difficulty: str
    total_questions: int
    reward_minutes: int


class AnswerSubmit(BaseModel):
    """Submit an answer to a question."""
    session_id: int
    question_index: int
    answer: str


class AnswerResult(BaseModel):
    """Result of checking an answer."""
    correct: bool
    correct_answer: str
    current_score: int
    total_answered: int
    total_questions: int


class SessionComplete(BaseModel):
    """Complete session results."""
    session_id: int
    subject: str
    difficulty: str
    correct_answers: int
    wrong_answers: int
    total_questions: int
    time_seconds: int
    tan_reward: int
    passed: bool


class LearningSessionRead(BaseModel):
    """Read model for a learning session."""
    id: int
    child_id: int
    subject: str
    difficulty: str
    total_questions: int
    correct_answers: int
    wrong_answers: int
    time_seconds: Optional[int]
    completed: bool
    tan_reward: Optional[int]
    created_at: datetime
    completed_at: Optional[datetime]

    class Config:
        from_attributes = True


class ProgressRead(BaseModel):
    """Read model for learning progress."""
    subject: str
    difficulty: str
    total_attempted: int
    total_correct: int
    sessions_completed: int
    accuracy_percent: float
