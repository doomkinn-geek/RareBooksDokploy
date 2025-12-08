#!/bin/bash

# Скрипт для проверки готовности системы к получению SSL сертификата
# Запускать перед получением сертификата для messenger.rare-books.ru

DOMAIN="messenger.rare-books.ru"

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "Проверка готовности к получению SSL"
echo "Домен: ${DOMAIN}"
echo "========================================"
echo ""

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Функция для успешной проверки
check_ok() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

# Функция для ошибки
check_fail() {
    echo -e "${RED}✗${NC} $1"
    echo -e "  ${BLUE}→${NC} $2"
    ((CHECKS_FAILED++))
}

# Функция для предупреждения
check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    echo -e "  ${BLUE}→${NC} $2"
    ((CHECKS_WARNING++))
}

# 1. Проверка Certbot
echo "1. Проверка Certbot..."
if command -v certbot &> /dev/null; then
    certbot_version=$(certbot --version 2>&1 | head -1)
    check_ok "Certbot установлен: ${certbot_version}"
else
    check_fail "Certbot не установлен" "Установите: sudo apt update && sudo apt install certbot -y"
fi
echo ""

# 2. Проверка папки для challenge
echo "2. Проверка папки для challenge..."
if [ -d "/var/www/certbot" ]; then
    check_ok "Папка /var/www/certbot существует"
    
    # Проверка прав
    if [ -w "/var/www/certbot" ]; then
        check_ok "Папка доступна для записи"
    else
        check_warn "Папка не доступна для записи" "Может потребоваться sudo"
    fi
else
    check_fail "Папка /var/www/certbot не существует" "Создайте: sudo mkdir -p /var/www/certbot"
fi
echo ""

# 3. Проверка DNS
echo "3. Проверка DNS..."
dns_result=$(nslookup ${DOMAIN} 2>/dev/null | grep -A1 "Name:" | grep "Address:" | head -1 | awk '{print $2}')

if [ -n "${dns_result}" ]; then
    check_ok "DNS настроен: ${DOMAIN} → ${dns_result}"
    
    # Получение внешнего IP сервера
    server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null)
    
    if [ -n "${server_ip}" ]; then
        if [ "${dns_result}" = "${server_ip}" ]; then
            check_ok "DNS указывает на этот сервер (${server_ip})"
        else
            check_warn "DNS указывает на ${dns_result}, но IP сервера ${server_ip}" "Убедитесь, что это правильно"
        fi
    fi
else
    check_fail "DNS не настроен для ${DOMAIN}" "Настройте A-запись: ${DOMAIN} → IP_вашего_сервера"
fi
echo ""

# 4. Проверка Docker
echo "4. Проверка Docker..."
if command -v docker &> /dev/null; then
    check_ok "Docker установлен"
    
    # Проверка docker-compose
    if command -v docker-compose &> /dev/null; then
        check_ok "Docker Compose установлен"
    else
        check_warn "Docker Compose не найден" "Может потребоваться для перезапуска контейнеров"
    fi
else
    check_fail "Docker не установлен" "Установите Docker"
fi
echo ""

# 5. Проверка nginx контейнера
echo "5. Проверка nginx контейнера..."
nginx_running=$(docker ps --filter "name=nginx_container" --format "{{.Names}}" 2>/dev/null)

if [ -n "${nginx_running}" ]; then
    check_ok "Nginx контейнер запущен: ${nginx_running}"
    
    # Проверка портов
    nginx_ports=$(docker port nginx_container 2>/dev/null | grep -E "(80|443)")
    if echo "${nginx_ports}" | grep -q "80"; then
        check_ok "Порт 80 открыт"
    else
        check_fail "Порт 80 не открыт" "Проверьте docker-compose.yml"
    fi
    
    if echo "${nginx_ports}" | grep -q "443"; then
        check_ok "Порт 443 открыт"
    else
        check_fail "Порт 443 не открыт" "Проверьте docker-compose.yml"
    fi
    
    # Проверка монтирования /var/www/certbot
    certbot_mount=$(docker inspect nginx_container 2>/dev/null | grep -o "/var/www/certbot")
    if [ -n "${certbot_mount}" ]; then
        check_ok "Папка /var/www/certbot смонтирована в контейнер"
    else
        check_fail "Папка /var/www/certbot НЕ смонтирована" "Проверьте volumes в docker-compose.yml"
    fi
    
    # Проверка монтирования /etc/letsencrypt
    letsencrypt_mount=$(docker inspect nginx_container 2>/dev/null | grep -o "/etc/letsencrypt")
    if [ -n "${letsencrypt_mount}" ]; then
        check_ok "Папка /etc/letsencrypt смонтирована в контейнер"
    else
        check_fail "Папка /etc/letsencrypt НЕ смонтирована" "Проверьте volumes в docker-compose.yml"
    fi
    
else
    check_fail "Nginx контейнер не запущен" "Запустите: docker-compose up -d proxy"
fi
echo ""

# 6. Проверка доступности HTTP
echo "6. Проверка доступности HTTP..."
http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://${DOMAIN}/ 2>/dev/null)

