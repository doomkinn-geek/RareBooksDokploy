#!/bin/bash

# Скрипт для автоматического обновления всех SSL сертификатов
# Используется в cron для периодического обновления

# Логирование
LOG_FILE="/var/log/renew_cert.log"
echo "=========================================" >> "$LOG_FILE"
echo "$(date): Начало обновления сертификатов" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"

# Обновление всех сертификатов
certbot renew --quiet >> "$LOG_FILE" 2>&1

# Проверка результата
if [ $? -eq 0 ]; then
    echo "$(date): Сертификаты успешно проверены/обновлены" >> "$LOG_FILE"
    
    # Перезапуск nginx в Docker для применения обновленных сертификатов
    # ВАЖНО: Укажите правильный путь к вашему docker-compose.yml
    cd /home/docker/RareBooksDokploy || cd /home/youruser/RareBooksDokploy
    
    if [ -f "docker-compose.yml" ]; then
        docker-compose restart proxy >> "$LOG_FILE" 2>&1
        echo "$(date): Nginx успешно перезапущен" >> "$LOG_FILE"
    else
        echo "$(date): ОШИБКА: docker-compose.yml не найден!" >> "$LOG_FILE"
    fi
else
    echo "$(date): ОШИБКА при обновлении сертификатов!" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"

