#!/bin/bash

# Скрипт для проверки статуса SSL сертификатов
# Использование: ./check_certificates.sh

echo "========================================"
echo "Проверка SSL сертификатов"
echo "========================================"
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для проверки сертификата
check_certificate() {
    local domain=$1
    local cert_path="/etc/letsencrypt/live/${domain}/fullchain.pem"
    
    echo "----------------------------------------"
    echo "Домен: ${domain}"
    echo "----------------------------------------"
    
    # Проверка наличия сертификата на диске
    if [ -f "${cert_path}" ]; then
        echo -e "${GREEN}✓${NC} Сертификат найден на диске"
        
        # Получение информации о сертификате
        expiry_date=$(openssl x509 -enddate -noout -in "${cert_path}" | cut -d= -f2)
        expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "${expiry_date}" +%s 2>/dev/null)
        current_epoch=$(date +%s)
        days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        echo "  Срок действия: ${expiry_date}"
        
        if [ ${days_left} -lt 0 ]; then
            echo -e "  ${RED}✗ ИСТЕК ${days_left#-} дней назад!${NC}"
        elif [ ${days_left} -lt 30 ]; then
            echo -e "  ${YELLOW}⚠ Осталось ${days_left} дней (скоро истечет)${NC}"
        else
            echo -e "  ${GREEN}✓ Осталось ${days_left} дней${NC}"
        fi
        
        # Проверка Subject Name
        subject=$(openssl x509 -subject -noout -in "${cert_path}" | sed 's/subject=//')
        echo "  Subject: ${subject}"
        
    else
        echo -e "${RED}✗${NC} Сертификат НЕ найден на диске!"
        echo "  Путь: ${cert_path}"
    fi
    
    # Проверка через сеть (если домен доступен)
    echo ""
    echo "  Проверка через сеть..."
    
    # Проверка DNS
    dns_ip=$(nslookup ${domain} 2>/dev/null | grep -A1 "Name:" | grep "Address:" | head -1 | awk '{print $2}')
    if [ -n "${dns_ip}" ]; then
        echo -e "  ${GREEN}✓${NC} DNS настроен: ${dns_ip}"
        
        # Проверка HTTPS
        https_check=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://${domain}/health 2>/dev/null || curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://${domain}/ 2>/dev/null)
        
        if [ -n "${https_check}" ] && [ "${https_check}" != "000" ]; then
            echo -e "  ${GREEN}✓${NC} HTTPS доступен (HTTP ${https_check})"
            
            # Проверка сертификата через OpenSSL
            cert_subject=$(openssl s_client -connect ${domain}:443 -servername ${domain} </dev/null 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//')
            
            if echo "${cert_subject}" | grep -q "${domain}"; then
                echo -e "  ${GREEN}✓${NC} Сертификат валиден для домена"
            else
                echo -e "  ${RED}✗${NC} Сертификат НЕ соответствует домену!"
                echo "    Получен: ${cert_subject}"
            fi
        else
            echo -e "  ${RED}✗${NC} HTTPS недоступен"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} DNS не настроен или недоступен"
    fi
    
    echo ""
}

# Проверка сертификатов для всех доменов
check_certificate "rare-books.ru"
check_certificate "messenger.rare-books.ru"

# Информация о Certbot
echo "========================================"
echo "Информация о Certbot"
echo "========================================"

if command -v certbot &> /dev/null; then
    echo -e "${GREEN}✓${NC} Certbot установлен"
    echo ""
    
    # Список всех сертификатов
    echo "Все сертификаты в системе:"
    echo ""
    certbot certificates 2>/dev/null || echo "Не удалось получить список сертификатов (нужны права sudo)"
else
    echo -e "${RED}✗${NC} Certbot не установлен!"
    echo "Установите: sudo apt install certbot -y"
fi

echo ""

# Проверка cron задачи
echo "========================================"
echo "Проверка автообновления (cron)"
echo "========================================"

cron_task=$(sudo crontab -l 2>/dev/null | grep renew)

if [ -n "${cron_task}" ]; then
    echo -e "${GREEN}✓${NC} Cron задача найдена:"
    echo "  ${cron_task}"
    
    # Проверка скрипта
    if [ -f "/usr/local/bin/renew_all_certificates.sh" ]; then
        echo -e "${GREEN}✓${NC} Скрипт обновления найден"
    else
        echo -e "${YELLOW}⚠${NC} Скрипт обновления НЕ найден: /usr/local/bin/renew_all_certificates.sh"
    fi
    
    # Проверка лога
    if [ -f "/var/log/renew_cert.log" ]; then
        echo -e "${GREEN}✓${NC} Лог обновлений найден"
        echo ""
        echo "Последние записи в логе:"
        tail -5 /var/log/renew_cert.log 2>/dev/null | sed 's/^/  /'
    else
        echo -e "${YELLOW}⚠${NC} Лог обновлений еще не создан"
    fi
else
    echo -e "${RED}✗${NC} Cron задача НЕ настроена!"
    echo "Настройте автообновление:"
    echo "  sudo crontab -e"
    echo "  0 3 * * * /usr/local/bin/renew_all_certificates.sh >> /var/log/renew_cert.log 2>&1"
fi

echo ""

# Проверка Docker
echo "========================================"
echo "Проверка Docker контейнеров"
echo "========================================"

if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker установлен"
    echo ""
    
    # Проверка nginx
    nginx_status=$(docker ps --filter "name=nginx_container" --format "{{.Status}}" 2>/dev/null)
    if [ -n "${nginx_status}" ]; then
        echo -e "${GREEN}✓${NC} Nginx контейнер запущен: ${nginx_status}"
    else
        echo -e "${RED}✗${NC} Nginx контейнер не запущен!"
    fi
    
    # Проверка messenger backend
    messenger_status=$(docker ps --filter "name=maymessenger_backend" --format "{{.Status}}" 2>/dev/null)
    if [ -n "${messenger_status}" ]; then
        echo -e "${GREEN}✓${NC} Messenger backend запущен: ${messenger_status}"
    else
        echo -e "${YELLOW}⚠${NC} Messenger backend не запущен"
    fi
else
    echo -e "${RED}✗${NC} Docker не установлен или недоступен"
fi

echo ""
echo "========================================"
echo "Проверка завершена!"
echo "========================================"

