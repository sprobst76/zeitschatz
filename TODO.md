# TODO – ZeitSchatz (MVP)

## Backend
- [ ] Alembic Migration ausführen (`uv run alembic upgrade head -c backend/alembic.ini`).
- [ ] Auth-Flow fertigstellen: PIN-Login/JWT ist angelegt, aber User-Management (Anlegen/Seed) und Refresh fehlen.
- [ ] Task-Router: Today-Filter verbessern, Zuweisungen prüfen.
- [ ] Submission-Router: History, bessere Validierungen, Push-Hook.
- [ ] Ledger-Router: Guthaben pro Kind aggregiert, Auszahlungs-Workflow feinjustieren.
- [ ] Photo-Upload Endpoint + Storage-Service (lokal, später MinIO).
- [ ] Notifications-Service (FCM) + Token-Registration.
- [ ] Retention-Job (Fotos löschen nach 14 Tagen).
- [ ] Tests: Services + API (TestClient, SQLite in-memory).
 - [ ] CORS/Ports: Default Backend-Port derzeit 8070 in Flutter-Client; ggf. vereinheitlichen und konfigurierbar machen.

## Frontend (Flutter)
- [ ] Scaffold `main.dart`, Router (GoRouter), State (Riverpod).
- [ ] Rollen-Gate (Parent/Child), PIN/Bio für Eltern.
- [ ] Child: Heute-Liste, Task-Detail, Submission mit optionalem Foto/Overlay, Offline-Queue.
- [ ] Parent: Inbox (Pending), Approve/Retry UI, Task-Management, Payout-Screen (Gerät + Dauer + TAN-Code).
- [ ] Ledger/Guthaben pro Gerät mit Ablaufanzeige.
- [ ] Push-Setup (FCM), Token-Registrierung.
- [ ] Tests: Widget/State, Offline-Queue Mock, API-Client Mock.
 - [ ] Web-Build: FCM entfernt; bei Bedarf Firebase-Pakete aktualisieren oder optional machen; CORS + `baseUrl` konfigurierbar gestalten.

## Infrastruktur/DevEx
- [ ] Makefile/Taskfile für dev Befehle.
- [ ] CI (Lint/Tests) – später.
- [ ] Reverse Proxy Beispiel (Caddy/Nginx) für Prod (später).

## Inhalte/Docs
- [ ] Ausführliche API-Doku (OpenAPI automatisch, README verlinken).
- [ ] Screenshots/Flowcharts, wenn UI steht.
