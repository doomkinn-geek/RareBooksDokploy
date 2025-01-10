# 1) Этап сборки React-приложения
FROM node:18-alpine AS build
WORKDIR /app

# Копируем package.json, package-lock.json или yarn.lock
COPY package*.json ./
RUN npm install

# Копируем всё остальное (исходники)
COPY . .
# Собираем проект (если используете VITE_API_URL — оно учитывается при build)
RUN npm run build

# 2) Этап запуска: nginx + статика
FROM nginx:stable-alpine
# Копируем результаты билда в папку nginx
COPY --from=build /app/dist /usr/share/nginx/html
# Копируем кастомный nginx.conf (см. ниже) для проксирования /api
# COPY ./nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
