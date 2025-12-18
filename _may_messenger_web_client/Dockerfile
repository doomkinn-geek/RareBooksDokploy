# Build stage
FROM node:20-alpine AS build

WORKDIR /app

# Copy package files first for better Docker layer caching
COPY package*.json ./

# Install dependencies
# Using npm install instead of npm ci because lock file may not be in sync
RUN npm install --legacy-peer-deps

# Copy source code
COPY . .

# Build the app with production optimizations
ENV NODE_ENV=production
RUN npm run build

# Production stage
FROM nginx:stable-alpine

# Install curl for healthcheck
RUN apk add --no-cache curl

# Copy custom nginx config first
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built assets from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Create directory for nginx pid and temp files
RUN mkdir -p /var/cache/nginx/client_temp \
    && chown -R nginx:nginx /var/cache/nginx \
    && chown -R nginx:nginx /usr/share/nginx/html

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Expose port 80
EXPOSE 80

# Run nginx as non-root user for security
USER nginx

CMD ["nginx", "-g", "daemon off;"]
