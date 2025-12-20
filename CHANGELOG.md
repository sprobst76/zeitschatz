# Changelog – ZeitSchatz

## 2025-12-20
- Auth: Refresh-Token-Flow ergänzt und JWT-Claims stabilisiert (`sub` als String).
- Tasks: Today-Endpoint mit Recurrence-Filter (`/tasks/today`).
- Submissions: History-Endpoint, Approval mit sauberem 409 bei doppeltem TAN.
- Ledger: Aggregat-Endpoint + 409 bei doppeltem TAN.
- Migration: `photo_expires_at` nachgezogen (idempotent).
- Frontend: Auto-Refresh auf 401, History/Aggregate-Screens und Today-Tasks.
- Ops: Start-Skripte, CORS als JSON-Liste, Remote-Notizen in `docs/ops.md`.

## 2024-12-19
- User-Management API: `POST/GET/PATCH/DELETE /users`, `GET /users/children` (parent-only).
- Seed-Script erweitert: CLI-Parameter für Namen/PINs (`--parent-name`, `--child-pin`, etc.).
- CLAUDE.md erstellt für Claude Code Kontext.
- TODO.md überarbeitet: erledigte Punkte markiert, offene Punkte konkretisiert.

## 2024-04-02
- Initiales Backend-Skeleton (FastAPI, Health-Route, Settings).
- Datenmodell: Users, ChildProfile, Tasks (mit duration_minutes, target_device), Submissions, TanLedger (minutes, target_device, tan_code, valid_until), DeviceTokens.
- Alembic-Setup mit erster Migration.
- Projekt-Blueprint (PRODUCT/ARCHitektur), Docker-Compose, ENV-Sample, Flutter/Backend Dependency Files.

## 2024-04-03
- Auth: PIN-Login + JWT, bcrypt-Hashing; Seed-Skript für Parent/Child.
- Foto-Upload/Download + Storage-Service; Retention-Job (APScheduler, 03:00).
- Push-Stubs: Token-Registrierung, Hooks bei Submission/Approve (skip ohne FCM-Key).
- Dev-Bypass-Auth Option für Heimnetz-Tests (`DEV_BYPASS_AUTH`).
- Flutter-Skeleton mit Rollenauswahl, Kind-Home (Tasks + Erledigt-Button), Eltern-Inbox (Approve/Retry-Dialoge).
- Flutter-Plattform-Support (Android/Linux/Web) hinzugefügt; Base-URL default auf Port 8070.
- Smoke-Skript für Backend + Linux-Build (`scripts/dev_smoke.sh`), SessionNotifier-Test.
