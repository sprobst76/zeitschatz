#!/bin/bash
# ZeitSchatz APK Deploy Script
# Baut die APK, erstellt GitHub Release, sendet Telegram-Benachrichtigung

set -e

# Konfiguration
REPO="sprobst76/zeitschatz"
N8N_WEBHOOK="http://192.168.0.147:5678/webhook/apk-release"
API_URL="https://zeitschatz-api.halbewahrheit21.de"

# Farben für Output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== ZeitSchatz APK Deploy ===${NC}"

# Ins Projektverzeichnis wechseln
cd "$(dirname "$0")/.."

# Version generieren
VERSION="v$(date +%Y%m%d-%H%M)"
APK_NAME="ZeitSchatz-${VERSION}.apk"

# 1. Flutter Build
echo -e "${BLUE}[1/4] Flutter APK bauen...${NC}"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
cd frontend
flutter build apk --release --dart-define=API_BASE_URL="$API_URL"
cd ..

# APK kopieren und umbenennen
cp frontend/build/app/outputs/flutter-apk/app-release.apk "./${APK_NAME}"

# 2. GitHub Release erstellen
echo -e "${BLUE}[2/4] GitHub Release erstellen...${NC}"
RELEASE_URL=$(gh release create "$VERSION" "./${APK_NAME}" \
  --repo "$REPO" \
  --title "ZeitSchatz $VERSION" \
  --notes "Android APK Build $(date '+%Y-%m-%d %H:%M')")

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${APK_NAME}"

echo -e "${GREEN}Release erstellt: ${RELEASE_URL}${NC}"

# 3. Telegram Benachrichtigung via n8n
echo -e "${BLUE}[3/4] Telegram Benachrichtigung senden...${NC}"
curl -s -X POST "$N8N_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "{\"version\": \"${VERSION}\", \"url\": \"${DOWNLOAD_URL}\", \"filename\": \"${APK_NAME}\"}" \
  > /dev/null && echo "Telegram notified" || echo "Telegram notification failed (non-critical)"

# 4. Aufräumen
echo -e "${BLUE}[4/4] Aufräumen...${NC}"
rm -f "./${APK_NAME}"

echo -e "${GREEN}=== Fertig! ===${NC}"
echo -e "Download: ${DOWNLOAD_URL}"
