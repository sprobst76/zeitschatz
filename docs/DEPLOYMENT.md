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
  /pfad/zu/ZeitSchatz/ \
  user@your-server:/srv/zeitschatz/
```

### 2. Auf dem VPS

```bash
ssh user@your-server
cd /srv/zeitschatz

# .env.prod aus .env.prod.sample erstellen und anpassen
cp .env.prod.sample .env.prod
nano .env.prod  # Domain und SECRET_KEY setzen

# Deployment starten
./deploy.sh
```

### 3. DNS konfigurieren

Stelle sicher, dass diese DNS-Eintraege existieren:

```
zeitschatz-api.YOUR_DOMAIN -> YOUR_SERVER_IP
zeitschatz.YOUR_DOMAIN     -> YOUR_SERVER_IP
```

## URLs nach Deployment

- **API**: https://zeitschatz-api.YOUR_DOMAIN
- **Web-App**: https://zeitschatz.YOUR_DOMAIN
- **Health-Check**: https://zeitschatz-api.YOUR_DOMAIN/health

## Android App

Die Produktions-APK wird mit dem Deploy-Script gebaut:

```bash
./scripts/deploy-apk.sh
```

### Installation auf Android

1. APK auf das Geraet uebertragen (USB, Cloud, etc.)
2. In den Einstellungen "Unbekannte Quellen" erlauben
3. APK oeffnen und installieren

## Erste Benutzer anlegen

Nach dem Deployment muessen Benutzer angelegt werden:

```bash
# Auf dem VPS
docker exec -it zeitschatz-api python scripts/seed_users.py \
  --parent-name "Mama" --parent-pin "1234" \
  --child-name "Max" --child-pin "0000"
```

Oder via API:

```bash
# Login als Parent (nach erstem Seed)
TOKEN=$(curl -s -X POST https://zeitschatz-api.YOUR_DOMAIN/auth/login \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "pin": "1234"}' | jq -r '.access_token')

# Kind hinzufuegen
curl -X POST https://zeitschatz-api.YOUR_DOMAIN/users \
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
