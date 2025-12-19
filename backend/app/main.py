from fastapi import FastAPI

from app.api.routes.health import router as health_router
from app.api.routes.tasks import router as tasks_router
from app.api.routes.submissions import router as submissions_router
from app.api.routes.ledger import router as ledger_router
from app.api.routes.auth import router as auth_router
from app.api.routes.photos import router as photos_router
from app.api.routes.notifications import router as notifications_router
from app.db.session import SessionLocal
from app.jobs.retention import clean_expired_photos
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from app.core.config import get_settings


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name, version="0.1.0")

    scheduler = AsyncIOScheduler()

    # Routers
    app.include_router(health_router, prefix="/health", tags=["health"])
    app.include_router(auth_router, prefix="/auth", tags=["auth"])
    app.include_router(tasks_router, prefix="/tasks", tags=["tasks"])
    app.include_router(submissions_router, prefix="/submissions", tags=["submissions"])
    app.include_router(ledger_router, prefix="/ledger", tags=["ledger"])
    app.include_router(photos_router, prefix="/photos", tags=["photos"])
    app.include_router(notifications_router, prefix="/notifications", tags=["notifications"])

    @app.on_event("startup")
    async def startup_event():
        # Daily photo retention cleanup
        scheduler.add_job(
            lambda: run_retention_job(),
            trigger="cron",
            hour=3,
            id="photo-retention",
            replace_existing=True,
        )
        scheduler.start()

    def run_retention_job():
        db = SessionLocal()
        try:
            removed = clean_expired_photos(db)
            if removed:
                print(f"[retention] removed {len(removed)} expired photos")
        finally:
            db.close()

    return app


app = create_app()


@app.get("/")
def root():
    return {"status": "ok"}