if [ -n "${http_code}" ] && [ "${http_code}" != "000" ]; then
    check_ok "HTTP доступен (код ${http_code})"
    
    # Проверка /.well-known/acme-challenge/
    # Создаем тестовый файл
    test_file="test-$(date +%s).txt"
    echo "test" | sudo tee /var/www/certbot/${test_file} > /dev/null 2>&1
    
    if [ -f "/var/www/certbot/${test_file}" ]; then
        challenge_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${DOMAIN}/.well-known/acme-challenge/${test_file}" 2>/dev/null)
        
        if [ "${challenge_code}" = "200" ]; then
            check_ok "Challenge endpoint доступен (/.well-known/acme-challenge/)"
        else
            check_fail "Challenge endpoint недоступен (код ${challenge_code})" "Проверьте nginx конфигурацию для location /.well-known/acme-challenge/"
        fi
        
        # Удаляем тестовый файл
        sudo rm -f /var/www/certbot/${test_file}
    fi
else
    check_fail "HTTP недоступен" "Проверьте nginx и firewall"
fi
echo ""

# 7. Проверка messenger backend
echo "7. Проверка messenger backend..."
messenger_running=$(docker ps --filter "name=maymessenger_backend" --format "{{.Names}}" 2>/dev/null)

if [ -n "${messenger_running}" ]; then
    check_ok "Messenger backend запущен: ${messenger_running}"
else
    check_warn "Messenger backend не запущен" "Запустите: docker-compose up -d maymessenger_backend"
fi
echo ""

# 8. Проверка существующих сертификатов
echo "8. Проверка существующих сертификатов..."
if [ -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    check_warn "Сертификат для ${DOMAIN} уже существует" "Если нужно переполучить, удалите: sudo certbot delete --cert-name ${DOMAIN}"
    
    # Проверка срока действия
    if [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
        expiry_date=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" | cut -d= -f2)
        expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "${expiry_date}" +%s 2>/dev/null)
        current_epoch=$(date +%s)
        days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        if [ ${days_left} -lt 0 ]; then
            check_fail "Сертификат истек ${days_left#-} дней назад!" "Получите новый сертификат"
        elif [ ${days_left} -lt 30 ]; then
            check_warn "Сертификат истекает через ${days_left} дней" "Рекомендуется обновить"
        else
            check_ok "Сертификат действителен еще ${days_left} дней"
        fi
    fi
else
    check_ok "Сертификат еще не получен (можно продолжать)"
fi
echo ""

# 9. Проверка firewall
echo "9. Проверка firewall..."
if command -v ufw &> /dev/null; then
    ufw_status=$(sudo ufw status 2>/dev/null | grep -i "status:" | awk '{print $2}')
    
    if [ "${ufw_status}" = "active" ]; then
        check_ok "UFW firewall активен"
        
        # Проверка портов
        if sudo ufw status | grep -q "80"; then
            check_ok "Порт 80 открыт в firewall"
        else
            check_warn "Порт 80 не найден в правилах firewall" "Откройте: sudo ufw allow 80"
        fi
        
        if sudo ufw status | grep -q "443"; then
            check_ok "Порт 443 открыт в firewall"
        else
            check_warn "Порт 443 не найден в правилах firewall" "Откройте: sudo ufw allow 443"
        fi
    else
        check_ok "UFW firewall неактивен"
    fi
else
    check_ok "UFW не установлен (возможно используется другой firewall)"
fi
echo ""

# Итоги
echo "========================================"
echo "Итоги проверки"
echo "========================================"
echo -e "${GREEN}✓${NC} Успешно: ${CHECKS_PASSED}"
echo -e "${YELLOW}⚠${NC} Предупреждений: ${CHECKS_WARNING}"
echo -e "${RED}✗${NC} Ошибок: ${CHECKS_FAILED}"
echo ""

# Рекомендации
if [ ${CHECKS_FAILED} -eq 0 ]; then
    if [ ${CHECKS_WARNING} -eq 0 ]; then
        echo -e "${GREEN}================================${NC}"
        echo -e "${GREEN}🎉 Система полностью готова!${NC}"
        echo -e "${GREEN}================================${NC}"
        echo ""
        echo "Вы можете получить сертификат:"
        echo ""
        echo -e "${BLUE}sudo certbot certonly --webroot -w /var/www/certbot -d ${DOMAIN}${NC}"
        echo ""
        echo "Или используйте скрипт:"
        echo ""
        echo -e "${BLUE}chmod +x scripts/get_messenger_certificate.sh${NC}"
        echo -e "${BLUE}sudo scripts/get_messenger_certificate.sh${NC}"
    else
        echo -e "${YELLOW}================================${NC}"
        echo -e "${YELLOW}⚠ Есть предупреждения${NC}"
        echo -e "${YELLOW}================================${NC}"
        echo ""
        echo "Вы можете продолжить, но рекомендуется"
        echo "устранить предупреждения для лучшей стабильности."
    fi
else
    echo -e "${RED}================================${NC}"
    echo -e "${RED}❌ Есть критические ошибки!${NC}"
    echo -e "${RED}================================${NC}"
    echo ""
    echo "Устраните ошибки перед получением сертификата."
    echo "Прокрутите вывод выше и следуйте рекомендациям."
fi

echo ""

