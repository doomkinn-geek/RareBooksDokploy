# PowerShell script for manual migration creation
# Usage: .\create-migration.ps1 <MigrationName>

param(
    [Parameter(Mandatory=$true)]
    [string]$MigrationName
)

Write-Host "Creating migration: $MigrationName" -ForegroundColor Cyan

Push-Location src\MayMessenger.Infrastructure

try {
    dotnet ef migrations add $MigrationName --startup-project ..\MayMessenger.API
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Migration created successfully!" -ForegroundColor Green
        Write-Host "Migration name: $MigrationName" -ForegroundColor Green
        Write-Host ""
        Write-Host "To apply this migration:" -ForegroundColor Yellow
        Write-Host "  1. In development: dotnet run --project src\MayMessenger.API" -ForegroundColor Yellow
        Write-Host "  2. In production: Migrations will be applied automatically on startup" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "❌ Failed to create migration" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}

