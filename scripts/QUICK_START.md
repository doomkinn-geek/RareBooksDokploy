# Быстрая настройка SSL для messenger.rare-books.ru

## ⚡ Быстрый старт (5 минут)

### 1. Проверьте DNS
```bash
nslookup messenger.rare-books.ru
# Должен вернуться IP вашего сервера
```

### 2. Убедитесь, что nginx запущен
```bash
docker ps | grep nginx
```

### 3. Получите сертификат
```bash
# Создайте папку для challenge-файлов (если нужно)
sudo mkdir -p /var/www/certbot

# Получите сертификат
sudo certbot certonly --webroot -w /var/www/certbot -d messenger.rare-books.ru
```

### 4. Перезапустите nginx
```bash
# Перейдите в папку проекта
cd /home/docker/RareBooksDokploy  # или ваш путь

# Перезапустите прокси
docker-compose restart proxy
```

### 5. Проверьте работу
```bash
# Проверка через curl
curl -I https://messenger.rare-books.ru/health

# Откройте в браузере
# https://messenger.rare-books.ru/swagger
```

---

## 🔄 Настройка автообновления сертификатов

### Шаг 1: Скопируйте скрипт
```bash
cd /home/docker/RareBooksDokploy  # или ваш путь

# Отредактируйте путь в скрипте
nano scripts/renew_all_certificates.sh
# Измените путь на свой реальный путь к docker-compose.yml

# Скопируйте скрипт
sudo cp scripts/renew_all_certificates.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/renew_all_certificates.sh
```

### Шаг 2: Добавьте в cron
```bash
sudo crontab -e

# Добавьте эту строку:
0 3 * * * /usr/local/bin/renew_all_certificates.sh >> /var/log/renew_cert.log 2>&1
```

### Шаг 3: Проверьте
```bash
# Тестовый запуск
sudo /usr/local/bin/renew_all_certificates.sh

# Проверьте лог
cat /var/log/renew_cert.log
```

---

## ✅ Готово!

Теперь:
- ✅ SSL сертификат для messenger.rare-books.ru установлен
- ✅ Nginx настроен и использует правильный сертификат
- ✅ Автообновление сертификатов настроено
- ✅ https://messenger.rare-books.ru/api работает без ошибок

---

## 🔧 Если что-то не работает

### Проблема: Ошибка при получении сертификата
```bash
# Проверьте DNS
dig messenger.rare-books.ru

# Проверьте nginx логи
docker logs nginx_container

# Проверьте доступность порта 80
curl -I http://messenger.rare-books.ru
```

### Проблема: Браузер показывает ошибку сертификата
```bash
# Проверьте, какой сертификат используется
openssl s_client -connect messenger.rare-books.ru:443 -servername messenger.rare-books.ru </dev/null 2>/dev/null | openssl x509 -noout -subject

# Должно быть: subject=CN = messenger.rare-books.ru

# Если показывает rare-books.ru, то:
docker-compose restart proxy
```

### Проблема: 502 Bad Gateway
```bash
# Проверьте backend
docker ps | grep maymessenger
docker logs maymessenger_backend

# Перезапустите сервисы
docker-compose restart
```

---

## 📚 Подробная документация

Смотрите полную инструкцию: `scripts/CERTIFICATE_SETUP_INSTRUCTIONS.md`

---

## 📝 Важные файлы

- `nginx/nginx_prod.conf` - конфигурация nginx (уже обновлена)
- `scripts/get_messenger_certificate.sh` - скрипт получения сертификата
- `scripts/renew_all_certificates.sh` - скрипт автообновления
- `/var/log/renew_cert.log` - лог автообновления

---

**Сертификаты Let's Encrypt действуют 90 дней и автоматически обновляются каждые 60 дней!** 🔒

