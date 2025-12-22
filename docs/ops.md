# Ops Notes

## VPS Deployment (Docker + Traefik)

### Prerequisites
- VPS with Docker and Docker Compose installed
- Traefik reverse proxy running with Let's Encrypt
- External network `ai-lab` created

### Deploy

```bash
# 1. Clone repository
git clone <repo-url> zeitschatz
cd zeitschatz

# 2. Configure environment
cp .env.prod.sample .env.prod
nano .env.prod
# Set: DOMAIN, SECRET_KEY (use: openssl rand -hex 32)

# 3. Build and start
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d --build

# 4. Initialize database with seed users (first run only)
docker-compose -f docker-compose.prod.yml exec zeitschatz-api \
  python scripts/seed_users.py
```

### Services
- **Frontend**: `https://zeitschatz.DOMAIN`
- **API**: `https://zeitschatz-api.DOMAIN`

### Logs
```bash
docker-compose -f docker-compose.prod.yml logs -f zeitschatz-api
docker-compose -f docker-compose.prod.yml logs -f zeitschatz-web
```

### Update
```bash
git pull
docker-compose -f docker-compose.prod.yml up -d --build
```

---

## Local Development

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
