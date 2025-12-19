
# 🪙 ZeitSchatz – Umsetzungs-Blueprint

## 1) Produkt-Scope (MVP vs. später)
- MVP: Rollen Parent/Child, Aufgaben mit TAN-Wert (als Dauer in Minuten) und Wochentagen, **gerätegebundene TANs** (phone/pc/tablet) mit Dauer, Submission mit optionalem Foto, TAN-Ledger ohne Abzüge, manuelle Auszahlung-Flag, Push an Eltern (neue Submission, Auszahlung fällig), Offline-Puffer für Kinder, PIN/BIometrie für Eltern, PIN für Kinder, lokales File-Storage, FCM-only SaaS. TAN ist ein **6–8-stelliger Textcode** (kann aus vorab in Kisi generiertem Vorrat stammen), wird pro Auszahlung zugeordnet.
- Später: Badges/Streaks, Web-Read-Only-Dashboard, Auto-Approve-Regeln, Mehrsprachigkeit, Postgres + S3/MinIO, feingranularere Rollen, Telegram/n8n-Exports, Streak-Gamification, bessere Analytics.

## 2) Architektur (Beschreibung statt Grafik)
- Client: Flutter-App (zwei Modi: Child/Parent), nutzt lokales SQLite/Hive für Offline-Queue und Cache.
- Backend: FastAPI + Uvicorn, REST, Auth via JWT mit Rollen (parent/child), Alembic-Migrationen, Hintergrund-Tasks für Retention und Push.
- DB: SQLite (dev/prod klein), später Postgres via ENV umschaltbar.
- Storage: lokales Filesystem `/data/photos/...`, optional MinIO (S3) per ENV.
- Push: FCM; Eltern-Devices registrieren FCM-Tokens, Kinder optional.
- Datenfluss: App → REST (Tasks/Submissions) → DB; Fotos per multipart Upload → Storage → Pfad in DB; Approval erzeugt Ledger-Eintrag; Cron/Task löscht Fotos nach 14 Tagen; Scheduler schickt „Auszahlung fällig“-Push.

## 3) Repo-Struktur (Soll)
```
backend/
  app/
    main.py
    api/__init__.py
    api/routes/{auth,users,tasks,submissions,ledger,photos,notifications}.py
    core/{config,security,dependencies}.py
    models/{base.py,user.py,task.py,submission.py,ledger.py,device.py}
    schemas/{auth.py,user.py,task.py,submission.py,ledger.py,device.py,common.py}
    services/{tasks.py,submissions.py,photos.py,notifications.py,ledger.py}
    db/{session.py,init_db.py}
    jobs/{retention.py,scheduler.py}
    utils/{storage.py,images.py}
  alembic.ini
  alembic/
    env.py
    versions/
  tests/{test_api_tasks.py,...}
frontend/
  lib/
    main.dart
    app.dart
    routing/app_router.dart
    theme/app_theme.dart
    models/{task.dart,submission.dart,ledger_entry.dart,user.dart}
    services/{api_client.dart,auth_service.dart,push_service.dart,offline_queue.dart}
    state/{app_state.dart,task_state.dart,submission_state.dart}
    screens/{auth_pin_screen.dart,child_home_screen.dart,parent_inbox_screen.dart,ledger_screen.dart,task_detail_screen.dart,settings_screen.dart}
    widgets/{task_tile.dart,submission_card.dart,photo_overlay.dart}
  test/
docs/
  rules.md
  privacy.md
README.md
PROJECT.md
docker-compose.yml
.env.sample
```

## 4) Datenbank-Schema (SQLite → Postgres)
- users: id PK, name, role (parent|child), pin_hash, is_active, created_at.
- children_profiles: id PK, user_id FK users.id (role=child), color/icon prefs.
- tasks: id PK, title, description, category, **duration_minutes** int (z. B. 30/60), **target_device** (phone|pc|tablet), requires_photo bool, recurrence json (Mo-So bools), assigned_children json/int array, is_active bool, created_at.
- submissions: id PK, task_id FK, child_id FK users.id, status (pending|approved|retry), comment, photo_path nullable, created_at, updated_at.
- tan_ledger: id PK, child_id FK, submission_id FK nullable, **minutes** int (dauer der Freigabe), **target_device**, **tan_code** (6–8 Stellen), **valid_until** datetime optional, reason, paid_out bool, created_at.
- device_tokens: id PK, user_id FK, fcm_token, platform, created_at.
- photo_blobs (optional später für S3 metadata): id PK, submission_id FK, path, mime, size, expires_at.
- Indizes: submissions (status, created_at), tan_ledger (child_id, paid_out), tasks (is_active), device_tokens (user_id), tan_ledger.tan_code (unique).
- Migration-Strategie: Alembic ab Start nutzen, env.py so, dass SQLite + Postgres funktioniert (saubere types, keine server_default-Funktionen die SQLite nicht kann).

