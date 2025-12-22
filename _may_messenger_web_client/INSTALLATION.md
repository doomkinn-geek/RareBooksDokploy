# Инструкция по установке и запуску веб-клиента

## Предварительные требования

- Node.js 18+ и npm
- Доступ к backend API
- (Опционально) Firebase для push-уведомлений

---

## Установка зависимостей

```bash
cd _may_messenger_web_client
npm install
```

---

## Конфигурация

### 1. API URL
Отредактируйте `src/utils/constants.ts`:

```typescript
export const API_BASE_URL = 'https://your-api-domain.com';
export const HUB_URL = 'https://your-api-domain.com/hubs/chat';
```

### 2. Firebase (для push-уведомлений)
Если используете Firebase, создайте файл конфигурации в `src/firebase/config.ts`.

---

## Запуск в режиме разработки

```bash
npm run dev
```

Приложение будет доступно по адресу `http://localhost:5173/web`

---

## Сборка для продакшена

```bash
npm run build
```

Собранные файлы будут в директории `dist/`.

---

## Развертывание

### Вариант 1: Nginx
Скопируйте содержимое `dist/` в директорию веб-сервера:

```bash
cp -r dist/* /var/www/html/web/
```

Пример конфигурации Nginx:

```nginx
location /web {
    alias /var/www/html/web;
    try_files $uri $uri/ /web/index.html;
}
```

### Вариант 2: Docker
Используйте существующий Dockerfile:

```bash
docker build -t may-messenger-web .
docker run -p 80:80 may-messenger-web
```

---

## Проверка работоспособности

1. Откройте `http://your-domain.com/web`
2. Зарегистрируйте новый аккаунт или войдите
3. Проверьте основные функции:
   - Список чатов загружается
   - Можно отправить сообщение
   - Поиск работает
   - Создание чатов работает

---

## Troubleshooting

### Проблема: "Failed to fetch"
**Решение:** Проверьте, что API_BASE_URL настроен правильно и backend доступен.

### Проблема: SignalR не подключается
**Решение:** Убедитесь, что HUB_URL правильный и websockets включены на сервере.

### Проблема: Push-уведомления не работают
**Решение:** Проверьте конфигурацию Firebase и наличие Service Worker.

---

## Дополнительные команды

```bash
# Запуск линтера
npm run lint

# Форматирование кода
npm run format

# Сборка с оптимизацией
npm run build

# Предпросмотр production-сборки
npm run preview
```

---

## Структура проекта

```
_may_messenger_web_client/
├── src/
│   ├── api/              # API клиенты
│   ├── components/       # React компоненты
│   ├── hooks/           # Custom hooks
│   ├── pages/           # Страницы приложения
│   ├── services/        # Бизнес-логика
│   ├── stores/          # State management (Zustand)
│   ├── types/           # TypeScript типы
│   └── utils/           # Утилиты
├── public/              # Статические файлы
└── dist/                # Собранное приложение
```

---

## Поддержка

При возникновении проблем:
1. Проверьте логи браузера (Console)
2. Проверьте логи сервера
3. Убедитесь, что все зависимости установлены
4. Проверьте версии Node.js и npm

