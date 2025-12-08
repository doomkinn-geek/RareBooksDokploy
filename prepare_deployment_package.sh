#!/bin/bash

# =================================================================
# Скрипт подготовки пакета для развертывания на сервер
# Запускать локально в Windows через Git Bash или WSL
# =================================================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}=================================================================="
    echo -e "$1"
    echo -e "==================================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header "📦 Подготовка пакета для развертывания May Messenger"

# Проверка наличия необходимых файлов
print_info "Проверка наличия файлов..."

if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml не найден!"
    exit 1
fi

if [ ! -f "nginx/nginx_prod.conf" ]; then
    print_error "nginx/nginx_prod.conf не найден!"
    exit 1
fi

if [ ! -d "_may_messenger_backend" ]; then
    print_error "Директория _may_messenger_backend не найдена!"
    exit 1
fi

print_success "Все необходимые файлы найдены"
echo ""

# Создание архива backend
print_header "📦 Создание архива may_messenger_backend.zip"
cd _may_messenger_backend
zip -r ../may_messenger_backend.zip . -x "*.git*" "*/bin/*" "*/obj/*"
cd ..

if [ -f "may_messenger_backend.zip" ]; then
    size=$(du -h may_messenger_backend.zip | cut -f1)
    print_success "Архив создан: may_messenger_backend.zip ($size)"
else
    print_error "Ошибка создания архива!"
    exit 1
fi

echo ""

# Вывод инструкций
print_header "📤 Загрузка файлов на сервер"

echo "Выполните следующие команды для загрузки файлов на сервер:"
echo ""
echo "# 1. Загрузка docker-compose.yml"
echo "scp docker-compose.yml root@217.198.5.89:/root/RareBooksDokploy/docker-compose.yml.new"
echo ""
echo "# 2. Загрузка nginx_prod.conf"
echo "scp nginx/nginx_prod.conf root@217.198.5.89:/root/RareBooksDokploy/nginx/nginx_prod.conf.new"
echo ""
echo "# 3. Загрузка архива backend"
echo "scp may_messenger_backend.zip root@217.198.5.89:/root/RareBooksDokploy/"
echo ""
echo "# 4. Загрузка скрипта развертывания"
echo "scp deploy_maymessenger.sh root@217.198.5.89:/root/RareBooksDokploy/"
echo "scp verify_services.sh root@217.198.5.89:/root/RareBooksDokploy/"
echo "scp check_messenger_logs.sh root@217.198.5.89:/root/RareBooksDokploy/"
echo "scp rollback_deployment.sh root@217.198.5.89:/root/RareBooksDokploy/"
echo ""

print_header "🚀 Развертывание на сервере"

echo "После загрузки файлов на сервер выполните:"
echo ""
echo "# 1. Подключитесь к серверу"
echo "ssh root@217.198.5.89"
echo ""
echo "# 2. Перейдите в директорию проекта"
echo "cd /root/RareBooksDokploy"
echo ""
echo "# 3. Распакуйте архив backend"
echo "rm -rf MayMessenger"
echo "mkdir -p MayMessenger"
echo "unzip -q may_messenger_backend.zip -d MayMessenger/backend"
echo ""
echo "# 4. Примените новые конфигурации"
echo "cp docker-compose.yml.new docker-compose.yml"
echo "cp nginx/nginx_prod.conf.new nginx/nginx_prod.conf"
echo ""
echo "# 5. Сделайте скрипты исполняемыми"
echo "chmod +x deploy_maymessenger.sh verify_services.sh check_messenger_logs.sh rollback_deployment.sh"
echo ""
echo "# 6. Запустите развертывание"
echo "./deploy_maymessenger.sh"
echo ""
echo "# 7. После развертывания проверьте работу"
echo "./verify_services.sh"
echo ""

print_header "✅ Подготовка завершена"
print_success "Файлы готовы к загрузке на сервер"
echo ""

