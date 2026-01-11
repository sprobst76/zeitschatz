# Sicherheitsrichtlinie

## Unterstuetzte Versionen

| Version | Unterstuetzt       |
| ------- | ------------------ |
| latest  | :white_check_mark: |

## Sicherheitsluecke melden

Wenn du eine Sicherheitsluecke entdeckst, melde sie bitte **nicht** oeffentlich ueber Issues.

### So meldest du eine Sicherheitsluecke:

1. **Erstelle einen privaten Security Advisory** ueber GitHub:
   - Gehe zu "Security" > "Advisories" > "New draft security advisory"

2. **Oder kontaktiere uns direkt** per E-Mail (falls im Profil hinterlegt)

### Was in deiner Meldung enthalten sein sollte:

- Beschreibung der Sicherheitsluecke
- Schritte zur Reproduktion
- Moegliche Auswirkungen
- Vorgeschlagene Loesung (falls vorhanden)

### Was du erwarten kannst:

- **Bestaetigung** innerhalb von 48 Stunden
- **Regelmaessige Updates** zum Fortschritt
- **Anerkennung** in den Release Notes (falls gewuenscht)

## Sicherheits-Best-Practices

### Fuer Betreiber

- Verwende immer HTTPS in Produktion
- Generiere sichere `SECRET_KEY` Werte: `openssl rand -hex 32`
- Halte alle Abhaengigkeiten aktuell
- Beschraenke Netzwerkzugriff auf notwendige Ports
- Aktiviere Firewall-Regeln
- Pruefe regelmaessig Container-Images auf Schwachstellen

### Fuer Entwickler

- Keine Secrets in Code oder Git-History
- Verwende `.env` Dateien (in `.gitignore`)
- Validiere alle Benutzereingaben
- Nutze parametrisierte Datenbankabfragen
- Folge dem Prinzip der minimalen Rechte

## Bekannte Sicherheitsmassnahmen

- JWT-basierte Authentifizierung mit Ablaufzeit
- Passwort-Hashing mit bcrypt
- Rate-Limiting auf Auth-Endpoints
- CORS-Konfiguration
- Input-Validierung mit Pydantic
- SQL-Injection-Schutz durch SQLAlchemy ORM
- Automatische Loeschung inaktiver Accounts (90 Tage)
- Foto-Retention mit automatischer Loeschung
