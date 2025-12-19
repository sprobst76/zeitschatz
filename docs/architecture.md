# Architektur – ZeitSchatz

## Überblick
- Frontend: Flutter (Android-first), zwei Rollen (Child/Parent) in einer App. Offline-First mit lokalem Cache/Queue (Hive/Drift).
- Backend: FastAPI + Uvicorn, REST, JWT mit Rollen. Alembic für Migrationen. Hintergrundjobs (Retention, Payout-Reminder) per APScheduler.
- DB: SQLite (MVP) → Postgres per ENV.
- Storage: Lokales Filesystem `/data/photos` (MVP), optional MinIO (S3).
- Push: FCM, Tokens pro Gerät/User.

## Datenfluss
1. Kind ruft Tasks des Tages ab.
2. Kind erstellt Submission (optional mit Foto): Foto-Upload → Pfad in Submission.
3. Eltern sehen Pending-Queue, Approve/Retry.
4. Approval erzeugt Ledger-Eintrag mit `minutes`, `target_device`, optional `tan_code` und `valid_until`.
5. Payout-Reminder/Push: Scheduler checkt offene Einträge.
6. Retention-Job löscht Fotos nach 14 Tagen.

## Komponenten
- API-Router: auth, users/children, tasks, submissions, ledger, photos, notifications.
- Services: Task-Logik (recurrence/today), Submission-Workflow, Ledger/Payout, Photo-Storage, Notifications.
- Jobs: retention (Fotos), scheduler (payout reminder).
- Utilities: storage (pfade/s3), images (overlay/cleanup).

## Sicherheits-/Privatsphäre-Grundzüge
- Rollenprüfung (parent/child), PIN-Hash serverseitig.
- HTTPS empfohlen, JWT kurzlebig.
- Fotos nur auth zugänglich, Retention 14 Tage.
- Rate-Limits/Lockout gegen PIN-Bruteforce (noch zu implementieren).

## Deployment (MVP)
- Docker Compose: backend (uvicorn), db (postgres oder sqlite-volume), optional minio.
- Volumes: `/data/photos` (Storage), DB-Daten.
- Reverse Proxy (Caddy/Nginx) vorne dran für TLS (nicht im Repo enthalten).
