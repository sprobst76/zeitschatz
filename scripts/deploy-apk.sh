#!/bin/bash
# ZeitSchatz APK Deploy Script
# Baut die APK, erstellt GitHub Release, sendet Telegram-Benachrichtigung

set -e

# Ins Projektverzeichnis wechseln
cd "$(dirname "$0")/.."

# Lokale Konfiguration laden (nicht im Repo)
if [ -f ".env.local" ]; then
  source .env.local
else
  echo "FEHLER: .env.local nicht gefunden!"
  echo "Erstelle .env.local mit folgenden Variablen:"
  echo "  DEPLOY_API_URL=https://zeitschatz-api.your-domain.de"
  echo "  DEPLOY_N8N_WEBHOOK=http://your-n8n:5678/webhook/apk-release"
  echo "  DEPLOY_GITHUB_REPO=username/zeitschatz"
  exit 1
fi

# Pflicht-Variablen pruefen
: "${DEPLOY_API_URL:?Variable DEPLOY_API_URL nicht gesetzt}"
: "${DEPLOY_GITHUB_REPO:?Variable DEPLOY_GITHUB_REPO nicht gesetzt}"

# Farben fuer Output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== ZeitSchatz APK Deploy ===${NC}"

# Version generieren
VERSION="v$(date +%Y%m%d-%H%M)"
APK_NAME="ZeitSchatz-${VERSION}.apk"

# 1. Flutter Build
echo -e "${BLUE}[1/4] Flutter APK bauen...${NC}"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
cd frontend
flutter build apk --release --dart-define=API_BASE_URL="$DEPLOY_API_URL"
cd ..

# APK kopieren und umbenennen
cp frontend/build/app/outputs/flutter-apk/app-release.apk "./${APK_NAME}"

# 2. GitHub Release erstellen
echo -e "${BLUE}[2/4] GitHub Release erstellen...${NC}"
RELEASE_URL=$(gh release create "$VERSION" "./${APK_NAME}" \
  --repo "$DEPLOY_GITHUB_REPO" \
  --title "ZeitSchatz $VERSION" \
  --notes "Android APK Build $(date '+%Y-%m-%d %H:%M')")

DOWNLOAD_URL="https://github.com/${DEPLOY_GITHUB_REPO}/releases/download/${VERSION}/${APK_NAME}"

echo -e "${GREEN}Release erstellt: ${RELEASE_URL}${NC}"

# 3. Telegram Benachrichtigung via n8n (optional)
if [ -n "$DEPLOY_N8N_WEBHOOK" ]; then
  echo -e "${BLUE}[3/4] Telegram Benachrichtigung senden...${NC}"
  curl -s -X POST "$DEPLOY_N8N_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"version\": \"${VERSION}\", \"url\": \"${DOWNLOAD_URL}\", \"filename\": \"${APK_NAME}\"}" \
    > /dev/null && echo "Telegram notified" || echo "Telegram notification failed (non-critical)"
else
  echo -e "${BLUE}[3/4] Telegram uebersprungen (DEPLOY_N8N_WEBHOOK nicht gesetzt)${NC}"
fi

# 4. Aufraeumen
echo -e "${BLUE}[4/4] Aufraeumen...${NC}"
rm -f "./${APK_NAME}"

echo -e "${GREEN}=== Fertig! ===${NC}"
echo -e "Download: ${DOWNLOAD_URL}"
