# ZeitSchatz Security Guide

## Overview

This document covers security best practices for deploying ZeitSchatz.

## Production Checklist

### 1. Secrets Management

```bash
# Generate a strong SECRET_KEY (min 32 bytes)
openssl rand -hex 32

# Never commit secrets to git
# Use .env files that are gitignored
```

**Required secrets:**
- `SECRET_KEY` - JWT signing key (MUST be random, min 64 chars)
- Database credentials (if using Postgres)

### 2. Network Security

#### Firewall Rules (ufw example)
```bash
# Allow only necessary ports
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp   # HTTP (redirects to HTTPS via Traefik)
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable
```

#### Docker Network Isolation
- All services use internal Docker network (`ai-lab`)
- Only Traefik is exposed to the internet
- Backend and frontend communicate via internal network only

### 3. HTTPS/TLS

Traefik handles TLS termination with Let's Encrypt:
- Automatic certificate renewal
- Strong cipher suites (Traefik defaults)
- HSTS headers added by nginx

### 4. Rate Limiting

The API implements rate limiting to prevent brute force attacks:

| Endpoint | Limit | Purpose |
|----------|-------|---------|
| `/auth/login` | 5/minute | Prevent PIN brute force |
| Other endpoints | No limit | Authenticated requests |

### 5. Authentication Security

#### PIN Policy
- Minimum 4 digits
- Stored as bcrypt hash (not plaintext)
- No PIN reuse enforcement (family app context)

#### JWT Tokens
- Access token: 60 minutes expiry
- Refresh token: 7 days expiry
- Tokens include user ID and role claims

#### Recommendations for Parents
- Use unique PINs (not 0000, 1234, etc.)
- Change PINs periodically
- Don't share PINs with children

### 6. Container Security

Both containers run as non-root users:
- Backend: `zeitschatz` user
- Frontend: `nginx` user

Additional hardening:
```yaml
# docker-compose.prod.yml additions (optional)
services:
  zeitschatz-api:
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
```

### 7. Data Protection

#### Photo Storage
- Photos stored locally in Docker volume
- Auto-deleted after 14 days (configurable)
- Not accessible without authentication

#### Database
- SQLite stored in Docker volume
- Regular backups recommended:
```bash
# Backup database
docker-compose -f docker-compose.prod.yml exec zeitschatz-api \
  cp /data/zeit.db /data/zeit.db.backup
```

### 8. Security Headers

The nginx frontend adds these headers:
- `X-Frame-Options: SAMEORIGIN` - Clickjacking protection
- `X-Content-Type-Options: nosniff` - MIME sniffing protection
- `X-XSS-Protection: 1; mode=block` - XSS protection
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy` - Restricts browser features

### 9. Logging & Monitoring

View logs for suspicious activity:
```bash
# API logs
docker-compose -f docker-compose.prod.yml logs -f zeitschatz-api

# Look for:
# - Multiple failed login attempts
# - Rate limit hits (429 responses)
# - Unusual request patterns
```

### 10. Updates

Keep dependencies updated:
```bash
# Rebuild with latest base images
docker-compose -f docker-compose.prod.yml build --no-cache
docker-compose -f docker-compose.prod.yml up -d
```

## Threat Model

### In Scope
- Unauthorized access to family data
- PIN brute forcing
- Session hijacking
- XSS/CSRF attacks

### Out of Scope (Family App Context)
- Nation-state attackers
- Physical device compromise
- Social engineering within family

## Incident Response

If you suspect a breach:
1. Rotate `SECRET_KEY` immediately (invalidates all sessions)
2. Check logs for unauthorized access
3. Reset all user PINs
4. Review photo submissions for inappropriate content
