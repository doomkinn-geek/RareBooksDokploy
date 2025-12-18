# Apply Performance Indexes Migration
# This script adds critical indexes to improve query performance

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Green
Write-Host "Applying Performance Indexes Migration" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

# Database connection parameters
$DB_HOST = if ($env:DB_HOST) { $env:DB_HOST } else { "localhost" }
$DB_PORT = if ($env:DB_PORT) { $env:DB_PORT } else { "5432" }
$DB_NAME = if ($env:DB_NAME) { $env:DB_NAME } else { "maymessenger" }
$DB_USER = if ($env:DB_USER) { $env:DB_USER } else { "postgres" }
$DB_PASSWORD = $env:DB_PASSWORD

Write-Host "Database: $DB_NAME @ ${DB_HOST}:${DB_PORT}"
Write-Host "User: $DB_USER"
Write-Host ""

# Check if psql is available
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlPath) {
    Write-Host "ERROR: psql is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install PostgreSQL client tools" -ForegroundColor Yellow
    exit 1
}

# Set PGPASSWORD environment variable
$env:PGPASSWORD = $DB_PASSWORD

# Apply the migration
Write-Host "Applying indexes migration..." -ForegroundColor Cyan

try {
    & psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f add_performance_indexes.sql

    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "Migration applied successfully!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Performance indexes have been added to the database." -ForegroundColor Green
    Write-Host "Query performance should now be significantly improved." -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "ERROR: Migration failed!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

