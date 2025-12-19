# Changelog – ZeitSchatz

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
