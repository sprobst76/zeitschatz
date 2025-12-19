# TODO – ZeitSchatz (MVP)

## Backend
- [ ] Alembic Migration ausführen (`uv run alembic upgrade head -c backend/alembic.ini`).
- [ ] Auth-Flow: PIN-Login, JWT, Rollen-Scopes.
- [ ] Task-Router: CRUD, Today-Filter, Zuweisungen.
- [ ] Submission-Router: Create (inkl. Foto-Pfad), Approve/Retry, History.
- [ ] Ledger-Router: Guthaben pro Kind, Payout (setzt `tan_code`, `valid_until`, `paid_out`).
- [ ] Photo-Upload Endpoint + Storage-Service (lokal, später MinIO).
- [ ] Notifications-Service (FCM) + Token-Registration.
- [ ] Retention-Job (Fotos löschen nach 14 Tagen).
- [ ] Tests: Services + API (TestClient, SQLite in-memory).

## Frontend (Flutter)
- [ ] Scaffold `main.dart`, Router (GoRouter), State (Riverpod).
- [ ] Rollen-Gate (Parent/Child), PIN/Bio für Eltern.
- [ ] Child: Heute-Liste, Task-Detail, Submission mit optionalem Foto/Overlay, Offline-Queue.
- [ ] Parent: Inbox (Pending), Approve/Retry UI, Task-Management, Payout-Screen (Gerät + Dauer + TAN-Code).
- [ ] Ledger/Guthaben pro Gerät mit Ablaufanzeige.
- [ ] Push-Setup (FCM), Token-Registrierung.
- [ ] Tests: Widget/State, Offline-Queue Mock, API-Client Mock.

## Infrastruktur/DevEx
- [ ] Makefile/Taskfile für dev Befehle.
- [ ] CI (Lint/Tests) – später.
- [ ] Reverse Proxy Beispiel (Caddy/Nginx) für Prod (später).

## Inhalte/Docs
- [ ] Ausführliche API-Doku (OpenAPI automatisch, README verlinken).
- [ ] Screenshots/Flowcharts, wenn UI steht.
