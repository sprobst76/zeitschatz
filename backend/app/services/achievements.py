"""Achievement checking and awarding service."""
from datetime import datetime, timedelta
from typing import List, Optional
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.achievement import Achievement, UserAchievement
from app.models.submission import Submission
from app.models.ledger import TanLedger
from app.models.learning import LearningSession


# Achievement definitions - will be seeded to database
ACHIEVEMENT_DEFINITIONS = [
    # Streak achievements
    {"code": "streak_3", "name": "3-Tage-Streak", "description": "3 Tage in Folge Aufgaben erledigt",
     "icon": "local_fire_department", "category": "streak", "threshold": 3, "reward_minutes": 5},
    {"code": "streak_7", "name": "Wochen-Champion", "description": "7 Tage in Folge Aufgaben erledigt",
     "icon": "local_fire_department", "category": "streak", "threshold": 7, "reward_minutes": 15},
    {"code": "streak_14", "name": "Zwei-Wochen-Held", "description": "14 Tage in Folge Aufgaben erledigt",
     "icon": "local_fire_department", "category": "streak", "threshold": 14, "reward_minutes": 30},
    {"code": "streak_30", "name": "Monats-Meister", "description": "30 Tage in Folge Aufgaben erledigt",
     "icon": "emoji_events", "category": "streak", "threshold": 30, "reward_minutes": 60},

    # Task count achievements
    {"code": "tasks_5", "name": "Starter", "description": "5 Aufgaben erledigt",
     "icon": "star", "category": "tasks", "threshold": 5, "reward_minutes": 5},
    {"code": "tasks_25", "name": "Fleissig", "description": "25 Aufgaben erledigt",
     "icon": "star", "category": "tasks", "threshold": 25, "reward_minutes": 10},
    {"code": "tasks_50", "name": "Aufgaben-Profi", "description": "50 Aufgaben erledigt",
     "icon": "star", "category": "tasks", "threshold": 50, "reward_minutes": 20},
    {"code": "tasks_100", "name": "Aufgaben-Meister", "description": "100 Aufgaben erledigt",
     "icon": "military_tech", "category": "tasks", "threshold": 100, "reward_minutes": 45},
    {"code": "tasks_250", "name": "Superstar", "description": "250 Aufgaben erledigt",
     "icon": "workspace_premium", "category": "tasks", "threshold": 250, "reward_minutes": 90},

    # Learning achievements
    {"code": "learn_first", "name": "Wissbegierig", "description": "Erste Lerneinheit abgeschlossen",
     "icon": "school", "category": "learning", "threshold": 1, "reward_minutes": 5},
    {"code": "learn_10", "name": "Lern-Enthusiast", "description": "10 Lerneinheiten abgeschlossen",
     "icon": "school", "category": "learning", "threshold": 10, "reward_minutes": 15},
    {"code": "learn_perfect", "name": "Perfektionist", "description": "Lerneinheit mit 100% abgeschlossen",
     "icon": "psychology", "category": "learning", "threshold": 100, "reward_minutes": 10},

    # Special achievements
    {"code": "early_bird", "name": "Fruehaufsteher", "description": "Aufgabe vor 8 Uhr eingereicht",
     "icon": "wb_sunny", "category": "special", "threshold": None, "reward_minutes": 5},
    {"code": "weekend_warrior", "name": "Wochenend-Krieger", "description": "Aufgabe am Wochenende erledigt",
     "icon": "celebration", "category": "special", "threshold": None, "reward_minutes": 5},
    {"code": "photo_pro", "name": "Foto-Profi", "description": "10 Aufgaben mit Foto eingereicht",
     "icon": "photo_camera", "category": "special", "threshold": 10, "reward_minutes": 10},
]


def seed_achievements(db: Session) -> int:
    """Seed achievement definitions to database. Returns count of new achievements."""
    created = 0
    for i, defn in enumerate(ACHIEVEMENT_DEFINITIONS):
        existing = db.query(Achievement).filter(Achievement.code == defn["code"]).first()
        if not existing:
            achievement = Achievement(
                code=defn["code"],
                name=defn["name"],
                description=defn["description"],
                icon=defn["icon"],
                category=defn["category"],
                threshold=defn["threshold"],
                reward_minutes=defn["reward_minutes"],
                sort_order=i,
            )
            db.add(achievement)
            created += 1
    db.commit()
    return created


