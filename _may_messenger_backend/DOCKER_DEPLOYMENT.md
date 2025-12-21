# Docker Deployment Guide - Депеша Messenger

## Overview

This guide provides instructions for deploying the Депеша messenger backend using Docker with proper volume configuration for media files (audio and images).

## Docker Compose Configuration

### Basic docker-compose.yml

```yaml
version: '3.8'

services:
  messenger-api:
    image: may-messenger-api:latest
    container_name: may_messenger_api
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "5000:5000"
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:5000
      - ConnectionStrings__DefaultConnection=Host=postgres;Port=5432;Database=maymessenger;Username=postgres;Password=${DB_PASSWORD}
    volumes:
      # CRITICAL: Mount volumes to persist media files
      - ./wwwroot/audio:/app/wwwroot/audio
      - ./wwwroot/images:/app/wwwroot/images
      # Optional: Persist logs
      - ./logs:/app/logs
    depends_on:
      - postgres
    restart: unless-stopped
    networks:
      - messenger-network

  postgres:
    image: postgres:15-alpine
    container_name: may_messenger_db
    environment:
      - POSTGRES_DB=maymessenger
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped
    networks:
      - messenger-network

volumes:
  postgres-data:
    driver: local

networks:
  messenger-network:
    driver: bridge
```

### Environment Variables

Create a `.env` file in the same directory as `docker-compose.yml`:

```env
DB_PASSWORD=your_secure_password_here
```

## Pre-deployment Setup

### 1. Create Required Directories

On the host machine, create directories for media files:

```bash
# Navigate to project root
cd /path/to/_may_messenger_backend

# Create directories with proper permissions
mkdir -p wwwroot/audio wwwroot/images logs
chmod -R 755 wwwroot
chmod -R 755 logs

# Verify structure
tree -L 2 wwwroot
# Expected output:
# wwwroot/
# ├── audio/
# └── images/
```

### 2. Build Docker Image

```bash
# From project root
docker build -t may-messenger-api:latest .
```

### 3. Start Services

```bash
# Start all services
docker-compose up -d

# Check logs
docker-compose logs -f messenger-api

# Verify migrations applied
docker-compose logs messenger-api | grep "Database migrations"
```

## Nginx Configuration (Reverse Proxy)

If using Nginx as a reverse proxy, add these location blocks:

```nginx
server {
    listen 443 ssl http2;
    server_name messenger.rare-books.ru;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/messenger.rare-books.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/messenger.rare-books.ru/privkey.pem;

    # Main API
    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # SignalR requires larger timeouts
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # Static audio files
    location /audio/ {
        alias /path/to/_may_messenger_backend/wwwroot/audio/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        add_header Access-Control-Allow-Origin "*";
        
        # Security: prevent directory listing
        autoindex off;
    }

    # Static image files
    location /images/ {
        alias /path/to/_may_messenger_backend/wwwroot/images/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        add_header Access-Control-Allow-Origin "*";
        
        # Security: prevent directory listing
        autoindex off;
    }

    # Maximum upload size for images (10MB)
    client_max_body_size 10M;
}
```

**Important:** Replace `/path/to/_may_messenger_backend/` with actual absolute path.

## Verification Checklist

After deployment, verify:

### 1. API Health

```bash
curl https://messenger.rare-books.ru/health/ready
# Expected: {"status":"Ready"}
```

### 2. Database Migrations

Check container logs for successful migration:

```bash
docker-compose logs messenger-api | grep -A 5 "Database migrations"
# Should show: "Database is up to date" or "Database migrations applied successfully"
```

### 3. Volume Mounts

Verify volumes are correctly mounted:

```bash
# List volumes
docker volume ls | grep messenger

# Inspect messenger-api container
docker inspect may_messenger_api | grep -A 10 "Mounts"

# Should show mounts for /app/wwwroot/audio and /app/wwwroot/images
```

### 4. Media Upload Test

Send a test audio message via API:

