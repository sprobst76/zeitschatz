# Ops Notes

## Start/Stop
- Backend: `./scripts/start_backend.sh` (env: `HOST`, `PORT`)
- Frontend (web): `./scripts/start_frontend_web.sh`

## Known Environment Fixes
- Flutter cache must be writable:
  - `sudo chown -R $USER:$USER /home/spro/flutter`

## Database Migrations
- `source .venv/bin/activate`
- `alembic -c backend/alembic.ini upgrade head`

## API Quick Checks
- Login:
  - `curl -X POST http://192.168.0.144:8070/auth/login -H "Content-Type: application/json" -d "{\"user_id\":1,\"pin\":\"1234\"}"`
- Pending submissions (use access token only):
  - `curl -H "Authorization: Bearer <ACCESS_TOKEN>" http://192.168.0.144:8070/submissions/pending -i`

## Troubleshooting
- Port in use: `PORT=8071 ./scripts/start_backend.sh`
- CORS: `.env` must use JSON list, e.g. `CORS_ORIGINS=["http://192.168.0.144:8081"]`
