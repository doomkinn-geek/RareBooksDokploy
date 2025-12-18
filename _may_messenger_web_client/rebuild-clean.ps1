# Clean rebuild script for May Messenger Web Client
# This script performs a complete rebuild without Docker cache

Write-Host "🧹 Cleaning Docker build cache..." -ForegroundColor Cyan
docker-compose build --no-cache maymessenger_web_client

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To start the service:" -ForegroundColor Yellow
    Write-Host "  docker-compose up -d maymessenger_web_client" -ForegroundColor White
    Write-Host ""
    Write-Host "To view logs:" -ForegroundColor Yellow
    Write-Host "  docker-compose logs -f maymessenger_web_client" -ForegroundColor White
} else {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    Write-Host "Check the error messages above." -ForegroundColor Yellow
}

