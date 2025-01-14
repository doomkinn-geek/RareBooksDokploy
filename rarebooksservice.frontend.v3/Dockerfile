# 1) Этап сборки React-приложения
FROM node:18-alpine AS build
WORKDIR /app

# Копируем package.json, package-lock.json
COPY package*.json ./
RUN npm install

# Копируем исходники
COPY . .
# Собираем проект (в Vite учитываем VITE_API_URL и т.д.)
RUN npm run build

# 2) Этап "runtime": nginx + статика
FROM nginx:stable-alpine

# Копируем статические файлы после сборки
COPY --from=build /app/dist /usr/share/nginx/html

# Копируем кастомный конфиг nginx, где прописан fallback на index.html
COPY ./nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
