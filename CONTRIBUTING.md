# Mitwirken bei ZeitSchatz

Vielen Dank fuer dein Interesse an ZeitSchatz! Hier findest du Informationen, wie du zum Projekt beitragen kannst.

## Verhaltenskodex

Bitte lies unseren [Code of Conduct](CODE_OF_CONDUCT.md) bevor du beitraegst.

## Wie kann ich beitragen?

### Fehler melden

1. Pruefe zuerst, ob der Fehler bereits gemeldet wurde (Issues durchsuchen)
2. Erstelle ein neues Issue mit:
   - Klarer Beschreibung des Problems
   - Schritte zur Reproduktion
   - Erwartetes vs. tatsaechliches Verhalten
   - Screenshots falls hilfreich
   - System-Informationen (OS, App-Version, etc.)

### Feature-Vorschlaege

1. Erstelle ein Issue mit dem Label "enhancement"
2. Beschreibe das gewuenschte Feature
3. Erklaere den Anwendungsfall

### Code beitragen

1. **Fork** das Repository
2. **Clone** deinen Fork lokal
3. Erstelle einen **Feature-Branch**: `git checkout -b feature/mein-feature`
4. Mache deine Aenderungen
5. **Teste** deine Aenderungen
6. **Commit** mit aussagekraeftiger Nachricht
7. **Push** zu deinem Fork
8. Erstelle einen **Pull Request**

## Entwicklungsrichtlinien

### Code-Stil

#### Python (Backend)
- Folge PEP 8
- Verwende Type Hints
- Docstrings fuer oeffentliche Funktionen
- Linting mit `ruff check .`

#### Dart (Frontend)
- Folge den [Dart Style Guidelines](https://dart.dev/guides/language/effective-dart/style)
- Verwende `flutter analyze` vor dem Commit

### Commit-Nachrichten

Verwende aussagekraeftige Commit-Nachrichten:

```
Kurze Zusammenfassung (max 50 Zeichen)

Optionale detaillierte Beschreibung. Erklaere WAS und WARUM,
nicht WIE (das sieht man im Code).

- Aufzaehlungspunkte sind okay
- Verwende Imperativ ("Add feature" nicht "Added feature")
```

### Pull Requests

- Beschreibe die Aenderungen klar
- Referenziere relevante Issues (`Fixes #123`)
- Halte PRs fokussiert (eine Sache pro PR)
- Stelle sicher, dass Tests durchlaufen

## Projekt-Struktur

```
backend/
├── app/
│   ├── api/routes/    # API Endpoints
│   ├── models/        # Datenbank-Modelle
│   ├── schemas/       # Request/Response Schemas
│   └── services/      # Business Logic
└── alembic/           # Migrationen

frontend/
└── lib/
    ├── screens/       # UI Screens
    ├── widgets/       # Wiederverwendbare Widgets
    ├── state/         # State Management
    ├── services/      # API Client
    └── models/        # Datenmodelle
```

## Lokale Entwicklung

Siehe [README.md](README.md#entwicklung) fuer Setup-Anweisungen.

## Fragen?

Erstelle ein Issue mit dem Label "question" oder kontaktiere die Maintainer.

## Lizenz

Mit deinem Beitrag stimmst du zu, dass dein Code unter der gleichen [MIT-Lizenz](LICENSE) wie das Projekt veroeffentlicht wird.
