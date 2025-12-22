from datetime import datetime, timedelta
from fastapi import APIRouter, Depends
from sqlalchemy import func, and_
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.security import require_role
from app.models.submission import Submission
from app.models.ledger import TanLedger
from app.models.user import User
from app.models.task import Task

router = APIRouter()


@router.get("/overview", dependencies=[Depends(require_role("parent"))])
def get_stats_overview(
    db: Session = Depends(get_db),
):
    """Get overall statistics for the dashboard."""
    # Get all children
    children = db.query(User).filter(User.role == "child", User.is_active == True).all()

    # Date ranges
    today = datetime.utcnow().date()
    week_start = today - timedelta(days=today.weekday())
    month_start = today.replace(day=1)

    child_stats = []
    for child in children:
        # Total completed submissions
        total_completed = db.query(func.count(Submission.id)).filter(
            Submission.child_id == child.id,
            Submission.status == "approved"
        ).scalar() or 0

        # This week completed
        week_completed = db.query(func.count(Submission.id)).filter(
            Submission.child_id == child.id,
            Submission.status == "approved",
            func.date(Submission.created_at) >= week_start
        ).scalar() or 0

        # This month completed
        month_completed = db.query(func.count(Submission.id)).filter(
            Submission.child_id == child.id,
            Submission.status == "approved",
            func.date(Submission.created_at) >= month_start
        ).scalar() or 0

        # Pending submissions
        pending = db.query(func.count(Submission.id)).filter(
            Submission.child_id == child.id,
            Submission.status == "pending"
        ).scalar() or 0

        # Total TAN minutes earned
        total_minutes = db.query(func.sum(TanLedger.minutes)).filter(
            TanLedger.child_id == child.id
        ).scalar() or 0

        # Calculate streak
        streak = _calculate_streak(db, child.id)

        child_stats.append({
            "child_id": child.id,
            "child_name": child.name,
            "total_completed": total_completed,
            "week_completed": week_completed,
            "month_completed": month_completed,
            "pending": pending,
            "total_minutes_earned": total_minutes,
            "current_streak": streak,
        })

    # TAN usage by device
    device_stats = db.query(
        TanLedger.target_device,
        func.sum(TanLedger.minutes).label("total_minutes"),
        func.count(TanLedger.id).label("count")
    ).group_by(TanLedger.target_device).all()

    device_usage = [
        {
            "device": row.target_device or "unknown",
            "total_minutes": row.total_minutes or 0,
            "count": row.count or 0,
        }
        for row in device_stats
    ]

    # Weekly trend (last 4 weeks)
    weekly_trend = []
    for i in range(4):
        week_end = week_start - timedelta(days=7 * i)
        week_begin = week_end - timedelta(days=7)

        count = db.query(func.count(Submission.id)).filter(
            Submission.status == "approved",
            func.date(Submission.created_at) >= week_begin,
            func.date(Submission.created_at) < week_end
        ).scalar() or 0

        weekly_trend.append({
            "week_start": week_begin.isoformat(),
            "completed": count,
        })

    weekly_trend.reverse()

    return {
        "children": child_stats,
        "device_usage": device_usage,
        "weekly_trend": weekly_trend,
        "summary": {
            "total_children": len(children),
            "total_completed_all": sum(c["total_completed"] for c in child_stats),
            "total_pending": sum(c["pending"] for c in child_stats),
            "total_minutes_all": sum(c["total_minutes_earned"] for c in child_stats),
        }
    }


@router.get("/child/{child_id}", dependencies=[Depends(require_role("parent"))])
def get_child_stats(
    child_id: int,
    db: Session = Depends(get_db),
):
    """Get detailed statistics for a specific child."""
    child = db.query(User).filter(User.id == child_id, User.role == "child").first()
    if not child:
        return {"error": "Child not found"}

    today = datetime.utcnow().date()
    week_start = today - timedelta(days=today.weekday())

    # Daily breakdown for current week
    daily_stats = []
    for i in range(7):
        day = week_start + timedelta(days=i)
        day_name = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"][i]

        count = db.query(func.count(Submission.id)).filter(
            Submission.child_id == child_id,
            Submission.status == "approved",
            func.date(Submission.created_at) == day
        ).scalar() or 0

        daily_stats.append({
            "day": day_name,
            "date": day.isoformat(),
            "completed": count,
            "is_today": day == today,
        })

    # Top completed tasks
    top_tasks = db.query(
        Task.title,
        func.count(Submission.id).label("count")
    ).join(Submission, Task.id == Submission.task_id).filter(
        Submission.child_id == child_id,
        Submission.status == "approved"
    ).group_by(Task.id, Task.title).order_by(func.count(Submission.id).desc()).limit(5).all()

    # TAN by device for this child
    device_breakdown = db.query(
        TanLedger.target_device,
        func.sum(TanLedger.minutes).label("minutes")
    ).filter(TanLedger.child_id == child_id).group_by(TanLedger.target_device).all()

    return {
        "child_id": child_id,
        "child_name": child.name,
        "daily_stats": daily_stats,
        "top_tasks": [{"title": t.title, "count": t.count} for t in top_tasks],
        "device_breakdown": [
            {"device": d.target_device or "unknown", "minutes": d.minutes or 0}
            for d in device_breakdown
        ],
        "current_streak": _calculate_streak(db, child_id),
    }


def _calculate_streak(db: Session, child_id: int) -> int:
    """Calculate current streak of consecutive days with approved submissions."""
    today = datetime.utcnow().date()
    streak = 0

    # Check each day going backwards
    for i in range(365):  # Max 1 year
        check_date = today - timedelta(days=i)

        has_completion = db.query(Submission.id).filter(
            Submission.child_id == child_id,
            Submission.status == "approved",
            func.date(Submission.created_at) == check_date
        ).first() is not None

        if has_completion:
            streak += 1
        elif i == 0:
            # Today has no completion yet, that's ok - check yesterday
            continue
        else:
            # Streak broken
            break

    return streak
