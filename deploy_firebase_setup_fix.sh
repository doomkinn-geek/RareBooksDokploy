#!/bin/bash
# Скрипт для деплоя исправления Firebase Setup Page

set -e

echo "🔄 Deploying Firebase Setup Page fix..."

cd /root/rarebooks

echo "📥 Pulling latest changes..."
git pull origin master

echo "🔨 Building maymessenger_backend..."
docker compose build maymessenger_backend

echo "🚀 Restarting services..."
docker compose up -d maymessenger_backend

echo "⏳ Waiting for backend to be healthy..."
sleep 10

echo "✅ Checking if setup page is accessible..."
curl -I https://messenger.rare-books.ru/messenger/setup/ || echo "⚠️  Check failed, but service might still be starting"

echo "📦 Checking files in container..."
docker exec maymessenger_backend ls -la /app/FirebaseSetup/ || echo "⚠️  FirebaseSetup folder not found"

echo ""
echo "✅ Deployment complete!"
echo "🌐 Open: https://messenger.rare-books.ru/messenger/setup/"
echo ""
echo "📋 Useful commands:"
echo "  - Check logs: docker compose logs -f maymessenger_backend"
echo "  - Check status: docker compose ps maymessenger_backend"
