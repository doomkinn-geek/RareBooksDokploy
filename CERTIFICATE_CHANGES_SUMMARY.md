# 🔐 Итоговая сводка изменений для SSL сертификата messenger.rare-books.ru

## 📝 Проблема

Домен `messenger.rare-books.ru` был настроен в nginx, но использовал сертификат от `rare-books.ru`, что вызывало ошибку сертификата в браузере (NET::ERR_CERT_COMMON_NAME_INVALID).

## ✅ Решение

Созданы скрипты и обновлена конфигурация для получения отдельного SSL сертификата для `messenger.rare-books.ru`.

---

## 📋 Выполненные изменения

### 1. Обновлен `nginx/nginx_prod.conf`

**Изменено:**
```nginx
# БЫЛО (неправильно):
ssl_certificate     /etc/letsencrypt/live/rare-books.ru/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/rare-books.ru/privkey.pem;

# СТАЛО (правильно):
ssl_certificate     /etc/letsencrypt/live/messenger.rare-books.ru/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/messenger.rare-books.ru/privkey.pem;
```

Теперь для `messenger.rare-books.ru` используется собственный сертификат.

### 2. Создан `scripts/get_messenger_certificate.sh`

Скрипт для получения SSL сертификата от Let's Encrypt для домена `messenger.rare-books.ru`.

**Использование:**
```bash
chmod +x scripts/get_messenger_certificate.sh
sudo scripts/get_messenger_certificate.sh
```

### 3. Создан `scripts/renew_all_certificates.sh`

Скрипт для автоматического обновления всех сертификатов (используется в cron).

**Установка:**
```bash
sudo cp scripts/renew_all_certificates.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/renew_all_certificates.sh
```

**⚠️ ВАЖНО:** Перед использованием отредактируйте путь к проекту в скрипте!

### 4. Создана документация

- `scripts/QUICK_START.md` - быстрая инструкция (5 минут)
- `scripts/CERTIFICATE_SETUP_INSTRUCTIONS.md` - подробная инструкция
- `scripts/README.md` - общая информация о скриптах

---

## 🚀 Что нужно сделать на сервере

### Шаг 1: Убедитесь, что DNS настроен

```bash
nslookup messenger.rare-books.ru
```

Должен вернуться IP адрес вашего сервера.

### Шаг 2: Получите сертификат

```bash
# Создайте папку для challenge-файлов
sudo mkdir -p /var/www/certbot

# Получите сертификат
sudo certbot certonly --webroot -w /var/www/certbot -d messenger.rare-books.ru
```

### Шаг 3: Обновите код на сервере

```bash
cd /home/docker/RareBooksDokploy  # или ваш путь
git pull  # или скопируйте обновленные файлы
```

### Шаг 4: Перезапустите nginx

```bash
docker-compose restart proxy
```

### Шаг 5: Проверьте работу

```bash
# Через curl
curl -I https://messenger.rare-books.ru/health

# Или откройте в браузере:
# https://messenger.rare-books.ru/swagger
```

### Шаг 6: Настройте автообновление

```bash
# Отредактируйте путь в скрипте
nano scripts/renew_all_certificates.sh

# Скопируйте скрипт
sudo cp scripts/renew_all_certificates.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/renew_all_certificates.sh

# Добавьте в cron
sudo crontab -e
# Добавьте: 0 3 * * * /usr/local/bin/renew_all_certificates.sh >> /var/log/renew_cert.log 2>&1
```

---

## 📊 Структура сертификатов после настройки

```
/etc/letsencrypt/live/
├── rare-books.ru/
│   ├── fullchain.pem     ← Для rare-books.ru и www.rare-books.ru
│   └── privkey.pem
└── messenger.rare-books.ru/
    ├── fullchain.pem     ← Для messenger.rare-books.ru
    └── privkey.pem
```

**Каждый домен использует свой сертификат!**

---

## 🔍 Проверка результата

### Через браузер

1. Откройте https://messenger.rare-books.ru/swagger
2. Нажмите на замочек в адресной строке
3. Посмотрите информацию о сертификате
4. Должно быть: **"Выдан для: messenger.rare-books.ru"**
5. Срок действия: ~90 дней

### Через командную строку

```bash
# Проверка сертификата
openssl s_client -connect messenger.rare-books.ru:443 -servername messenger.rare-books.ru </dev/null 2>/dev/null | openssl x509 -noout -subject

# Должно вывести:
# subject=CN = messenger.rare-books.ru
```

### Проверка API

