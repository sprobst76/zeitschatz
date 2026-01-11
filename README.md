# ZeitSchatz

Eine Familien-App zur Aufgabenverwaltung und Belohnung. Kinder erledigen Aufgaben und verdienen Bildschirmzeit (TANs), die von Eltern verwaltet und freigegeben werden.

## Features

- **Aufgabenverwaltung**: Eltern erstellen Aufgaben mit Beschreibung und TAN-Belohnung
- **Foto-Nachweis**: Kinder koennen Fotos als Erledigungsnachweis hochladen
- **TAN-System**: Virtuelle Zeitgutscheine fuer verschiedene Geraete (Handy, PC, Tablet)
- **Multi-Familie**: Unterstuetzung fuer mehrere Familien mit Einladungscodes
- **Kindgerechter Login**: Einfache Login-Codes wie "TIGER-BLAU-42"
- **Biometrische Anmeldung**: Fingerabdruck-Login fuer Eltern
- **Web & Android**: Plattformuebergreifend nutzbar

## Screenshots

*Coming soon*

## Installation

### Android App

1. APK von [Releases](../../releases) herunterladen
2. Auf dem Geraet "Unbekannte Quellen" erlauben
3. APK installieren

### Web-Version

Die Web-App ist unter deiner konfigurierten Domain erreichbar.

### Selbst hosten

Siehe [Deployment Guide](docs/DEPLOYMENT.md) fuer eine detaillierte Anleitung.

## Entwicklung

### Voraussetzungen

- Python 3.11+
- Flutter/Dart SDK 3.3+
- Docker & Docker Compose

### Backend starten

```bash
# Umgebungsvariablen kopieren
cp .env.sample .env

# Datenbank starten
docker-compose up -d db

# Backend starten
uvicorn app.main:app --app-dir backend --host 0.0.0.0 --port 8070 --reload
```

### Frontend starten

```bash
cd frontend
flutter pub get

# Linux Desktop
flutter run -d linux

# Android
flutter run -d android

# Web (Port 8081)
flutter run -d chrome --web-port=8081
```

### Tests

```bash
# Backend
cd backend && pytest

# Frontend
cd frontend && flutter test
```

## Architektur

```
ZeitSchatz/
├── backend/           # FastAPI Backend (Python)
│   ├── app/
│   │   ├── api/       # REST Endpoints
│   │   ├── models/    # SQLAlchemy Models
│   │   ├── schemas/   # Pydantic Schemas
│   │   └── services/  # Business Logic
│   └── alembic/       # Database Migrations
├── frontend/          # Flutter App (Dart)
│   └── lib/
│       ├── screens/   # UI Screens
│       ├── state/     # Riverpod State
│       └── services/  # API Client
└── docs/              # Dokumentation
```

## API Dokumentation

Nach dem Start des Backends ist die interaktive API-Dokumentation verfuegbar unter:
- Swagger UI: `http://localhost:8070/docs`
- ReDoc: `http://localhost:8070/redoc`

## Mitwirken

Siehe [CONTRIBUTING.md](CONTRIBUTING.md) fuer Richtlinien zur Mitarbeit.

## Sicherheit

Sicherheitsprobleme bitte an die im [SECURITY.md](SECURITY.md) genannte Adresse melden.

## Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert - siehe [LICENSE](LICENSE) fuer Details.

## Danksagung

- Entwickelt mit [Claude Code](https://claude.ai/code)
- Icons erstellt mit SVG
