from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.core.rate_limit import limiter
from app.api.routes.health import router as health_router
from app.api.routes.tasks import router as tasks_router
from app.api.routes.submissions import router as submissions_router
from app.api.routes.ledger import router as ledger_router
from app.api.routes.auth import router as auth_router
from app.api.routes.photos import router as photos_router
from app.api.routes.notifications import router as notifications_router
from app.api.routes.users import router as users_router
from app.api.routes.tan_pool import router as tan_pool_router
from app.api.routes.stats import router as stats_router
from app.api.routes.learning import router as learning_router
from app.api.routes.achievements import router as achievements_router
from app.api.routes.templates import router as templates_router
from fastapi.middleware.cors import CORSMiddleware
from app.db.session import SessionLocal
from app.jobs.retention import clean_expired_photos
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from app.core.config import get_settings


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name, version="0.1.0")

    # Rate limiting
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

    scheduler = AsyncIOScheduler()

    # Routers
    app.include_router(health_router, prefix="/health", tags=["health"])
    app.include_router(auth_router, prefix="/auth", tags=["auth"])
    app.include_router(users_router, prefix="/users", tags=["users"])
    app.include_router(tasks_router, prefix="/tasks", tags=["tasks"])
    app.include_router(submissions_router, prefix="/submissions", tags=["submissions"])
    app.include_router(ledger_router, prefix="/ledger", tags=["ledger"])
    app.include_router(photos_router, prefix="/photos", tags=["photos"])
    app.include_router(notifications_router, prefix="/notifications", tags=["notifications"])
    app.include_router(tan_pool_router, prefix="/tan-pool", tags=["tan-pool"])
    app.include_router(stats_router, prefix="/stats", tags=["stats"])
    app.include_router(learning_router, prefix="/learning", tags=["learning"])
    app.include_router(achievements_router, prefix="/achievements", tags=["achievements"])
    app.include_router(templates_router, prefix="/templates", tags=["templates"])

    # CORS for web/desktop
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.get_cors_origins(),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

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