## 5) REST API Design (Auszug)
- Auth: `POST /auth/login` (pin + profile) → JWT, role im Claim; `POST /auth/refresh`.
- Users: `GET /users/me`, `GET /children` (parent only).
- Tasks: `POST /tasks` (parent), `GET /tasks/today?child_id=...`, `PATCH /tasks/{id}` (parent), `POST /tasks/{id}/deactivate`. Payload enthält `duration_minutes` und `target_device`.
- Submissions: `POST /submissions` (child; payload: task_id, comment?, photo_upload_token?), `GET /submissions/pending` (parent), `POST /submissions/{id}/approve`, `POST /submissions/{id}/retry` (comment required), `GET /submissions/history?child_id=...`.
- Photos: `POST /photos/upload` multipart (child) → returns stored path + signed/relative URL; `GET /photos/{id}` protected, parent or owning child.
- Ledger: `GET /ledger/{child_id}`, `POST /ledger/payout` (marks unpaid entries as paid_out=true, reason="payout YYYY-MM-DD") – je Eintrag: `minutes`, `target_device`, optional `valid_until`, optional `tan_code` (6–8 Stellen, z. B. aus Kisi-Vorrat). Endpoint akzeptiert `tan_code` pro Auszahlung.
- Notifications: `POST /notifications/register` (save FCM token), internal service triggers push.
- Beispiele:
```http
POST /submissions
{ "task_id": 12, "comment": "fertig", "photo_path": "/photos/child1/123.jpg" }

POST /submissions/{id}/approve
{ "minutes": 60, "target_device": "phone", "tan_code": "ABC12345", "valid_until": "2024-04-02T20:00:00Z", "comment": "Danke!" }
```
Antwort-Shape: `{"id":1,"status":"pending","created_at":"2024-04-02T18:30:00Z","minutes":60,"target_device":"phone","tan_code":"ABC12345",...}`

## 6) Flutter UI/UX Flow
- Onboarding: Rolle wählen (Eltern/Kinder), Profil-PIN eingeben; Eltern optional Biometrics.
- Child-Flow: Home „Heute“ (Task-Liste mit Status), Task-Detail (Beschreibung, Foto aufnehmen/anhängen mit Overlay-Preview), Submit → Offline-Queue → Sync Status; Ledger-Screen „Mein Guthaben“ (heute/woche/gesamt, pending vs. approved).
- Parent-Flow: PIN/Bio → Inbox (Pending Submissions mit Foto-Thumbnail, Buttons Approve/Retry + Kommentar), Task-Management (Liste, Neu/Bearbeiten, Zuweisung an Kinder), Auszahlung-Screen (Summe unpaid pro Kind + „als ausgezahlt markieren“), Einstellungen (FCM-Token anzeigen/erneuern, Foto-Policy).
- Navigation: GoRouter/Beamer Router mit Guards auf Role-State; Bottom Nav für Kind (Home, Ledger), Drawer/Tab für Eltern (Inbox, Tasks, Ledger, Settings).
- State-Management: Riverpod/Provider (lightweight), lokale Persistence via Hive/Drift für Offline-Queue + Task-Cache.

## 7) Push-Flows (FCM)
- Token-Registrierung: Beim App-Start Eltern-Mode → `POST /notifications/register` (user_id, token, platform).
- Ereignisse:
  - Neue Submission: Backend sendet Push an alle Parent-Tokens `{type:"submission_pending", submission_id, child_name, task_title}`.
  - Auszahlung fällig (daily scheduler): `{type:"payout_reminder", total_pending, date}`.
  - Optional an Kinder bei Approval: `{type:"submission_approved", submission_id, tan_delta}`.
- Topics: vermeiden (kleiner Nutzerkreis), stattdessen per Token. Später Topic „payout_reminder“ für alle Eltern möglich.

## 8) Foto-Pipeline
- App: Kamera direkt, Overlay (Timestamp, Task, Child), Kompression (lange Kante ~1280px, JPEG 75%), temporär lokal speichern, dann Upload multipart.
- Backend: Endpoint speichert unter `/data/photos/{child_id}/{submission_id}/{uuid}.jpg`, erzeugt relative URL; DB speichert Pfad + expires_at (created_at + 14d).
- Retention: Background-Job täglich, löscht Dateien und DB-Einträge mit expires_at < now; entfernt verwaiste Files.
- Sicherheit: Nur authentifizierte Zugriffe; Download-Endpoint prüft Rolle (parent or owning child), sendet als attachment/stream.

## 9) Offline-Queue Design
- Lokal (Hive/Drift) Tabelle `pending_ops`: id, type (submit_task), payload JSON, blob_path optional, status (queued|uploading|failed), retry_count, last_error.
- Submission Flow offline: Speichere Task-Daten + Foto-Datei im App-Storage; Sync-Service versucht Upload wenn online → zuerst Foto, erhält photo_path, dann Submission POST; bei Erfolg lösche Queue-Eintrag.
- Konflikte: Falls Task deaktiviert wurde, markiere Queue-Eintrag als failed mit Hinweis; Child sieht „Task nicht mehr gültig“.
- Retry: Exponentielles Backoff (z. B. 5s, 30s, 5m, 30m), max Versuche bevor „manuelle Aktion nötig“ angezeigt.

