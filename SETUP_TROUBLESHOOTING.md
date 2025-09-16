# Устранение проблем с Initial Setup

## Проблема
При попытке инициализировать систему через `RareBooksService.WebApi/InitialSetup/index.html` возникает ошибка 405 Not Allowed от nginx.

## Решение

### 1. Запустите диагностику
```powershell
# Сначала проверьте состояние системы
./setup-diagnostics.ps1

# Если нужно перезапустить сервисы
./setup-diagnostics.ps1 -RestartServices

# Если система считает себя уже настроенной, но вы хотите переинициализировать
./setup-diagnostics.ps1 -ForceSetupMode
```

### 2. Исправленные компоненты

#### ✅ Nginx конфигурация (nginx/nginx_dev.conf)
- Добавлены специальные правила для `/api/setup/`, `/api/test/`, `/api/setupcheck/`
- Увеличены таймауты для процесса инициализации
- Явно разрешены все HTTP методы (включая POST)

#### ✅ Entity Framework LINQ запросы (TelegramBotService.cs)
- Исправлена ошибка с `tag.ToLower().Contains(keyword)` 
- Исправлена ошибка с `b.City.ToLower().Contains(city)`
- Использование `EF.Functions.Like` для корректного перевода в SQL

#### ✅ Test Controller (TestController.cs)
- Добавлена диагностическая информация в `/api/test/setup-status`
- Показывает статус setup'а системы

### 3. Пошаговое устранение

1. **Перезапуск сервисов:**
   ```bash
   docker-compose restart nginx backend
   ```

2. **Проверка логов:**
   ```bash
   docker-compose logs nginx
   docker-compose logs backend
   ```

3. **Ручная проверка endpoints:**
   ```bash
   # Проверка test API
   curl http://localhost/api/test/setup-status
   
   # Проверка setup API (GET)
   curl http://localhost/api/setup
   
   # Проверка setup API (POST)
   curl -X POST http://localhost/api/setup/initialize \
        -H "Content-Type: application/json" \
        -d '{"adminEmail":"test@test.com","adminPassword":"test123"}'
   ```

### 4. Возможные причины ошибки 405

1. **nginx блокирует POST запросы** - исправлено в конфигурации
2. **Middleware блокирует доступ** - middleware настроен правильно, пропускает setup запросы
3. **Система считает себя настроенной** - используйте `-ForceSetupMode` в диагностическом скрипте
4. **Проблемы с docker networking** - перезапустите контейнеры

### 5. Проверка успешности

После применения исправлений:

1. Откройте `http://localhost/api/setup` - должна загрузиться HTML страница
2. Нажмите "Тест соединения" - должно показать статус "OK"
3. Заполните форму и нажмите "Инициализировать систему"

### 6. Дополнительная помощь

Если проблема persists:
1. Запустите полную диагностику: `./setup-diagnostics.ps1`
2. Проверьте логи: `docker-compose logs`
3. Убедитесь, что используется правильная nginx конфигурация (dev vs prod)

## Команды для быстрого решения

```powershell
# Полная диагностика и перезапуск
./setup-diagnostics.ps1 -RestartServices

# Принудительное включение setup режима
./setup-diagnostics.ps1 -ForceSetupMode -RestartServices
```
