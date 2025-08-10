# 1) Этап сборки React-приложения
FROM node:18-alpine AS build
WORKDIR /app

# Копируем package.json, package-lock.json
COPY package*.json ./
# Устанавливаем все зависимости явно, включая yet-another-react-lightbox
RUN npm install
# Для гарантии установки критической зависимости
RUN npm install yet-another-react-lightbox@3.16.0 --save

# Копируем исходники
COPY . .
# Создание сборки (в Vite передается VITE_API_URL и т.д.)
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
