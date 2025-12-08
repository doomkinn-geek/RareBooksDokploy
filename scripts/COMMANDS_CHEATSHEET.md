# 🚀 Шпаргалка команд для SSL сертификатов

## 📝 Быстрые команды

### Получение сертификата для messenger.rare-books.ru

```bash
# Вариант 1: Использовать скрипт (рекомендуется)
chmod +x scripts/get_messenger_certificate.sh
sudo scripts/get_messenger_certificate.sh

# Вариант 2: Вручную
sudo certbot certonly --webroot -w /var/www/certbot -d messenger.rare-books.ru
```

### Проверка системы перед получением сертификата

```bash
chmod +x scripts/pre_certificate_check.sh
sudo scripts/pre_certificate_check.sh
```

### Проверка статуса всех сертификатов

```bash
chmod +x scripts/check_certificates.sh
sudo scripts/check_certificates.sh
```

---

## 🔐 Управление сертификатами

### Просмотр всех сертификатов
```bash
sudo certbot certificates
```

### Обновление сертификатов (dry-run)
```bash
sudo certbot renew --dry-run
```

### Обновление сертификатов (реальное)
```bash
sudo certbot renew
```

### Удаление сертификата
```bash
sudo certbot delete --cert-name messenger.rare-books.ru
```

### Просмотр информации о сертификате
```bash
# На диске
sudo openssl x509 -text -noout -in /etc/letsencrypt/live/messenger.rare-books.ru/fullchain.pem

# Срок действия
sudo openssl x509 -enddate -noout -in /etc/letsencrypt/live/messenger.rare-books.ru/fullchain.pem

# Subject (для кого выдан)
sudo openssl x509 -subject -noout -in /etc/letsencrypt/live/messenger.rare-books.ru/fullchain.pem
```

---

## 🐳 Docker команды

### Управление контейнерами
```bash
# Просмотр запущенных контейнеров
docker ps

# Просмотр всех контейнеров
docker ps -a

# Перезапуск nginx
docker-compose restart proxy

# Перезапуск messenger backend
docker-compose restart maymessenger_backend

# Перезапуск всех сервисов
docker-compose restart

# Остановка всех сервисов
docker-compose down

# Запуск всех сервисов
docker-compose up -d
```

### Просмотр логов
```bash
# Логи nginx
docker logs nginx_container

# Логи nginx (последние 100 строк, live)
docker logs nginx_container --tail 100 -f

# Логи messenger backend
docker logs maymessenger_backend --tail 100 -f

# Логи всех контейнеров
docker-compose logs -f
```

### Проверка конфигурации nginx
```bash
# Проверка синтаксиса
docker exec nginx_container nginx -t

# Просмотр конфигурации
docker exec nginx_container cat /etc/nginx/nginx.conf

# Просмотр части для messenger
docker exec nginx_container cat /etc/nginx/nginx.conf | grep -A20 "messenger.rare-books.ru"

# Перезагрузка конфигурации без перезапуска
docker exec nginx_container nginx -s reload
```

### Проверка монтирования томов
```bash
# Проверка всех монтирований для nginx
docker inspect nginx_container | grep -A5 "Mounts"

# Проверка доступности сертификата в контейнере
docker exec nginx_container ls -la /etc/letsencrypt/live/

# Проверка папки challenge
docker exec nginx_container ls -la /var/www/certbot/
```

---

## 🌐 Проверка доступности

### DNS проверка
```bash
# nslookup
nslookup messenger.rare-books.ru

# dig
dig messenger.rare-books.ru

# Внешний IP сервера
curl ifconfig.me
```

### HTTP/HTTPS проверка
```bash
# HTTP
curl -I http://messenger.rare-books.ru

# HTTPS
curl -I https://messenger.rare-books.ru/health

# Подробная информация об HTTPS соединении
curl -v https://messenger.rare-books.ru/health 2>&1 | grep -E "(SSL|certificate|CN=)"

# Swagger
curl -I https://messenger.rare-books.ru/swagger
```

### Проверка сертификата через OpenSSL
```bash
# Полная информация о сертификате
openssl s_client -connect messenger.rare-books.ru:443 -servername messenger.rare-books.ru </dev/null 2>/dev/null | openssl x509 -noout -text

# Subject (для кого выдан)
openssl s_client -connect messenger.rare-books.ru:443 -servername messenger.rare-books.ru </dev/null 2>/dev/null | openssl x509 -noout -subject

# Срок действия
openssl s_client -connect messenger.rare-books.ru:443 -servername messenger.rare-books.ru </dev/null 2>/dev/null | openssl x509 -noout -dates

# Subject Alternative Names (SANs)
openssl s_client -connect messenger.rare-books.ru:443 -servername messenger.rare-books.ru </dev/null 2>/dev/null | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
```

### Проверка портов
```bash
# Локально
sudo netstat -tulpn | grep -E ':(80|443)'

# Или с помощью ss
sudo ss -tulpn | grep -E ':(80|443)'

# Извне (если telnet установлен)
telnet messenger.rare-books.ru 80
telnet messenger.rare-books.ru 443
```

---

## 🔧 Автообновление сертификатов

### Настройка cron
```bash
# Редактирование crontab
sudo crontab -e

# Добавить строку:
0 3 * * * /usr/local/bin/renew_all_certificates.sh >> /var/log/renew_cert.log 2>&1

# Просмотр текущих задач cron
sudo crontab -l

# Удаление задачи (откроется редактор)
sudo crontab -e
```

### Проверка автообновления
```bash
# Установка скрипта
sudo cp scripts/renew_all_certificates.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/renew_all_certificates.sh

# Тестовый запуск
sudo /usr/local/bin/renew_all_certificates.sh

# Просмотр лога
cat /var/log/renew_cert.log

# Последние 20 строк лога
tail -20 /var/log/renew_cert.log

# Live просмотр лога
tail -f /var/log/renew_cert.log
```

