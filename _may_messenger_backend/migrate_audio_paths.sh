#!/bin/bash
# Migration script to update audio paths in database

echo "🔄 Migrating audio file paths in database..."

# Get database connection info from docker-compose
DB_CONTAINER="postgres_maymessenger"
DB_NAME="maymessenger_db"
DB_USER="maymessenger_user"

# Execute the SQL migration
docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME << 'EOF'
-- Show affected messages
\echo '📊 Messages with old paths (/uploads/audio/):'
SELECT 
    "Id",
    "ChatId",
    "FilePath",
    "CreatedAt"
FROM "Messages"
WHERE "FilePath" LIKE '/uploads/audio/%';

-- Update the paths
\echo ''
\echo '🔧 Updating paths...'
UPDATE "Messages"
SET "FilePath" = REPLACE("FilePath", '/uploads/audio/', '/audio/')
WHERE "FilePath" LIKE '/uploads/audio/%';

-- Verify the update
\echo ''
\echo '✅ Updated messages with new paths (/audio/):'
SELECT 
    "Id",
    "ChatId",
    "FilePath",
    "CreatedAt"
FROM "Messages"
WHERE "FilePath" LIKE '/audio/%'
ORDER BY "CreatedAt" DESC
LIMIT 10;

\echo ''
\echo '✅ Migration completed!'
EOF

echo ""
echo "✅ Audio path migration completed!"
echo ""
echo "Next steps:"
echo "1. Reload nginx: docker compose restart proxy"
echo "2. Test audio playback in the app"
