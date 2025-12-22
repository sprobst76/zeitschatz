#!/bin/bash
# ZeitSchatz Deployment Script
# Run this on the VPS after copying the project

set -e

echo "=== ZeitSchatz Deployment ==="

# Check if .env.prod exists
if [ ! -f .env.prod ]; then
    echo "ERROR: .env.prod not found. Copy from .env.prod.sample and configure."
    exit 1
fi

# Load environment
export $(grep -v '^#' .env.prod | xargs)

# Create ai-lab network if it doesn't exist
docker network create ai-lab 2>/dev/null || true

# Build and deploy
echo "Building containers..."
docker compose -f docker-compose.prod.yml --env-file .env.prod build

echo "Starting services..."
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d

echo ""
echo "=== Deployment Complete ==="
echo "API: https://zeitschatz-api.${DOMAIN}"
echo "Web: https://zeitschatz.${DOMAIN}"
echo ""
echo "Check logs with: docker compose -f docker-compose.prod.yml logs -f"
