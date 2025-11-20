# 1) Этап сборки React-приложения
FROM node:18-alpine AS build
WORKDIR /app

# Копируем package.json, package-lock.json (для кеширования слоя dependencies)
COPY package*.json ./

# Используем npm ci для более быстрой и надежной установки в production
# --prefer-offline использует кеш, если доступен
RUN npm ci --prefer-offline --no-audit

# Копируем исходники
COPY . .

# Создание оптимизированной сборки
RUN npm run build

# 2) Этап "runtime": nginx + собранное приложение
FROM nginx:stable-alpine

# Копируем собранные файлы после сборки
COPY --from=build /app/dist /usr/share/nginx/html

# Копируем кастомный конфиг nginx, для редиректа fallback на index.html
COPY ./nginx.conf /etc/nginx/conf.d/default.conf

# Устанавливаем curl для корректной работы healthcheck
RUN apk add --no-cache curl

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
