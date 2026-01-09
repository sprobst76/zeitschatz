# TODO – ZeitSchatz (MVP)

## Backend

### Fertig
- [x] Alembic Migration (0001_initial).
- [x] Auth: PIN-Login → JWT (`/auth/login`, `/auth/me`).
- [x] Task-Router: CRUD, `child_id`-Filter.
- [x] Submission-Router: create, pending, approve, retry + Push-Hooks.
- [x] Ledger-Router: list, payout, mark-paid.
- [x] Photo-Upload + Storage-Service (lokal).
- [x] Notifications-Service + Token-Registration.
- [x] Retention-Job (APScheduler, 03:00 Uhr).

### Offen
- [x] User-Seeding / Admin-Endpoint zum Anlegen neuer Nutzer.
  - Seed-Script: `python backend/scripts/seed_users.py` (mit `--parent-name`, `--parent-pin` etc.)
  - API: `POST /users`, `GET /users`, `GET /users/children`, `PATCH /users/{id}`, `DELETE /users/{id}` (parent-only)
- [ ] Auth: Refresh-Token-Endpoint.
- [ ] Task-Router: Today-Filter mit Wochentag-Logik (`recurrence` JSON auswerten).
- [ ] Submission-Router: History-Endpoint (`/submissions/history?child_id=...`).
- [ ] Ledger-Router: Aggregat-Endpoint (Summe unbezahlt pro Kind/Gerät).
- [ ] Tests: Services + API (pytest, SQLite in-memory).
- [ ] MinIO/S3-Storage optional aktivierbar machen.

## Frontend (Flutter)

### Fertig
- [x] Scaffold `main.dart`, Router (GoRouter), State (Riverpod).
- [x] Rollen-Auswahl (RoleSelectScreen) mit Seed-PINs.
- [x] Child: Task-Liste mit Submit-Button.
- [x] Parent: Inbox mit Approve/Retry-Dialogen.

### Offen
- [ ] PIN-Eingabe (eigener Screen statt Seed-Auswahl), optional Biometrie für Eltern.
- [ ] Child: Task-Detail-Screen mit Beschreibung.
- [ ] Child: Foto-Aufnahme mit Overlay (Timestamp, Task) + Upload.
- [ ] Child: Offline-Queue (Hive) für Submissions ohne Netz.
- [ ] Parent: Task-Management (Liste, Neu/Bearbeiten, Zuweisung).
- [ ] Parent: Payout-Screen (unbezahlte Einträge markieren, TAN eingeben).
- [ ] Ledger-Screen: Guthaben pro Gerät mit Ablaufanzeige (Kind + Eltern).
- [ ] Push-Setup: FCM-Token registrieren, Benachrichtigungen empfangen.
- [ ] `baseUrl` konfigurierbar machen (Settings oder .env-Datei).
- [ ] Tests: Widget/State, Offline-Queue Mock, API-Client Mock.

## Infrastruktur/DevEx
- [ ] Makefile/Taskfile für häufige dev-Befehle.
- [ ] CI-Pipeline (Lint + Tests) für GitHub Actions.
- [ ] Reverse-Proxy-Beispiel (Caddy/Nginx) für Prod-Deployment.

## Design / Branding
- [x] App-Icon erstellt (minimalistisch: goldene Uhr auf blauem Hintergrund)
- [ ] Alternative: Detailliertes Icon mit Schatztruhe + Uhr (`assets/icon/zeitschatz_icon.svg`, `icon_512_detailed.png`) - evtl. für Splash-Screen oder Marketing
- [ ] Splash-Screen mit Animation (Uhr/Schatztruhe)
- [ ] App-Store Screenshots

## Docs
- [ ] OpenAPI-Doku verlinken (FastAPI generiert automatisch unter `/docs`).
- [ ] Screenshots/Flowcharts ergänzen, sobald UI steht.
