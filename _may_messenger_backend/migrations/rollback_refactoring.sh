#!/bin/bash

# Rollback script for May Messenger refactoring migrations
# Use this if something goes wrong after applying migrations

set -e

echo "========================================="
echo "May Messenger Migration Rollback"
echo "========================================="
echo ""

if [ -z "$1" ]; then
    echo "Usage: ./rollback_refactoring.sh <backup_file.sql>"
    echo ""
    echo "Available backups:"
    ls -lh maymessenger_backup_*.sql 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"
DB_CONTAINER="db_maymessenger"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "✗ Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "WARNING: This will restore the database to the state in $BACKUP_FILE"
echo "All data changes since the backup will be LOST"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Rollback cancelled"
    exit 0
fi

echo ""
echo "[1/3] Stopping backend service..."
docker stop maymessenger_backend
echo "✓ Backend stopped"

echo ""
echo "[2/3] Restoring database from backup..."
docker exec -i $DB_CONTAINER psql -U postgres -d MayMessengerDb < "$BACKUP_FILE"
if [ $? -eq 0 ]; then
    echo "✓ Database restored"
else
    echo "✗ Database restore failed"
    exit 1
fi

echo ""
echo "[3/3] Starting backend service..."
docker start maymessenger_backend
echo "✓ Backend started"

echo ""
echo "========================================="
echo "Rollback completed successfully!"
echo "========================================="
echo ""
echo "The database has been restored to the backup state"
echo "Monitor logs: docker logs -f maymessenger_backend"
echo ""

