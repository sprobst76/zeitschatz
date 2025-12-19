from fastapi import FastAPI

from app.api.routes.health import router as health_router
from app.api.routes.tasks import router as tasks_router
from app.api.routes.submissions import router as submissions_router
from app.api.routes.ledger import router as ledger_router
from app.api.routes.auth import router as auth_router
from app.core.config import get_settings


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name, version="0.1.0")

    # Routers
    app.include_router(health_router, prefix="/health", tags=["health"])
    app.include_router(auth_router, prefix="/auth", tags=["auth"])
    app.include_router(tasks_router, prefix="/tasks", tags=["tasks"])
    app.include_router(submissions_router, prefix="/submissions", tags=["submissions"])
    app.include_router(ledger_router, prefix="/ledger", tags=["ledger"])

    return app


app = create_app()


@app.get("/")
def root():
    return {"status": "ok"}
