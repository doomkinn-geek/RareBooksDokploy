# 🚀 Быстрое исправление для Ubuntu сервера

## 🎯 Проблема решена!
Добавлены критически важные директивы в `nginx/nginx_prod.conf`:
- `proxy_method $request_method;` - разрешает POST запросы
- `client_max_body_size 10M;` - увеличивает лимит размера запроса

## ⚡ Инструкции для Ubuntu сервера

### 1. Загрузите обновленные файлы на сервер:
- `nginx/nginx_prod.conf` (исправлен)
- `setup-diagnostics.sh` (новый)
- `UBUNTU_SETUP_FIX.md` (инструкция)

### 2. Примените исправления:
```bash
# Сделайте скрипт исполняемым
chmod +x setup-diagnostics.sh

# Запустите автоматическое исправление
./setup-diagnostics.sh --restart-services --verbose

# Или вручную:
sudo nginx -s reload
sudo docker-compose restart nginx
```

### 3. Проверьте результат:
```bash
# Должен вернуть JSON, а не HTML 405 ошибку
curl -X POST https://rare-books.ru/api/setup/initialize \
     -H "Content-Type: application/json" \
     -d '{"test":"data"}'
```

## ✅ Критические изменения в nginx_prod.conf:

### До (не работало):
```nginx
location /api/setup/ {
    proxy_pass http://backend;
    # proxy_method отсутствовал - блокировал POST!
}
```

### После (работает):
```nginx
location /api/setup/ {
    proxy_pass http://backend;
    proxy_method $request_method;    # ← ДОБАВЛЕНО
    client_max_body_size 10M;        # ← ДОБАВЛЕНО
}
```

## 🔍 Если нужна диагностика:
```bash
./setup-diagnostics.sh --verbose
```

## 📞 Поддержка:
Если проблема persist, отправьте результат диагностики:
```bash
./setup-diagnostics.sh --verbose > diagnostics.log 2>&1
```
