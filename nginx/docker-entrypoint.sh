#!/bin/sh
# Custom entrypoint for nginx that waits for upstream services before starting

set -e

echo "=== Nginx Entrypoint: Waiting for upstream services ==="

# Function to wait for a service to be ready
wait_for_service() {
    local host=$1
    local port=$2
    local service_name=$3
    local max_attempts=${4:-60}
    local attempt=1
    
    echo "Waiting for $service_name ($host:$port)..."
    
    while [ $attempt -le $max_attempts ]; do
        # Try to connect using wget (available in alpine)
        if wget -q --spider --timeout=2 "http://$host:$port/" 2>/dev/null || \
           wget -q --spider --timeout=2 "http://$host:$port/health" 2>/dev/null || \
           wget -q --spider --timeout=2 "http://$host:$port/healthz" 2>/dev/null; then
            echo "✓ $service_name is ready!"
            return 0
        fi
        
        # Alternative: try simple TCP connection using /dev/tcp or nc
        if command -v nc >/dev/null 2>&1; then
            if nc -z -w 2 "$host" "$port" 2>/dev/null; then
                echo "✓ $service_name is ready (TCP)!"
                return 0
            fi
        fi
        
        echo "  Attempt $attempt/$max_attempts - $service_name not ready yet..."
        sleep 1
        attempt=$((attempt + 1))
    done
    
    echo "⚠ WARNING: $service_name may not be fully ready after $max_attempts attempts, continuing anyway..."
    return 0  # Don't fail, let nginx try anyway
}

# Wait for all backend services
echo ""
echo "=== Checking RareBooks Backend ==="
wait_for_service "rarebooks_backend" "80" "RareBooks Backend" 60

echo ""
echo "=== Checking RareBooks Frontend ==="
wait_for_service "rarebooks_frontend" "80" "RareBooks Frontend" 60

echo ""
echo "=== Checking MayMessenger Backend ==="
wait_for_service "maymessenger_backend" "5000" "MayMessenger Backend" 60

echo ""
echo "=== Checking MayMessenger Web Client ==="
wait_for_service "maymessenger_web_client" "80" "MayMessenger Web Client" 60

echo ""
echo "=== All services checked, starting nginx... ==="

# Give services a moment to fully initialize after TCP connection is ready
sleep 2

# Execute nginx
exec nginx -g 'daemon off;'

