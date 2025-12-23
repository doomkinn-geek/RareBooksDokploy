# Custom nginx image with entrypoint that waits for upstream services
FROM nginx:stable-alpine

# Install netcat for TCP health checks
RUN apk add --no-cache netcat-openbsd

# Copy custom entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Use our custom entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]

