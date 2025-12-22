#!/bin/bash

# Script to apply all refactoring migrations for May Messenger
# Run this script on the production server to apply database changes

set -e  # Exit on error

echo "========================================="
echo "May Messenger Refactoring Migration"
echo "========================================="
echo ""

# Configuration
DB_CONTAINER="db_maymessenger"
BACKEND_DIR="/app/_may_messenger_backend"
MIGRATIONS_DIR="$BACKEND_DIR/migrations"

echo "[1/5] Checking database connection..."
docker exec $DB_CONTAINER psql -U postgres -d MayMessengerDb -c "SELECT version();" > /dev/null
if [ $? -eq 0 ]; then
    echo "✓ Database connection successful"
else
    echo "✗ Database connection failed"
    exit 1
fi

echo ""
echo "[2/5] Backing up database..."
BACKUP_FILE="maymessenger_backup_$(date +%Y%m%d_%H%M%S).sql"
docker exec $DB_CONTAINER pg_dump -U postgres MayMessengerDb > "$BACKUP_FILE"
if [ $? -eq 0 ]; then
    echo "✓ Backup created: $BACKUP_FILE"
else
    echo "✗ Backup failed"
    exit 1
fi

echo ""
echo "[3/5] Applying EF Core migrations..."
docker exec maymessenger_backend dotnet ef database update --project src/MayMessenger.Infrastructure/MayMessenger.Infrastructure.csproj --startup-project src/MayMessenger.API/MayMessenger.API.csproj --context AppDbContext
if [ $? -eq 0 ]; then
    echo "✓ EF Core migrations applied"
else
    echo "✗ EF Core migrations failed"
    echo "Rollback: Restore from backup using: docker exec -i $DB_CONTAINER psql -U postgres MayMessengerDb < $BACKUP_FILE"
    exit 1
fi

echo ""
echo "[4/5] Applying custom SQL migrations (indexes, triggers)..."
docker exec -i $DB_CONTAINER psql -U postgres -d MayMessengerDb < "$MIGRATIONS_DIR/add_fulltext_search_index.sql"
if [ $? -eq 0 ]; then
    echo "✓ Custom SQL migrations applied"
else
    echo "✗ Custom SQL migrations failed"
    echo "Rollback: Restore from backup using: docker exec -i $DB_CONTAINER psql -U postgres MayMessengerDb < $BACKUP_FILE"
    exit 1
fi

echo ""
echo "[5/5] Verifying migrations..."
# Check that new tables and indexes exist
docker exec $DB_CONTAINER psql -U postgres -d MayMessengerDb -c "\d \"MessageStatusEvents\"" > /dev/null
if [ $? -eq 0 ]; then
    echo "✓ MessageStatusEvents table exists"
else
    echo "✗ MessageStatusEvents table not found"
    exit 1
fi

docker exec $DB_CONTAINER psql -U postgres -d MayMessengerDb -c "\d \"IX_Messages_ClientMessageId\"" > /dev/null
if [ $? -eq 0 ]; then
    echo "✓ Unique index on ClientMessageId exists"
else
    echo "✗ Unique index on ClientMessageId not found"
    exit 1
fi

docker exec $DB_CONTAINER psql -U postgres -d MayMessengerDb -c "\d \"IX_Messages_Content_FullText\"" > /dev/null
if [ $? -eq 0 ]; then
    echo "✓ Full-text search index exists"
else
    echo "✗ Full-text search index not found"
    exit 1
fi

echo ""
echo "========================================="
echo "Migration completed successfully!"
echo "========================================="
echo ""
echo "Backup file: $BACKUP_FILE"
echo "Keep this backup for at least 7 days"
echo ""
echo "Next steps:"
echo "1. Restart backend service: docker restart maymessenger_backend"
echo "2. Monitor logs: docker logs -f maymessenger_backend"
echo "3. Test critical functionality (send message, status updates, search)"
echo "4. Deploy mobile app update"
echo ""