```bash
# Health check
curl https://messenger.rare-books.ru/health
# Ожидается: {"status":"Healthy"}

# Swagger
curl https://messenger.rare-books.ru/swagger
# Должен вернуть HTML страницу Swagger UI
```

---

## ⚠️ Возможные проблемы и решения

### Проблема 1: DNS не настроен

**Симптомы:**
- `nslookup messenger.rare-books.ru` не возвращает IP сервера
- Certbot выдает ошибку "DNS problem: NXDOMAIN"

**Решение:**
1. Настройте A-запись в DNS: `messenger.rare-books.ru → IP_сервера`
2. Подождите 5-30 минут распространения DNS
3. Повторите получение сертификата

### Проблема 2: Nginx не может обработать challenge

**Симптомы:**
- Certbot выдает ошибку "Failed authorization procedure"
- Ошибка "Connection refused"

**Решение:**
```bash
# Проверьте, что nginx запущен
docker ps | grep nginx

# Проверьте логи
docker logs nginx_container

# Проверьте доступность
curl -I http://messenger.rare-books.ru
```

### Проблема 3: Браузер все еще показывает ошибку сертификата

**Симптомы:**
- В браузере ошибка NET::ERR_CERT_COMMON_NAME_INVALID
- Сертификат показывает rare-books.ru вместо messenger.rare-books.ru

**Решение:**
```bash
# Убедитесь, что nginx использует обновленную конфигурацию
docker exec nginx_container cat /etc/nginx/nginx.conf | grep -A3 "messenger.rare-books.ru"

# Если видите старые пути, обновите конфигурацию и перезапустите
docker-compose restart proxy

# Очистите кэш браузера и попробуйте снова
```

### Проблема 4: 502 Bad Gateway

**Симптомы:**
- HTTPS работает, но API возвращает 502

**Решение:**
```bash
# Проверьте статус backend
docker ps | grep maymessenger

# Проверьте логи
docker logs maymessenger_backend

# Перезапустите backend
docker-compose restart maymessenger_backend
```

---

## 📞 Полезные команды

```bash
# Статус всех сертификатов
sudo certbot certificates

# Проверка автообновления
sudo certbot renew --dry-run

# Логи nginx
docker logs nginx_container -f

# Логи messenger backend
docker logs maymessenger_backend -f

# Проверка конфигурации nginx
docker exec nginx_container nginx -t

# Перезапуск только nginx
docker-compose restart proxy

# Полный перезапуск
docker-compose restart
```

---

## 📚 Дополнительная информация

### Сертификаты Let's Encrypt

- **Срок действия:** 90 дней
- **Автообновление:** За 30 дней до истечения
- **Проверка обновлений:** Ежедневно в 3:00 (через cron)
- **Стоимость:** Бесплатно

### Структура проекта

```
RareBooksDokploy/
├── docker-compose.yml
├── nginx/
│   └── nginx_prod.conf          ← Обновлен
├── scripts/
│   ├── get_messenger_certificate.sh       ← Новый
│   ├── renew_all_certificates.sh          ← Новый
│   ├── QUICK_START.md                     ← Новый
│   ├── CERTIFICATE_SETUP_INSTRUCTIONS.md  ← Новый
│   └── README.md                          ← Новый
└── CERTIFICATE_CHANGES_SUMMARY.md         ← Этот файл
```

### Монтирование в Docker

В `docker-compose.yml` уже настроено:

```yaml
volumes:
  - /etc/letsencrypt:/etc/letsencrypt:ro   # Сертификаты
  - /var/www/certbot:/var/www/certbot      # Challenge-файлы
```

Поэтому сертификаты, полученные на хосте, автоматически доступны в контейнере nginx.

---

## ✅ Финальный checklist

После выполнения всех шагов:

- [ ] DNS для messenger.rare-books.ru настроен
- [ ] Сертификат для messenger.rare-books.ru получен
- [ ] Nginx перезапущен с обновленной конфигурацией
- [ ] https://messenger.rare-books.ru/swagger открывается
- [ ] Сертификат в браузере показывает messenger.rare-books.ru
- [ ] API отвечает без ошибок
- [ ] Автообновление настроено в cron
- [ ] Тестовый запуск автообновления выполнен

---

## 🎉 Результат

После выполнения всех шагов:

✅ **https://messenger.rare-books.ru/api** работает с валидным SSL сертификатом  
✅ Браузеры не показывают предупреждений о безопасности  
✅ Сертификаты автоматически обновляются каждые 60 дней  
✅ Приложение полностью готово к продакшену  

---

**Версия:** 1.0  
**Дата:** Декабрь 2024  
**Автор:** Assistant  
**Проект:** RareBooks + MayMessenger

