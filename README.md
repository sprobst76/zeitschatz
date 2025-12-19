# 🪙 ZeitSchatz

Familieninterne App, mit der Kinder durch erledigte Aufgaben virtuelle TANs verdienen. Eltern bestätigen, verwalten Regeln und zahlen TANs manuell aus einem vorgehaltenen Kisi-Vorrat aus (keine automatische Integration). TANs sind 6–8-stellige Codes, gerätegebunden (z. B. Handy/PC) und haben eine Dauer (Minuten) + optionales Ablaufdatum.

## Schnellstart (Entwicklung)

- Voraussetzungen: Docker, Docker Compose, Python 3.11+, Flutter/Dart SDK, `uv` oder `poetry` (Backend).
- Backend lokal starten:
  ```bash
  cp .env.sample .env
  docker-compose up -d db
  uv run fastapi dev backend/app/main.py  # alternativ: poetry run fastapi dev backend/app/main.py
  ```
- Flutter-App:
  ```bash
  cd frontend
  flutter pub get
  flutter run
  ```
- Auth: `POST /auth/login` mit `user_id` + `pin` → Bearer-Token. (User-Seeding/Refresh noch offen.)
- Bekannte Einschränkung: In-Process-TestClient (Starlette/httpx) hängt beim ersten Request in dieser Umgebung. Workaround: echten `uvicorn` starten und via curl/httpx testen (siehe unten).
- Fotos: `/photos/upload?submission_id=` (multipart) speichert im lokalen `STORAGE_DIR`, setzt `photo_expires_at`. Abruf via `/photos/{submission_id}` (auth erforderlich). Retention-Job noch folgen.
- Retention-Job: Läuft täglich 03:00 (APScheduler) und löscht abgelaufene Fotos (`photo_expires_at` oder mtime-Fallback). Logs in stdout.
- Tests (später ergänzen): `uv run pytest` bzw. `poetry run pytest` und `flutter test`.

Mehr Details im vollständigen Plan: `PROJECT.md`.
