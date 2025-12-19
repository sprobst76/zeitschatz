from fastapi import FastAPI

from app.api.routes.health import router as health_router
from app.core.config import get_settings


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name, version="0.1.0")

    # Routers
    app.include_router(health_router, prefix="/health", tags=["health"])

    return app


app = create_app()


@app.get("/")
def root():
    return {"status": "ok"}
