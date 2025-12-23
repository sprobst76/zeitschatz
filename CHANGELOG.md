# Changelog – ZeitSchatz

## 2025-12-22 (Multi-Family + Provider)

### Multi-Family Support (Backend)
- **Database**: Neue Tabellen `families`, `family_members`, `device_providers`, `reward_providers`
- **Migration**: `0009_multi_family.py` - `family_id` auf Tasks, TanPool, Submissions, TanLedger
- **User-Model**: Email/Password-Felder für Eltern-Registrierung (`email`, `password_hash`, `email_verified`, `verification_token`, `reset_token`)

### Modulare Provider-Abstraktion
- **Provider-System**: Abstrakte Basis `RewardProvider` mit konkreten Implementierungen:
  - `KisiProvider` - TAN-basierte Belohnungen (Salfeld Kisi)
  - `FamilyLinkProvider` - Manuelle Zeiterfassung (Google Family Link)
  - `ManualProvider` - Einfaches Tracking ohne externes System
- **Provider pro Gerät**: Familie kann verschiedene Provider für PC, Handy, Tablet, Konsole nutzen

### Auth-Erweiterungen
- `POST /auth/register` - Email/Passwort-Registrierung mit Verifizierung
- `POST /auth/verify-email` - Email-Verifizierung
- `POST /auth/login/email` - Email/Passwort-Login (Eltern)
- `POST /auth/login/pin` - PIN-Login mit Familiencode (Kinder)
- `POST /auth/forgot-password` - Passwort-Reset anfordern
- `POST /auth/reset-password` - Passwort zurücksetzen

### Family Management API
- `POST /families` - Familie erstellen (wird Admin)
- `GET /families` - Eigene Familien auflisten
- `POST /families/{id}/children` - Kind zur Familie hinzufügen
- `POST /families/{id}/invite` - Einladungscode generieren
- `POST /families/join` - Mit Code beitreten
- `GET/PATCH /families/{id}/devices/{type}` - Provider pro Gerät konfigurieren
- `GET /families/providers/available` - Verfügbare Provider auflisten

### Services
- **Email-Service** (`app/services/email.py`): SMTP-basierter Versand für Verifizierung, Passwort-Reset, Einladungen

### Config
- SMTP-Einstellungen: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM`
- App-URLs: `APP_URL`, `FRONTEND_URL`
- `INVITE_CODE_EXPIRY_DAYS` (default: 7)

### Family-Scoped Endpoints (Phase 5)
Alle bestehenden Endpoints wurden auf Multi-Family umgestellt:
- **Tasks**: `family_id` Filter, Zugriffsprüfung, automatische Zuordnung bei Erstellung
- **Submissions**: `family_id` Filter bei create/list/approve/retry
- **TAN-Pool**: `family_id` Pflichtparameter, Import/List/Stats/Next alle family-scoped
- **Ledger**: `family_id` Filter bei my/aggregate/list/payout/mark-paid

Neue Helper in `dependencies.py`:
- `verify_family_access(db, user_id, family_id)` - Prüft Family-Mitgliedschaft
- `get_user_family_ids(db, user_id)` - Gibt alle Family-IDs des Users zurück

---

## 2025-12-22 (Dark Mode + Deploy)
- Dark Mode: Alle 18 Screens auf Theme-aware Farben umgestellt.
- Fix: `withOpacity()` durch `withValues(alpha: ...)` ersetzt (Flutter Deprecation).
- Fix: Hardcodierte Farben (`Colors.*.shade*`) durch `Theme.of(context).colorScheme.*` ersetzt.
- Fix: Android INTERNET Permission im Release-Manifest hinzugefügt.
- Fix: Hardcodierte API-URL in `role_select_screen.dart` durch `AppConfig.apiBaseUrl` ersetzt.
- Deploy: APK-Deploy-Skript mit GitHub Releases + Telegram-Benachrichtigung (`scripts/deploy-apk.sh`).
- Deploy: n8n Workflow für APK-Release Notifications (`scripts/n8n-apk-release-workflow.json`).
- Ops: CORS Origins um `capacitor://localhost` erweitert für Android-App.
- Ops: n8n Payload-Limit auf 100MB erhöht, ZeitSchatz-Ordner gemountet.

## 2025-12-20
- Auth: Refresh-Token-Flow ergänzt und JWT-Claims stabilisiert (`sub` als String).
- Tasks: Today-Endpoint mit Recurrence-Filter (`/tasks/today`).
- Submissions: History-Endpoint, Approval mit sauberem 409 bei doppeltem TAN.
- Ledger: Aggregat-Endpoint + 409 bei doppeltem TAN.
- Migration: `photo_expires_at` nachgezogen (idempotent).
- Frontend: Auto-Refresh auf 401, neue Parent-Workflows (Aufgaben, Kinder, TAN-Übersicht).
- Frontend: Child-Flow mit Task-Detail, Foto-Upload und TAN-Budget-Tab.
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
