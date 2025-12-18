#!/bin/bash

# Apply Performance Indexes Migration
# This script adds critical indexes to improve query performance

set -e  # Exit on error

echo "========================================="
echo "Applying Performance Indexes Migration"
echo "========================================="

# Database connection parameters
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-maymessenger}"
DB_USER="${DB_USER:-postgres}"

echo "Database: $DB_NAME @ $DB_HOST:$DB_PORT"
echo "User: $DB_USER"
echo ""

# Check if psql is available
if ! command -v psql &> /dev/null; then
    echo "ERROR: psql is not installed or not in PATH"
    exit 1
fi

# Apply the migration
echo "Applying indexes migration..."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f add_performance_indexes.sql

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "Migration applied successfully!"
    echo "========================================="
    echo ""
    echo "Performance indexes have been added to the database."
    echo "Query performance should now be significantly improved."
else
    echo ""
    echo "ERROR: Migration failed!"
    exit 1
fi