def get_user_achievements(db: Session, user_id: int) -> List[dict]:
    """Get all achievements with user's unlock status."""
    achievements = db.query(Achievement).filter(Achievement.is_active == True).order_by(Achievement.sort_order).all()
    user_unlocked = db.query(UserAchievement).filter(UserAchievement.user_id == user_id).all()
    unlocked_ids = {ua.achievement_id: ua.unlocked_at for ua in user_unlocked}

    result = []
    for a in achievements:
        result.append({
            "id": a.id,
            "code": a.code,
            "name": a.name,
            "description": a.description,
            "icon": a.icon,
            "category": a.category,
            "threshold": a.threshold,
            "reward_minutes": a.reward_minutes,
            "unlocked": a.id in unlocked_ids,
            "unlocked_at": unlocked_ids.get(a.id),
        })
    return result


def check_and_award_achievements(db: Session, user_id: int) -> List[Achievement]:
    """Check all achievements for a user and award any newly unlocked ones."""
    newly_unlocked = []

    # Get already unlocked achievements
    unlocked = db.query(UserAchievement.achievement_id).filter(UserAchievement.user_id == user_id).all()
    unlocked_ids = {ua[0] for ua in unlocked}

    # Get all achievements
    achievements = db.query(Achievement).filter(Achievement.is_active == True).all()

    for achievement in achievements:
        if achievement.id in unlocked_ids:
            continue

        if _check_achievement(db, user_id, achievement):
            # Award the achievement
            user_achievement = UserAchievement(
                user_id=user_id,
                achievement_id=achievement.id,
            )
            db.add(user_achievement)
            newly_unlocked.append(achievement)

    if newly_unlocked:
        db.commit()

    return newly_unlocked


def _check_achievement(db: Session, user_id: int, achievement: Achievement) -> bool:
    """Check if a user has met the criteria for an achievement."""
    code = achievement.code

    # Streak achievements
    if code.startswith("streak_"):
        streak = _calculate_streak(db, user_id)
        return streak >= (achievement.threshold or 0)

    # Task count achievements
    if code.startswith("tasks_"):
        count = db.query(func.count(Submission.id)).filter(
            Submission.child_id == user_id,
            Submission.status == "approved"
        ).scalar() or 0
        return count >= (achievement.threshold or 0)

    # Learning achievements
    if code == "learn_first":
        count = db.query(func.count(LearningSession.id)).filter(
            LearningSession.child_id == user_id,
            LearningSession.completed == True
        ).scalar() or 0
        return count >= 1

    if code == "learn_10":
        count = db.query(func.count(LearningSession.id)).filter(
            LearningSession.child_id == user_id,
            LearningSession.completed == True
        ).scalar() or 0
        return count >= 10

    if code == "learn_perfect":
        perfect = db.query(LearningSession).filter(
            LearningSession.child_id == user_id,
            LearningSession.completed == True,
            LearningSession.correct_answers == LearningSession.total_questions
        ).first()
        return perfect is not None

    # Special achievements
    if code == "early_bird":
        early = db.query(Submission).filter(
            Submission.child_id == user_id,
            Submission.status == "approved",
            func.extract('hour', Submission.created_at) < 8
        ).first()
        return early is not None

    if code == "weekend_warrior":
        weekend = db.query(Submission).filter(
            Submission.child_id == user_id,
            Submission.status == "approved",
            func.extract('dow', Submission.created_at).in_([0, 6])  # Sunday=0, Saturday=6
        ).first()
        return weekend is not None

    if code == "photo_pro":
        photo_count = db.query(func.count(Submission.id)).filter(
            Submission.child_id == user_id,
            Submission.status == "approved",
            Submission.photo_path.isnot(None)
        ).scalar() or 0
        return photo_count >= (achievement.threshold or 10)

    return False


def _calculate_streak(db: Session, user_id: int) -> int:
    """Calculate current streak of consecutive days with approved submissions."""
    today = datetime.utcnow().date()
    streak = 0

    for i in range(365):
        check_date = today - timedelta(days=i)
        has_completion = db.query(Submission.id).filter(
            Submission.child_id == user_id,
            Submission.status == "approved",
            func.date(Submission.created_at) == check_date
        ).first() is not None

        if has_completion:
            streak += 1
        elif i == 0:
            continue  # Today might not have completion yet
        else:
            break

    return streak


def get_new_unlocked_achievements(db: Session, user_id: int) -> List[dict]:
    """Get achievements that were unlocked but not yet notified."""
    unlocked = db.query(UserAchievement, Achievement).join(
        Achievement, UserAchievement.achievement_id == Achievement.id
    ).filter(
        UserAchievement.user_id == user_id,
        UserAchievement.notified == False
    ).all()

    result = []
    for ua, achievement in unlocked:
        result.append({
            "id": achievement.id,
            "code": achievement.code,
            "name": achievement.name,
            "description": achievement.description,
            "icon": achievement.icon,
            "reward_minutes": achievement.reward_minutes,
            "unlocked_at": ua.unlocked_at,
        })
        ua.notified = True

    if result:
        db.commit()

    return result