---

## 🔍 Диагностика проблем

### Проблема: DNS не работает
```bash
# Проверка DNS
nslookup messenger.rare-books.ru
dig messenger.rare-books.ru

# Проверка через разные DNS серверы
nslookup messenger.rare-books.ru 8.8.8.8
nslookup messenger.rare-books.ru 1.1.1.1

# Очистка DNS кэша (если на локальной машине)
# Windows: ipconfig /flushdns
# Linux: sudo systemd-resolve --flush-caches
# macOS: sudo dscacheutil -flushcache
```

### Проблема: Сертификат не применяется
```bash
# Проверка конфигурации nginx
docker exec nginx_container nginx -t

# Проверка путей к сертификату
docker exec nginx_container cat /etc/nginx/nginx.conf | grep -A3 "messenger.rare-books.ru" | grep ssl_certificate

# Проверка наличия сертификата в контейнере
docker exec nginx_container ls -la /etc/letsencrypt/live/messenger.rare-books.ru/

# Перезапуск nginx
docker-compose restart proxy

# Просмотр логов nginx при перезапуске
docker logs nginx_container --tail 50
```

### Проблема: 502 Bad Gateway
```bash
# Проверка backend
docker ps | grep maymessenger

# Логи backend
docker logs maymessenger_backend --tail 100

# Проверка health endpoint напрямую (изнутри сервера)
docker exec nginx_container curl http://maymessenger_backend:5000/health

# Проверка сети Docker
docker network inspect rarebooks_network

# Перезапуск backend
docker-compose restart maymessenger_backend
```

### Проблема: Challenge не проходит
```bash
# Создание тестового файла
echo "test" | sudo tee /var/www/certbot/test.txt

# Проверка через HTTP
curl http://messenger.rare-books.ru/.well-known/acme-challenge/test.txt

# Проверка в контейнере
docker exec nginx_container ls -la /var/www/certbot/

# Проверка конфигурации location
docker exec nginx_container cat /etc/nginx/nginx.conf | grep -A5 "acme-challenge"

# Удаление тестового файла
sudo rm /var/www/certbot/test.txt
```

### Проблема: Ошибка в логах certbot
```bash
# Логи certbot
sudo less /var/log/letsencrypt/letsencrypt.log

# Последние ошибки
sudo tail -50 /var/log/letsencrypt/letsencrypt.log

# Verbose режим certbot
sudo certbot certonly --webroot -w /var/www/certbot -d messenger.rare-books.ru --verbose
```

---

## 📊 Мониторинг

### Проверка здоровья сервисов
```bash
# Health checks
curl https://rare-books.ru/api/test/setup-status
curl https://messenger.rare-books.ru/health

# Статус Docker контейнеров
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Использование ресурсов
docker stats --no-stream
```

### Проверка дискового пространства
```bash
# Общее использование
df -h

# Использование Docker
docker system df

# Размер логов
sudo du -sh /var/log/letsencrypt/
sudo du -sh /var/log/renew_cert.log
```

---

## 🗂️ Полезные пути

```bash
# Сертификаты
/etc/letsencrypt/live/messenger.rare-books.ru/fullchain.pem
/etc/letsencrypt/live/messenger.rare-books.ru/privkey.pem

# Challenge файлы
/var/www/certbot/

# Логи certbot
/var/log/letsencrypt/

# Лог автообновления
/var/log/renew_cert.log

# Скрипт автообновления
/usr/local/bin/renew_all_certificates.sh

# Проект
/home/docker/RareBooksDokploy/
# или
/home/youruser/RareBooksDokploy/

# Конфигурация nginx
./nginx/nginx_prod.conf

# Docker Compose
./docker-compose.yml
```

---

## 📱 Быстрые тесты

### После получения сертификата
```bash
# 1. Проверка сертификата
openssl s_client -connect messenger.rare-books.ru:443 -servername messenger.rare-books.ru </dev/null 2>/dev/null | openssl x509 -noout -subject

# 2. Проверка health endpoint
curl https://messenger.rare-books.ru/health

# 3. Проверка Swagger
curl -I https://messenger.rare-books.ru/swagger

# 4. Проверка в браузере
# Откройте: https://messenger.rare-books.ru/swagger
```

### Перед получением сертификата
```bash
# 1. DNS
nslookup messenger.rare-books.ru

# 2. HTTP доступность
curl -I http://messenger.rare-books.ru

# 3. Nginx запущен
docker ps | grep nginx

# 4. Challenge доступен
echo "test" | sudo tee /var/www/certbot/test.txt
curl http://messenger.rare-books.ru/.well-known/acme-challenge/test.txt
sudo rm /var/www/certbot/test.txt
```

---

## 💾 Резервное копирование

### Создание бэкапа сертификатов
```bash
# Создание архива
sudo tar -czf letsencrypt-backup-$(date +%Y%m%d).tar.gz /etc/letsencrypt/

# Копирование в безопасное место
sudo cp letsencrypt-backup-*.tar.gz /home/youruser/backups/
```

### Восстановление из бэкапа
```bash
# Распаковка
sudo tar -xzf letsencrypt-backup-YYYYMMDD.tar.gz -C /

# Перезапуск nginx
docker-compose restart proxy
```

---

## 🎓 Полезные ссылки

- **Документация Let's Encrypt:** https://letsencrypt.org/docs/
- **Документация Certbot:** https://certbot.eff.org/docs/
- **SSL Labs Test:** https://www.ssllabs.com/ssltest/
- **Nginx документация:** https://nginx.org/ru/docs/

---

**Совет:** Добавьте эту шпаргалку в закладки для быстрого доступа к командам! 🚀

