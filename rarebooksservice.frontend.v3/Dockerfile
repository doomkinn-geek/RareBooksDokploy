# Этап 1: Сборка React-приложения
FROM node:18-alpine AS build
WORKDIR /app

# Копируем package.json и package-lock.json и устанавливаем зависимости
COPY package*.json ./
RUN npm install

# Копируем весь код в рабочую директорию контейнера
COPY . .

# Сборка приложения
RUN npm run build

# Этап 2: Настройка Nginx для обслуживания статических файлов
FROM nginx:stable-alpine

# Копируем собранные файлы React-приложения из этапа сборки в Nginx
COPY --from=build /app/dist /usr/share/nginx/html
COPY ./nginx.conf /etc/nginx/conf.d/default.conf

# Открываем порт 80 для доступа к приложению
EXPOSE 3000

# Запускаем Nginx
CMD ["nginx", "-g", "daemon off;"]
