#!/bin/bash

# Script for manual migration creation
# Usage: ./create-migration.sh <MigrationName>

MIGRATION_NAME=$1

if [ -z "$MIGRATION_NAME" ]; then
    echo "Usage: ./create-migration.sh <MigrationName>"
    echo "Example: ./create-migration.sh AddUserOnlineStatus"
    exit 1
fi

echo "Creating migration: $MIGRATION_NAME"

cd src/MayMessenger.Infrastructure || exit 1
dotnet ef migrations add "$MIGRATION_NAME" --startup-project ../MayMessenger.API

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Migration created successfully!"
    echo "Migration name: $MIGRATION_NAME"
    echo ""
    echo "To apply this migration:"
    echo "  1. In development: dotnet run --project src/MayMessenger.API"
    echo "  2. In production: Migrations will be applied automatically on startup"
else
    echo ""
    echo "❌ Failed to create migration"
    exit 1
fi

