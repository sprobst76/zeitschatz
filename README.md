# 🪙 ZeitSchatz

Familieninterne App, mit der Kinder durch erledigte Aufgaben virtuelle TANs verdienen. Eltern bestätigen, verwalten Regeln und zahlen TANs manuell aus einem vorgehaltenen Kisi-Vorrat aus (keine automatische Integration). TANs sind 6–8-stellige Codes, gerätegebunden (z. B. Handy/PC) und haben eine Dauer (Minuten) + optionales Ablaufdatum.

## Schnellstart (Entwicklung)

- Voraussetzungen: Docker, Docker Compose, Python 3.11+, Flutter/Dart SDK, `uv` oder `poetry` (Backend).
- Backend lokal starten:
  ```bash
  cp .env.sample .env
  # optional: DEV_BYPASS_AUTH=true für Heimnetz ohne Login
  docker-compose up -d db
  uvicorn app.main:app --app-dir backend/app --host 0.0.0.0 --port 8070
  ```
- Flutter-App:
  ```bash
  cd frontend
  flutter pub get
  flutter run -d linux   # oder -d android / -d chrome --web-port=8081
  ```
- Auth: `POST /auth/login` mit `user_id` + `pin` → Bearer-Token. (User-Seeding/Refresh noch offen.)
- Bekannte Einschränkung: In-Process-TestClient (Starlette/httpx) hängt beim ersten Request in dieser Umgebung. Workaround: echten `uvicorn` starten und via curl/httpx testen (siehe unten).
- Fotos: `/photos/upload?submission_id=` (multipart) speichert im lokalen `STORAGE_DIR`, setzt `photo_expires_at`. Abruf via `/photos/{submission_id}` (auth erforderlich). Retention-Job noch folgen.
- Retention-Job: Läuft täglich 03:00 (APScheduler) und löscht abgelaufene Fotos (`photo_expires_at` oder mtime-Fallback). Logs in stdout.
- Push: `POST /notifications/register` speichert FCM-Token. Hooks: Bei neuer Submission Push an Eltern (`submission_pending`), bei Approval optional an Kind (`submission_approved`). Ohne `FCM_SERVER_KEY` wird Push nur geloggt/übersprungen.
- Flutter-Skeleton: `flutter run` startet eine einfache Rollenauswahl (Seed-PINs 1234/0000), Child-Home zeigt Tasks, Parent-Inbox zeigt Pending-Submissions. API-Client unter `frontend/lib/services/api_client.dart`.
- Plattform-Builds:
  - Android: `flutter run -d android` bzw. `flutter build apk --release`
  - Linux: `flutter config --enable-linux-desktop` → `flutter run -d linux` / `flutter build linux`
  - Web/Chrome: `flutter config --enable-web` → `flutter run -d chrome` / `flutter build web`
  - Für Web CORS anpassen (`CORS_ORIGINS` in `.env`, z. B. `http://localhost:8081`), Backend per TLS/Proxy bereitstellen.
- Heimnetz-Dev ohne Login: Setze in `.env` `DEV_BYPASS_AUTH=true` (optional `DEV_USER_ID/ROLE`). Dann akzeptiert das Backend alle Anfragen als den konfigurierten Nutzer.
- Backend-Smoketest + Linux-Build: `./scripts/dev_smoke.sh` (setzt laufende GUI für Linux voraus).
- Tests (später ergänzen): `uv run pytest` bzw. `poetry run pytest` und `flutter test`.

Mehr Details im vollständigen Plan: `PROJECT.md`.