```bash
curl -X POST https://messenger.rare-books.ru/api/messages/audio \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "chatId=YOUR_CHAT_ID" \
  -F "audioFile=@test.m4a"

# Verify file exists on host
ls -lh wwwroot/audio/
```

Send a test image message:

```bash
curl -X POST https://messenger.rare-books.ru/api/messages/image \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "chatId=YOUR_CHAT_ID" \
  -F "imageFile=@test.jpg"

# Verify file exists on host
ls -lh wwwroot/images/
```

### 5. File Access Test

```bash
# Test direct access to uploaded files
curl -I https://messenger.rare-books.ru/audio/{guid}.m4a
# Expected: 200 OK

curl -I https://messenger.rare-books.ru/images/{guid}.jpg
# Expected: 200 OK
```

## Common Issues and Solutions

### Issue 1: Permission Denied on Volume Mounts

**Symptom:** API cannot write to `/app/wwwroot/audio` or `/app/wwwroot/images`

**Solution:**
```bash
# Fix permissions on host
sudo chown -R 1000:1000 wwwroot
chmod -R 755 wwwroot
```

### Issue 2: Files Not Persisting After Container Restart

**Symptom:** Uploaded files disappear when container restarts

**Solution:** Verify volume mounts in `docker-compose.yml`:
```yaml
volumes:
  - ./wwwroot/audio:/app/wwwroot/audio  # Must use relative or absolute host path
  - ./wwwroot/images:/app/wwwroot/images
```

### Issue 3: 404 on Static Files

**Symptom:** Images/audio return 404 even though file exists

**Solutions:**
1. Verify Nginx configuration (alias path must end with `/`)
2. Check file permissions: `ls -la wwwroot/audio/`
3. Verify `app.UseStaticFiles()` is enabled in `Program.cs`

### Issue 4: Large Image Upload Fails

**Symptom:** Upload fails with 413 Request Entity Too Large

**Solution:** Increase Nginx client_max_body_size:
```nginx
client_max_body_size 10M;  # Match API validation (10MB)
```

## Backup Strategy

### Automated Backup Script

Create `backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/backups/may_messenger"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup media files
tar -czf "$BACKUP_DIR/media_$DATE.tar.gz" \
    wwwroot/audio \
    wwwroot/images

# Backup database
docker exec may_messenger_db pg_dump -U postgres maymessenger | \
    gzip > "$BACKUP_DIR/database_$DATE.sql.gz"

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "media_*.tar.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "database_*.sql.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
```

Make executable and add to crontab:

```bash
chmod +x backup.sh
crontab -e
# Add: 0 2 * * * /path/to/backup.sh
```

## Monitoring

### Disk Usage Monitoring

```bash
# Monitor media directory size
du -sh wwwroot/audio wwwroot/images

# Set up alert when > 10GB
watch -n 300 'du -sm wwwroot | awk '\''$1 > 10240 { print "WARNING: Media storage > 10GB" }'\'''
```

### Container Resource Monitoring

```bash
# Real-time resource usage
docker stats may_messenger_api

# Add resource limits to docker-compose.yml
services:
  messenger-api:
    # ... other config ...
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          memory: 512M
```

## Updating the Application

### Zero-downtime Update Process

```bash
# 1. Build new image
docker build -t may-messenger-api:latest .

# 2. Pull new image (if using registry)
docker-compose pull messenger-api

# 3. Restart with new image
docker-compose up -d --no-deps --build messenger-api

# 4. Verify
docker-compose logs -f messenger-api
```

## Security Recommendations

1. **Media Files:**
   - Never allow directory listing (`autoindex off`)
   - Set proper CORS headers
   - Implement file size limits
   - Validate file types on upload

2. **Volumes:**
   - Use bind mounts for media (easier backups)
   - Use named volumes for database (better performance)
   - Never mount host root directory

3. **Network:**
   - Use Docker networks to isolate services
   - Only expose necessary ports to host
   - Use SSL/TLS for all external connections

---

**Last Updated:** December 21, 2025  
**Project:** Депеша (May Messenger)  
**Version:** 1.0.0

