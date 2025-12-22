# ZeitSchatz Deployment Guide

## Voraussetzungen auf dem VPS

- Docker & Docker Compose
- Traefik mit Let's Encrypt (bereits konfiguriert)
- `ai-lab` Docker Network

## Schnellstart

### 1. Projekt auf den VPS kopieren

```bash
# Vom lokalen Rechner:
rsync -avz --exclude '.venv' --exclude 'build' --exclude '.dart_tool' \
  /home/spro/development/ZeitSchatz/ \
  root@91.99.200.244:/srv/zeitschatz/
```

### 2. Auf dem VPS

```bash
ssh root@91.99.200.244
cd /srv/zeitschatz

# Prüfen dass .env.prod existiert
cat .env.prod

# Deployment starten
./deploy.sh
```

### 3. DNS konfigurieren

Stelle sicher, dass diese DNS-Einträge existieren:

```
zeitschatz-api.halbewahrheit21.de -> 91.99.200.244
zeitschatz.halbewahrheit21.de     -> 91.99.200.244
```

## URLs nach Deployment

- **API**: https://zeitschatz-api.halbewahrheit21.de
- **Web-App**: https://zeitschatz.halbewahrheit21.de
- **Health-Check**: https://zeitschatz-api.halbewahrheit21.de/health

## Android App

Die Produktions-APK ist vorkonfiguriert für die API:

```
/home/spro/development/ZeitSchatz/ZeitSchatz-prod.apk
```

### Installation auf Android

1. APK auf das Gerät übertragen (USB, Cloud, etc.)
2. In den Einstellungen "Unbekannte Quellen" erlauben
3. APK öffnen und installieren

## Erste Benutzer anlegen

Nach dem Deployment müssen Benutzer angelegt werden:

```bash
# Auf dem VPS
docker exec -it zeitschatz-api python scripts/seed_users.py \
  --parent-name "Mama" --parent-pin "1234" \
  --child-name "Max" --child-pin "0000"
```

Oder via API:

```bash
# Login als Parent (nach erstem Seed)
TOKEN=$(curl -s -X POST https://zeitschatz-api.halbewahrheit21.de/auth/login \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "pin": "1234"}' | jq -r '.access_token')

# Kind hinzufügen
curl -X POST https://zeitschatz-api.halbewahrheit21.de/users \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Lisa", "role": "child", "pin": "1111"}'
```

## Logs & Debugging

```bash
# Alle Logs
docker compose -f docker-compose.prod.yml logs -f

# Nur API Logs
docker compose -f docker-compose.prod.yml logs -f zeitschatz-api

# Container Status
docker compose -f docker-compose.prod.yml ps
```

## Updates deployen

```bash
cd /srv/zeitschatz
git pull  # oder rsync vom lokalen Rechner

# Rebuild und Restart
docker compose -f docker-compose.prod.yml --env-file .env.prod build
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d
```

## Backup

Die Daten liegen im Docker Volume `zeitschatz_data`:

```bash
# Backup erstellen
docker run --rm -v zeitschatz_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/zeitschatz-backup-$(date +%Y%m%d).tar.gz /data

# Backup wiederherstellen
docker run --rm -v zeitschatz_data:/data -v $(pwd):/backup alpine \
  tar xzf /backup/zeitschatz-backup-YYYYMMDD.tar.gz -C /
```
