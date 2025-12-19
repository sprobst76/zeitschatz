#!/usr/bin/env bash
set -euo pipefail

# Simple dev script:
# 1) Start backend (uvicorn) in background
# 2) Run backend smoke test script
# 3) Build Flutter Linux app (debug build)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="${ROOT_DIR}/.venv"
BACKEND_PORT=${BACKEND_PORT:-8000}
BASE_URL="http://localhost:${BACKEND_PORT}"

if [ ! -d "${VENV}" ]; then
  echo "Venv not found at ${VENV}. Please create and install backend deps first."
  exit 1
fi

source "${VENV}/bin/activate"

echo "Starting backend on port ${BACKEND_PORT}..."
uvicorn app.main:app --app-dir "${ROOT_DIR}/backend/app" --port "${BACKEND_PORT}" --reload --host 0.0.0.0 >"${ROOT_DIR}/backend_uvicorn.log" 2>&1 &
UV_PID=$!
trap "kill ${UV_PID} 2>/dev/null || true" EXIT

sleep 3
echo "Running backend smoke test..."
BASE_URL=${BASE_URL} "${ROOT_DIR}/backend/scripts/smoke_test.sh"

echo "Building Flutter Linux app..."
pushd "${ROOT_DIR}/frontend" >/dev/null
flutter config --enable-linux-desktop >/dev/null
flutter build linux
popd >/dev/null

echo "Done. Backend log: ${ROOT_DIR}/backend_uvicorn.log"
