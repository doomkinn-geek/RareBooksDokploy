# 🎯 Решение проблемы nginx на Ubuntu сервере

## 📊 Анализ результатов диагностики:

Из вашей диагностики видно:
- ❌ **nginx_container - unhealthy** (основная проблема)
- ❌ **API запросы возвращают HTML фронтенда** вместо JSON
- ❌ **301 редирект с HTTP на HTTPS** блокирует тестирование
- ❌ **405 Not Allowed для POST** запросов

## 🔍 Причина проблемы:
`nginx_prod.conf` настроен **только для HTTPS** с SSL сертификатами, но:
1. SSL сертификаты могут быть недоступны/неправильно настроены
2. nginx не может запуститься корректно из-за проблем с SSL
3. Все HTTP запросы редиректятся на HTTPS (статус 301)

## ✅ Быстрое решение:

### Вариант 1: Переключение на HTTP для setup (рекомендуется)

```bash
# 1. Загрузите все новые файлы на сервер:
# - nginx/nginx_prod_http.conf
# - quick-fix-http.sh  
# - restore-https.sh
# - debug-nginx.sh

# 2. Сделайте скрипты исполняемыми
chmod +x quick-fix-http.sh restore-https.sh debug-nginx.sh

# 3. Переключитесь на HTTP версию для setup
./quick-fix-http.sh

# 4. После успешной инициализации вернитесь к HTTPS
./restore-https.sh
```

### Вариант 2: Исправление SSL проблем

```bash
# 1. Проверьте SSL сертификаты
sudo ls -la /etc/letsencrypt/live/rare-books.ru/

# 2. Если сертификаты отсутствуют, обновите их
sudo certbot renew

# 3. Перезапустите nginx
sudo docker-compose restart nginx
```

## 🔧 Подробные инструкции:

### Шаг 1: Диагностика проблем nginx
```bash
./debug-nginx.sh
```

### Шаг 2: Быстрое исправление с HTTP
```bash
./quick-fix-http.sh
```

**Ожидаемый результат:**
- ✅ HTTP Test API возвращает код 200
- ✅ HTTP Setup API POST возвращает JSON (не HTML)
- ✅ Открывается http://localhost/api/setup

### Шаг 3: Выполните инициализацию
```bash
# Откройте в браузере или curl:
curl http://localhost/api/setup

# Выполните POST запрос для инициализации:
curl -X POST http://localhost/api/setup/initialize \
     -H "Content-Type: application/json" \
     -d '{
       "adminEmail": "admin@example.com",
       "adminPassword": "your_password",
       "booksConnectionString": "...",
       "usersConnectionString": "...",
       "jwtKey": "...",
       "jwtIssuer": "...",
       "jwtAudience": "..."
     }'
```

### Шаг 4: Верните HTTPS конфигурацию
```bash
./restore-https.sh
```

## 🔍 Проверка успешности:

### HTTP версия работает, если:
```bash
curl http://localhost/api/test/setup-status
# Возвращает: {"success":true,"message":"Test endpoint working",...}

curl -X POST http://localhost/api/setup/initialize -H "Content-Type: application/json" -d '{"test":"data"}'
# Возвращает: JSON (не HTML с 405 ошибкой)
```

### HTTPS версия работает, если:
```bash
curl -k https://rare-books.ru/api/test/setup-status  
# Возвращает: {"success":true,...}

curl -k -X POST https://rare-books.ru/api/setup/initialize -H "Content-Type: application/json" -d '{"test":"data"}'
# Возвращает: JSON (не HTML)
```

## 🚨 Если проблема persists:

### 1. Проверьте логи:
```bash
sudo docker-compose logs nginx
sudo docker-compose logs backend
```

### 2. Проверьте docker network:
```bash
sudo docker network ls
sudo docker-compose exec nginx ping backend
```

### 3. Проверьте конфигурацию nginx:
```bash
sudo docker-compose exec nginx nginx -t
sudo docker-compose exec nginx cat /etc/nginx/nginx.conf | head -20
```

### 4. Форсированное пересоздание:
```bash
sudo docker-compose down
sudo docker-compose up -d --force-recreate
```

## 📁 Файлы для загрузки:

1. **nginx/nginx_prod_http.conf** - конфигурация с поддержкой HTTP
2. **quick-fix-http.sh** - переключение на HTTP
3. **restore-https.sh** - возврат к HTTPS
4. **debug-nginx.sh** - глубокая диагностика

## 🎯 Ожидаемый результат:

После выполнения всех шагов:
- ✅ nginx контейнер показывает статус "healthy"  
- ✅ Setup API доступен по HTTP и/или HTTPS
- ✅ POST запросы к /api/setup/initialize возвращают JSON
- ✅ Система успешно инициализируется

## 📞 Если нужна помощь:

Отправьте результаты выполнения:
```bash
./debug-nginx.sh > debug.log 2>&1
./quick-fix-http.sh > fix.log 2>&1
```
