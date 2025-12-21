# Quick Deploy - Nginx Update для поддержки изображений

## Что было изменено

Добавлена поддержка проксирования изображений в Nginx конфигурации `nginx/nginx_prod.conf`.

## Шаги для применения на production

### 1. Проверить изменения локально

```bash
# Убедиться что файл изменен
git diff nginx/nginx_prod.conf
```

### 2. Закоммитить и запушить

```bash
git add nginx/nginx_prod.conf
git commit -m "Add /images/ location to nginx config for messenger media support"
git push origin main
```

### 3. На сервере: Pull изменений

```bash
cd /path/to/rarebooks  # Путь к проекту на сервере
git pull origin main
```

### 4. Проверить Nginx конфигурацию

```bash
# Проверить синтаксис конфигурации (ВАЖНО!)
docker exec nginx_container nginx -t

# Ожидаемый вывод:
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### 5. Применить изменения (без даунтайма)

```bash
# Перезагрузить Nginx (graceful reload)
docker exec nginx_container nginx -s reload

# Проверить статус
docker ps | grep nginx
```

### 6. Проверить работу

```bash
# Тест 1: Отправить изображение через мобильное приложение

# Тест 2: Проверить доступ к файлу (заменить {guid} на реальный)
curl -I https://messenger.rare-books.ru/images/{guid}.jpg

# Ожидаемый ответ:
# HTTP/2 200
# content-type: image/jpeg
# cache-control: public, immutable
# expires: ...
```

## Что дальше?

Все остальное уже настроено:
- ✅ Backend пути корректны
- ✅ Docker volumes монтируются правильно
- ✅ MediaCleanupService работает для audio и images
- ✅ Локальное хранилище на клиентах реализовано

## Rollback (если что-то пошло не так)

```bash
# Откатить изменения в Nginx
git revert HEAD
docker cp nginx/nginx_prod.conf nginx_container:/etc/nginx/nginx.conf
docker exec nginx_container nginx -s reload
```

---

**Общее время деплоя: ~2 минуты**  
**Даунтайм: 0 секунд** (graceful reload)

