#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="${ROOT_DIR}/frontend"

if [[ ! -d "${FRONTEND_DIR}" ]]; then
  echo "Missing frontend directory at ${FRONTEND_DIR}."
  exit 1
fi

FLUTTER_BIN="$(command -v flutter || true)"
if [[ -z "${FLUTTER_BIN}" ]]; then
  echo "Flutter not found in PATH."
  exit 1
fi

FLUTTER_DIR="$(cd "$(dirname "${FLUTTER_BIN}")/.." && pwd)"
FLUTTER_CACHE_DIR="${FLUTTER_DIR}/bin/cache"
if [[ ! -w "${FLUTTER_CACHE_DIR}" ]]; then
  echo "Flutter cache is not writable: ${FLUTTER_CACHE_DIR}"
  echo "Fix with: sudo chown -R ${USER}:${USER} ${FLUTTER_DIR}"
  exit 1
fi
ENGINE_STAMP="${FLUTTER_CACHE_DIR}/engine.stamp"
if [[ -e "${ENGINE_STAMP}" && ! -w "${ENGINE_STAMP}" ]]; then
  echo "Flutter engine stamp is not writable: ${ENGINE_STAMP}"
  echo "Fix with: sudo chown -R ${USER}:${USER} ${FLUTTER_DIR}"
  exit 1
fi
WRITE_TEST="${FLUTTER_CACHE_DIR}/.write_test"
if ! (touch "${WRITE_TEST}" && rm -f "${WRITE_TEST}"); then
  echo "Cannot write to Flutter cache: ${FLUTTER_CACHE_DIR}"
  echo "Fix with: sudo chown -R ${USER}:${USER} ${FLUTTER_DIR}"
  exit 1
fi

cd "${FRONTEND_DIR}"
exec flutter run -d web-server --web-port=8081 --web-hostname=0.0.0.0
