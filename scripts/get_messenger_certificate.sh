#!/bin/bash

# Скрипт для получения SSL сертификата для messenger.rare-books.ru
# Запускать на хосте с правами sudo

echo "=========================================="
echo "Получение SSL сертификата для messenger.rare-books.ru"
echo "=========================================="

# Проверка наличия папки для challenge-файлов
if [ ! -d "/var/www/certbot" ]; then
    echo "Создание папки /var/www/certbot..."
    sudo mkdir -p /var/www/certbot
fi

# Получение сертификата
echo ""
echo "Запуск Certbot для получения сертификата..."
echo "ВАЖНО: Убедитесь, что домен messenger.rare-books.ru правильно настроен в DNS"
echo "и nginx уже запущен с конфигурацией, позволяющей обработку /.well-known/acme-challenge/"
echo ""

sudo certbot certonly --webroot -w /var/www/certbot -d messenger.rare-books.ru

# Проверка результата
if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Сертификат успешно получен!"
    echo ""
    echo "Сертификаты находятся здесь:"
    echo "  /etc/letsencrypt/live/messenger.rare-books.ru/fullchain.pem"
    echo "  /etc/letsencrypt/live/messenger.rare-books.ru/privkey.pem"
    echo ""
    echo "Следующие шаги:"
    echo "1. Обновите nginx/nginx_prod.conf (используйте обновленную конфигурацию)"
    echo "2. Перезапустите nginx контейнер:"
    echo "   docker-compose restart proxy"
    echo ""
else
    echo ""
    echo "✗ Ошибка при получении сертификата!"
    echo ""
    echo "Возможные причины:"
    echo "1. DNS записи для messenger.rare-books.ru не настроены или еще не распространились"
    echo "2. Nginx не запущен или не может обработать /.well-known/acme-challenge/"
    echo "3. Порты 80/443 недоступны извне"
    echo ""
    exit 1
fi

