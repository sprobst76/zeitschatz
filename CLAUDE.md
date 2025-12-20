# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ZeitSchatz is a family task/reward app where children earn virtual TANs (6-8 digit codes) by completing tasks. Parents approve submissions and manually issue TANs from a pre-existing pool (e.g., Kisi codes). TANs are device-bound (phone/pc/tablet) with duration in minutes and optional expiration.

## Development Commands

### Backend (FastAPI + Python 3.11+)

```bash
# Setup
cp .env.sample .env
python -m venv .venv && source .venv/bin/activate
cd backend && pip install -e ".[dev]"

# Run database
docker-compose up -d db

# Start dev server (from repo root, with venv activated)
uvicorn app.main:app --app-dir backend --host 0.0.0.0 --port 8070 --reload

# Seed initial users (from repo root, with venv activated)
python backend/scripts/seed_users.py
# Or with custom values:
python backend/scripts/seed_users.py --parent-name "Mama" --parent-pin "5678" --child-name "Max" --child-pin "1111"

# Run tests
cd backend && pytest

# Lint
cd backend && ruff check .
```

### Frontend (Flutter/Dart 3.3+)

```bash
cd frontend
flutter pub get

# Run on different platforms
flutter run -d linux
flutter run -d android
flutter run -d chrome --web-port=8081

# Build
flutter build linux
flutter build apk --release
flutter build web

# Run tests
flutter test
```

### Full Smoke Test

```bash
./scripts/dev_smoke.sh  # Starts backend, runs smoke tests, builds Flutter Linux
```

## Architecture

### Backend Structure (`backend/app/`)

- **FastAPI application** with routers organized by domain
- **Routes**: `api/routes/` - auth, tasks, submissions, ledger, photos, notifications
- **Models**: SQLAlchemy models in `models/` - User, Task, Submission, Ledger, Device
- **Schemas**: Pydantic validation in `schemas/`
- **Services**: Business logic in `services/`
- **Jobs**: Background tasks in `jobs/` (photo retention via APScheduler, runs at 03:00)
- **Config**: `core/config.py` uses pydantic-settings, loads from `.env`

API endpoints:
- `/auth/login` - PIN-based auth returning JWT
- `/users` - User CRUD (parent-only): list, create, update, deactivate
- `/users/children` - List child users (parent-only)
- `/tasks` - Task CRUD, `?child_id=` filters for assigned tasks
- `/submissions` - Create/approve/retry submissions
- `/submissions/{id}/approve` - Parent approval with TAN assignment
- `/ledger/{child_id}` - TAN balance and history
- `/photos/upload` - Multipart photo upload
- `/notifications/register` - FCM token registration

### Frontend Structure (`frontend/lib/`)

- **State**: Riverpod-based in `state/` - `SessionNotifier` manages auth state
- **Routing**: GoRouter in `routing/`
- **Services**: `services/api_client.dart` - Dio-based API client
- **Screens**: Role-based screens (child home, parent inbox, role selection)
- **Models**: Domain models in `models/`
- **Widgets**: Reusable components in `widgets/`
- **Offline**: Hive for local persistence and offline queue

API base URL is configured in `services/api_client.dart` (default: `http://192.168.0.144:8070`).

### Database

- SQLite for development (default: `./data/zeit.db`)
- Postgres supported via `DATABASE_URL` env var
- Alembic migrations in `backend/alembic/`

### Key Env Variables

- `DEV_BYPASS_AUTH=true` - Skip auth in dev (accepts all requests as configured user)
- `DEV_USER_ID`, `DEV_USER_ROLE` - User context when auth bypassed
- `CORS_ORIGINS` - Comma-separated origins for web builds
- `STORAGE_DIR` - Photo storage path (default: `/data/photos`)
- `PHOTO_RETENTION_DAYS` - Days before photo auto-deletion (default: 14)
- `FCM_SERVER_KEY` - For push notifications (logged/skipped if empty)

## Important Notes

- Backend uses JWT auth with roles (`parent`/`child`) in claims
- Seed users: PIN `1234` for parent, `0000` for child
- Photos are stored locally, auto-deleted after 14 days by retention job
- In-process TestClient may hang; use live uvicorn server for API tests
- For web builds, ensure CORS and backend TLS/proxy are configured
