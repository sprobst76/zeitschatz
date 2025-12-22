# ZeitSchatz Backend - FastAPI
FROM python:3.11-slim

WORKDIR /app

# Install dependencies first (for caching)
COPY pyproject.toml ./
RUN pip install --no-cache-dir . alembic

# Copy application
COPY . .

# Create data directory with correct permissions
RUN mkdir -p /data/photos

# Security: Create non-root user and set ownership
RUN groupadd -r zeitschatz && useradd -r -g zeitschatz zeitschatz \
    && chown -R zeitschatz:zeitschatz /app /data

# Security: Switch to non-root user
USER zeitschatz

# Expose port
EXPOSE 8070

# Run migrations then start server
CMD ["sh", "-c", "cd /app && alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8070"]
