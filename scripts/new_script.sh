#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <path-to-script>"
  exit 1
fi

TARGET="$1"

if [[ -e "${TARGET}" ]]; then
  echo "File already exists: ${TARGET}"
  exit 1
fi

mkdir -p "$(dirname "${TARGET}")"

cat > "${TARGET}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

EOF

chmod +x "${TARGET}"
echo "Created executable script at ${TARGET}"
