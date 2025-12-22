# ZeitSchatz Frontend - Flutter Web
# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Copy pubspec first for caching
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source and build
COPY . .

# Build argument for API URL
ARG API_BASE_URL=https://zeitschatz-api.DOMAIN.de

# Build web app with API URL
RUN flutter build web --release --pwa-strategy none --dart-define=API_BASE_URL=$API_BASE_URL

# Stage 2: Serve with nginx
FROM nginx:alpine

# Copy built web app
COPY --from=builder /app/build/web /usr/share/nginx/html

# Custom nginx config with security headers
RUN echo 'server { \
    listen 80; \
    server_name _; \
    root /usr/share/nginx/html; \
    index index.html; \
    \
    # Security Headers \
    add_header X-Frame-Options "SAMEORIGIN" always; \
    add_header X-Content-Type-Options "nosniff" always; \
    add_header X-XSS-Protection "1; mode=block" always; \
    add_header Referrer-Policy "strict-origin-when-cross-origin" always; \
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always; \
    \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
    \
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ { \
        expires 1y; \
        add_header Cache-Control "public, immutable"; \
    } \
    \
    # Block sensitive files \
    location ~ /\. { \
        deny all; \
    } \
}' > /etc/nginx/conf.d/default.conf

# Security: Run as non-root (nginx user exists in alpine)
RUN chown -R nginx:nginx /usr/share/nginx/html

EXPOSE 80
