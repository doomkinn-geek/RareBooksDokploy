# 🚀 Универсальная конфигурация Setup API

## ✨ Что изменилось

Теперь **Setup API постоянно доступен через HTTP** без необходимости переключения конфигураций или перезапуска контейнеров!

## 🎯 Ключевые улучшения:

### ✅ nginx_prod.conf (универсальная конфигурация):
- **HTTP Setup API** доступен на `http://localhost/api/setup` (без редиректа)
- **HTTP Test API** доступен на `http://localhost/api/test` (для диагностики)
- **Все остальное** редиректится на HTTPS для безопасности
- **HTTPS** полностью поддерживается (если SSL настроен)

### ✅ docker-compose.yml:
- Обновленный **healthcheck** проверяет Setup API
- Улучшенные таймауты и параметры запуска
- **SSL сертификаты** подключаются автоматически (если доступны)

### ✅ Диагностические скрипты:
- Поддержка **нового формата** `docker compose` и старого `docker-compose`
- Автоматическое определение доступного формата
- Обновленные команды во всех скриптах

## 🚀 Быстрое применение (3 шага):

### 1. Загрузите обновленные файлы на сервер:
```
nginx/nginx_prod.conf           # Универсальная конфигурация
docker-compose.yml              # Обновленный compose файл
apply-universal-config.sh       # Скрипт применения
setup-diagnostics.sh            # Обновленная диагностика
```

### 2. Примените конфигурацию:
```bash
chmod +x apply-universal-config.sh
./apply-universal-config.sh
```

### 3. Проверьте результат:
```bash
# Setup API должен быть доступен через HTTP
curl http://localhost/api/setup

# POST запросы должны работать
curl -X POST http://localhost/api/setup/initialize \
     -H "Content-Type: application/json" \
     -d '{"test":"data"}'
```

## 📊 Ожидаемый результат:

### ✅ Успешное применение:
- nginx контейнер показывает статус **healthy**
- `http://localhost/api/setup` открывается без ошибок
- POST запросы возвращают **JSON** (не HTML 405)
- Диагностика показывает все зеленые галочки

### 🌐 Доступные endpoints:

| Endpoint | HTTP | HTTPS | Описание |
|----------|------|-------|----------|
| `/api/setup/*` | ✅ Доступен | ✅ Доступен | Setup API (инициализация) |
| `/api/test/*` | ✅ Доступен | ✅ Доступен | Test API (диагностика) |
| `/api/setupcheck/*` | ✅ Доступен | ✅ Доступен | Setup Check API |
| `/api/*` (остальные) | ↗️ Редирект | ✅ Доступен | Production API |
| `/*` (фронтенд) | ↗️ Редирект | ✅ Доступен | Web интерфейс |

## 🔧 Диагностика и устранение проблем:

### Если что-то не работает:
```bash
# Полная диагностика
./setup-diagnostics.sh --verbose

# Перезапуск с диагностикой
./setup-diagnostics.sh --restart-services

# Проверка логов
sudo docker compose logs nginx
sudo docker compose logs backend
```

### Проверка корректности применения:
```bash
# 1. Статус контейнеров
sudo docker compose ps

# 2. Healthcheck nginx
sudo docker inspect nginx_container --format='{{.State.Health.Status}}'

# 3. Тест Setup API
curl http://localhost/api/test/setup-status

# 4. Тест POST запросов
curl -X POST http://localhost/api/setup/initialize \
     -H "Content-Type: application/json" -d '{"test":"data"}'
```

## 💡 Преимущества новой конфигурации:

1. **🎯 Стабильность** - не нужно переключать конфигурации
2. **🚀 Быстрота** - Setup API всегда доступен
3. **🔒 Безопасность** - Production трафик идет через HTTPS
4. **🛠️ Удобство** - инициализация доступна в любое время
5. **📊 Диагностика** - встроенные health checks

## 🔄 Откат (если нужен):

```bash
# Восстановление из бэкапа
cp docker-compose.yml.backup_* docker-compose.yml
sudo docker compose restart nginx
```

## 📞 Поддержка:

Если возникают проблемы:
```bash
# Сгенерировать отчет для поддержки
./setup-diagnostics.sh --verbose > diagnostic_report.log 2>&1
./apply-universal-config.sh > apply_report.log 2>&1
```

## 🎉 Готово!

После успешного применения:
- Откройте `http://localhost/api/setup` для инициализации
- Или `https://rare-books.ru/api/setup` (если HTTPS настроен)
- Setup API работает **постоянно** без дополнительных настроек!