## 10) Testing-Strategie
- Backend: Unit-Tests für Services (Tasks, Ledger, Photo-Path), API-Tests mit TestClient + SQLite in-memory, Alembic migration test, Retention-Job test mit tmpdir.
- Frontend: Unit/Widget-Tests für View-Model/State, Golden-Tests für wichtige Screens, Integration-Test (flutter drive) für Submission-Flow ohne Kamera (Mock), offline-queue test mit mock http.
- E2E später: docker-compose + backend + emulator? Minimale Smoke: start backend, run flutter integration tests against mock server.

## 11) Security & Privacy Checkliste
- Auth: JWT kurzlebig + refresh, PIN-Hash (argon2/bcrypt), Eltern optional Biometrie clientseitig.
- Transport: HTTPS empfohlen (reverse proxy), HTTP-only Cookie optional oder bearer.
- RBAC: parents dürfen alles, children nur eigene Submissions/Tasks.
- Storage: Fotos nur serverseitig, nicht in Cloud; 14d Retention; Zugriffsschutz auf Endpoints.
- Logging: Keine Foto-URLs im Klartext in Logs; PII minimal; Rate-Limits für PIN-Eingaben; Brute-Force-Schutz serverseitig (Lockout nach N Fehlversuchen).
- Backup: DB-Backup möglich, Fotos nicht langfristig (Retention!).

## 12) Deployment-Plan
- Local dev: docker-compose (FastAPI + SQLite + optional MinIO), `.env` laden, Hot-Reload via `fastapi dev`.
- Prod (VPS): Docker Compose mit Uvicorn/Gunicorn, SQLite persistentes Volume oder Postgres-Container; Nginx/Caddy als TLS-Terminator/Reverse Proxy; FCM Server Key als Secret; volumes `/data/photos`.
- Self-Hosting: .env.example bereitstellen, keine externen SaaS außer FCM; Cron/Task via `apscheduler` in app oder separatem worker container.

## 13) Sprints (5–8)
1. Skeleton & Auth: Repo-Struktur, FastAPI+Alembic+JWT+PIN-Hash, Flutter Grundnavigation + Role-Gate, Basic theming. Akzeptanz: Login per Dummy-User funktioniert, protected endpoint erreichbar.
2. Tasks Core: Task CRUD (parent), Task-Liste Kind (today), recurrence handling, assigned_children. Akzeptanz: Kind sieht nur zugewiesene Tasks des Tages.
3. Submissions & Ledger: Submission create, approve/retry, ledger Einträge, Auszahlung-Flag, Eltern-Inbox UI. Akzeptanz: Approve erzeugt Ledger, Auszahlung markiert paid_out.
4. Offline & Queue: Lokaler Cache, Queue für Submissions, Retry-Logik, Sync-Indicator. Akzeptanz: Flugmodus → Queue, nach Online Sync sichtbar.
5. Photos: Kamera + Overlay + Upload, Storage Pfad, Foto-Vorschau in Inbox, Retention-Job. Akzeptanz: Foto wird gespeichert, nach Ablauf gelöscht (simulierter Job).
6. Push & Reminders: FCM Token-Registrierung, Submission-Push an Eltern, Payout-Reminder Scheduler. Akzeptanz: Token gespeichert, Dummy-Push empfangen.
7. Polishing & Privacy: PIN-Beschränkung, Fehlerzustände, UI-Polish, Privacy text, logs cleanup. Akzeptanz: Checkliste erfüllt, Lint/Tests grün.

## 14) Risiken & Mitigation
- FCM Setup/Keys falsch: Frühzeitiger Smoke-Test mit Dummy-App, Keys aus ENV, Monitoring auf Push-Fehler.
- Kamera/Permissions: Früh testen auf günstigen Android-Versionen, Fallback auf Galerie optional, klare Fehlermeldung.
- Offline-Sync: Komplexität hoch → minimaler Queue-Umfang, klare Konfliktmeldungen, Telemetrie (lokal) für Fehler.
- SQLite Locks: Schreibzugriffe kurz halten, Pydantic/ORM Session-Scopes sauber, später Postgres vorbereiten.
- Foto-Speicher wächst: Retention-Job + Max-Size + Kompression, Warnung bei fehlendem Speicher.
- Eltern-PIN Bruteforce: Server Lockout, Client Delay, Logging ohne PII.

## 15) Day-1 Next Actions (Checkliste)
- [ ] Repo-Struktur anlegen (backend/app, frontend/lib, docs).
- [ ] `.env` aus `.env.sample` kopieren, dev-Werte setzen.
- [ ] FastAPI `main.py` mit Health-Route + Settings laden.
- [ ] Alembic initialisieren, erste Migration für users/tasks/submissions/ledger/device_tokens.
- [ ] Flutter `pubspec.yaml` anlegen, minimale `main.dart` mit Riverpod/Router.
- [ ] docker-compose up (db + backend), einfache GET /health testen.
- [ ] Notion/Board: Sprint 1 Tasks anlegen mit Acceptance.
