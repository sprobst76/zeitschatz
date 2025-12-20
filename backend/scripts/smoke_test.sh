#!/usr/bin/env bash
set -euo pipefail

# Simple smoke test against a running uvicorn server on 192.168.0.144:8070
# Requires: jq, curl, server running (uvicorn app.main:app --port 8000)

BASE_URL=${BASE_URL:-http://192.168.0.144:8070}

echo "Health..."
curl -s "$BASE_URL/health" | jq .

echo "Login parent..."
PARENT_TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"user_id":1,"pin":"1234"}' | jq -r '.access_token')

echo "Login child..."
CHILD_TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"user_id":2,"pin":"0000"}' | jq -r '.access_token')

echo "Create task..."
TASK=$(curl -s -X POST "$BASE_URL/tasks" \
  -H "Authorization: Bearer $PARENT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Smoke Task","duration_minutes":30,"target_device":"phone"}')
echo "$TASK" | jq .
TASK_ID=$(echo "$TASK" | jq -r '.id')

echo "Submit task as child..."
SUB=$(curl -s -X POST "$BASE_URL/submissions" \
  -H "Authorization: Bearer $CHILD_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"task_id\":$TASK_ID,\"comment\":\"done\"}")
echo "$SUB" | jq .
SUB_ID=$(echo "$SUB" | jq -r '.id')

echo "Approve submission..."
APPROVE=$(curl -s -X POST "$BASE_URL/submissions/$SUB_ID/approve" \
  -H "Authorization: Bearer $PARENT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"minutes":30,"target_device":"phone","tan_code":"SMOKETAN"}')
echo "$APPROVE" | jq .

echo "Ledger for child..."
curl -s "$BASE_URL/ledger/2" -H "Authorization: Bearer $PARENT_TOKEN" | jq .

echo "Smoke test finished."
