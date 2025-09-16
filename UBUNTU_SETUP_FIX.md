# Исправление проблемы Initial Setup на Ubuntu сервере

## 🚨 Проблема
Ошибка 405 Not Allowed при попытке инициализировать систему через POST запрос к `/api/setup/initialize`.

## ✅ Быстрое решение

### 1. Загрузите исправленные файлы на сервер
```bash
# Скопируйте обновленные файлы:
# - nginx/nginx_prod.conf
# - setup-diagnostics.sh
```

### 2. Сделайте диагностический скрипт исполняемым
```bash
chmod +x setup-diagnostics.sh
```

### 3. Запустите диагностику
```bash
# Полная диагностика
./setup-diagnostics.sh --verbose

# Диагностика с автоматическим исправлением
./setup-diagnostics.sh --restart-services --force-setup-mode
```

### 4. Обновите nginx конфигурацию
```bash
# Проверьте конфигурацию
sudo nginx -t

# Перезагрузите nginx
sudo nginx -s reload

# Или перезапустите через docker-compose
sudo docker-compose restart nginx
```

### 5. Проверьте результат
```bash
# Проверьте test endpoint
curl https://rare-books.ru/api/test/setup-status

# Проверьте setup endpoint
curl -X POST https://rare-books.ru/api/setup/initialize \
     -H "Content-Type: application/json" \
     -d '{"test":"data"}'
```

## 🔧 Что было исправлено в nginx_prod.conf

### ✅ Критические изменения:
1. **Добавлен `proxy_method $request_method;`** - разрешает все HTTP методы включая POST
2. **Добавлен `client_max_body_size 10M;`** - увеличивает лимит размера запроса
3. **Исправлена конфигурация для всех API секций**

### 📍 Ключевые секции:
```nginx
# Setup API
location /api/setup/ {
    proxy_method $request_method;  # ← КРИТИЧЕСКИ ВАЖНО
    client_max_body_size 10M;
    # ... остальные настройки
}

# Test API  
location ~ ^/api/(test|setupcheck)/ {
    proxy_method $request_method;  # ← ДОБАВЛЕНО
    # ... остальные настройки
}

# Общие API
location /api/ {
    proxy_method $request_method;  # ← ДОБАВЛЕНО
    # ... остальные настройки
}
```

## 🔍 Диагностические команды

### Проверка nginx:
```bash
# Статус nginx
sudo systemctl status nginx

# Проверка конфигурации
sudo nginx -t

# Просмотр логов nginx
sudo tail -f /var/log/nginx/error.log
```

### Проверка Docker:
```bash
# Статус контейнеров
sudo docker-compose ps

# Логи сервисов
sudo docker-compose logs nginx
sudo docker-compose logs backend

# Перезапуск сервисов
sudo docker-compose restart nginx backend
```

### Проверка endpoints:
```bash
# Test API
curl -v https://rare-books.ru/api/test/setup-status

# Setup API (GET)
curl -v https://rare-books.ru/api/setup

# Setup API (POST) - должен возвращать JSON, а не HTML
curl -v -X POST https://rare-books.ru/api/setup/initialize \
     -H "Content-Type: application/json" \
     -d '{"adminEmail":"test@example.com"}'
```

## 🎯 Признаки успешного исправления

✅ **Успех:**
- `curl https://rare-books.ru/api/test/setup-status` возвращает JSON с кодом 200
- `curl -X POST https://rare-books.ru/api/setup/initialize` возвращает JSON (не HTML)
- Страница инициализации `https://rare-books.ru/api/setup` загружается
- Кнопка "Тест соединения" работает
- Кнопка "Инициализировать систему" отправляет запрос без ошибки 405

❌ **Проблема не решена:**
- POST запросы возвращают HTML со статусом 405
- В ответе видно `<h1>405 Not Allowed</h1>`
- nginx логи показывают ошибки 405

## 🔄 Если проблема persists

1. **Убедитесь, что используется правильный файл конфигурации:**
   ```bash
   sudo docker-compose exec nginx nginx -T | grep "setup"
   ```

2. **Принудительно пересоберите контейнеры:**
   ```bash
   sudo docker-compose down
   sudo docker-compose up -d --force-recreate nginx
   ```

3. **Проверьте, что конфигурация применилась:**
   ```bash
   ./setup-diagnostics.sh --verbose
   ```

## 📞 Поддержка
Если проблема не решается, запустите полную диагностику и отправьте результат:
```bash
./setup-diagnostics.sh --verbose > diagnostics.log 2>&1
```
