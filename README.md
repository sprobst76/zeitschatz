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
- Vorläufige Auth im Backend: Header `X-User-Id` und `X-User-Role` (parent|child) setzen, bis PIN/JWT implementiert ist.
- Tests (später ergänzen): `uv run pytest` bzw. `poetry run pytest` und `flutter test`.

Mehr Details im vollständigen Plan: `PROJECT.md`.
