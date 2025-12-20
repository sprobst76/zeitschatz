#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8070}"

if [[ -d "${VENV_DIR}" ]]; then
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
else
  echo "Missing venv at ${VENV_DIR}. Create it first."
  exit 1
fi

exec uvicorn app.main:app --app-dir "${ROOT_DIR}/backend/app" --host "${HOST}" --port "${PORT}"
