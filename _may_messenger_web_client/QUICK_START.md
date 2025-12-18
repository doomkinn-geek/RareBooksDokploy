# Quick Start - May Messenger Web Client

## Локальная разработка

```bash
cd _may_messenger_web_client

# Установка зависимостей
npm install

# Запуск dev сервера (с HMR)
npm run dev

# Доступно на http://localhost:3000
```

## Production Build

```bash
# Сборка для production
npm run build

# Preview production build
npm run preview

# Результат в папке dist/
```

## Docker

### Быстрый запуск

```bash
# Пересобрать и запустить
docker-compose build maymessenger_web_client
docker-compose up -d maymessenger_web_client

# Проверить логи
docker-compose logs -f maymessenger_web_client

# Проверить healthcheck
curl http://localhost/healthz
```

### Полный перезапуск

```bash
# Остановить
docker-compose down

# Пересобрать (с учётом изменений)
docker-compose build --no-cache maymessenger_web_client

# Запустить
docker-compose up -d

# Проверить статус
docker-compose ps
```

## Проверка после запуска

```bash
# 1. Healthcheck
curl http://localhost/healthz
# Ожидается: "healthy"

# 2. Проверить что SPA загружается
curl -I http://localhost/web/
# Ожидается: 200 OK

# 3. Проверить статические файлы
curl -I http://localhost/web/assets/index-*.js
# Ожидается: 200 OK + Cache-Control: public, immutable

# 4. Открыть в браузере
# http://localhost/web/
```

## Troubleshooting

### Build fails

```bash
# Очистить node_modules и пересобрать
rm -rf node_modules package-lock.json
npm install
npm run build
```

### Docker image слишком большой

```bash
# Проверить размер
docker images | grep maymessenger_web_client

# Должно быть ~50MB

# Если больше - проверьте .dockerignore
cat .dockerignore
```

### Service Worker не работает

1. Откройте DevTools → Application → Service Workers
2. Проверьте что SW зарегистрирован
3. Нажмите "Unregister" и обновите страницу
4. Hard reload (Ctrl+Shift+R)

### Nginx ошибки

```bash
# Проверить логи
docker logs maymessenger_web_client

# Проверить конфигурацию
docker exec maymessenger_web_client nginx -t

# Перезапустить nginx
docker restart maymessenger_web_client
```

## Environment Variables

Переменные задаются в docker-compose.yml:

```yaml
environment:
  - VITE_API_URL=https://messenger.rare-books.ru
```

Для локальной разработки создайте `.env.local`:

```bash
VITE_API_URL=http://localhost:5000
```

## Performance Monitoring

### Bundle Size

```bash
# Analyze bundle
npm run build

# Смотреть размеры в консоли
```

### Lighthouse

```bash
# Установить Lighthouse CLI
npm install -g lighthouse

# Запустить audit
lighthouse http://localhost/web/ --view
```

## Cache Strategy

- **HTML**: No cache (всегда свежий)
- **JS/CSS**: 1 год (immutable с hash)
- **Service Worker**: 1 час
- **Manifest**: 7 дней
- **Icons**: 1 год

## Development Tips

1. **Hot Module Replacement**: Работает автоматически в dev mode
2. **TypeScript**: Проверка типов при сборке
3. **Linting**: `npm run lint`
4. **DevTools**: React DevTools + Redux DevTools (если есть)

## Deployment Checklist

- [ ] Обновлен код в репозитории
- [ ] Пройдены линтеры: `npm run lint`
- [ ] Успешная сборка: `npm run build`
- [ ] Проверен размер bundle (< 1.5MB)
- [ ] Обновлена версия Service Worker
- [ ] Тестирование в production mode: `npm run preview`
- [ ] Docker образ собран: `docker-compose build`
- [ ] Healthcheck проходит
- [ ] Проверено в браузере

## Next Steps

После запуска:
1. Откройте https://messenger.rare-books.ru/web/
2. Зарегистрируйтесь или войдите
3. Проверьте FCM notifications
4. Проверьте offline mode (отключите сеть)

## Documentation

- `OPTIMIZATION_GUIDE.md` - Детали оптимизаций
- `README.md` - Общая информация
- `README_SETUP.md` - Setup инструкции

