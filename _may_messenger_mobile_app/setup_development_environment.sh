#!/bin/bash

# Скрипт автоматической установки окружения для разработки Flutter iOS/Android
# Для macOS

set -e  # Остановка при ошибке

echo "=================================================="
echo "   Установка окружения Flutter для iOS/Android"
echo "=================================================="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Функция проверки установки
check_installed() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 установлен"
        return 0
    else
        echo -e "${RED}✗${NC} $1 не установлен"
        return 1
    fi
}

# Функция установки с подтверждением
ask_install() {
    echo -e "${YELLOW}Установить $1? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        return 0
    else
        return 1
    fi
}

echo "Шаг 1: Проверка существующих инструментов"
echo "----------------------------------------"

# Проверка Xcode
if check_installed "xcodebuild"; then
    xcodebuild -version
else
    echo -e "${RED}ОШИБКА: Xcode не установлен!${NC}"
    echo "Установите Xcode из Mac App Store, затем запустите скрипт снова."
    exit 1
fi

# Проверка Homebrew
if ! check_installed "brew"; then
    echo ""
    if ask_install "Homebrew"; then
        echo "Установка Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Добавление в PATH
        if [[ $(uname -m) == 'arm64' ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        
        echo -e "${GREEN}✓ Homebrew установлен${NC}"
    else
        echo "Пропуск установки Homebrew"
    fi
fi

echo ""
echo "Шаг 2: Установка Flutter"
echo "----------------------------------------"

if ! check_installed "flutter"; then
    echo ""
    if ask_install "Flutter"; then
        echo "Установка Flutter..."
        brew install --cask flutter
        
        # Добавление в PATH если нужно
        if ! grep -q "flutter" ~/.zshrc; then
            echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
        fi
        
        echo -e "${GREEN}✓ Flutter установлен${NC}"
    else
        echo -e "${RED}Flutter необходим для продолжения!${NC}"
        exit 1
    fi
else
    flutter --version
fi

echo ""
echo "Шаг 3: Установка CocoaPods"
echo "----------------------------------------"

if ! check_installed "pod"; then
    echo ""
    if ask_install "CocoaPods"; then
        echo "Установка CocoaPods..."
        brew install cocoapods
        echo -e "${GREEN}✓ CocoaPods установлен${NC}"
        
        echo "Инициализация репозитория CocoaPods (может занять несколько минут)..."
        pod setup
    else
        echo -e "${RED}CocoaPods необходим для iOS разработки!${NC}"
        exit 1
    fi
else
    pod --version
fi

echo ""
echo "Шаг 4: Настройка Xcode Command Line Tools"
echo "----------------------------------------"

if ! xcode-select -p &> /dev/null; then
    echo "Установка Xcode Command Line Tools..."
    xcode-select --install
else
    echo -e "${GREEN}✓ Xcode Command Line Tools настроены${NC}"
    xcode-select -p
fi

# Установка правильного пути
sudo xcodebuild -runFirstLaunch 2>/dev/null || true
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Принятие лицензии
echo "Принятие лицензии Xcode..."
sudo xcodebuild -license accept 2>/dev/null || echo "Лицензия уже принята"

echo ""
echo "Шаг 5: Проверка окружения Flutter"
echo "----------------------------------------"

flutter doctor -v

echo ""
echo "Шаг 6: Подготовка проекта"
echo "----------------------------------------"

PROJECT_DIR="/Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app"

if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
    
    echo "Получение зависимостей Flutter..."
    flutter pub get
    
    echo ""
    echo "Генерация иконок приложения..."
    flutter pub run flutter_launcher_icons
    
    echo ""
    echo "Установка iOS зависимостей (CocoaPods)..."
    cd ios
    
    # Очистка старых зависимостей если есть
    if [ -d "Pods" ]; then
        echo "Очистка старых pods..."
        pod deintegrate
    fi
    
    echo "Установка pods..."
    pod install --repo-update
    
    cd ..
    
    echo -e "${GREEN}✓ Проект подготовлен${NC}"
else
    echo -e "${RED}ОШИБКА: Проект не найден по пути $PROJECT_DIR${NC}"
    exit 1
fi

echo ""
echo "=================================================="
echo "           Установка завершена!"
echo "=================================================="
echo ""
echo "Следующие шаги:"
echo ""
echo "1. Настройте Firebase (см. SETUP_FLUTTER_AND_FIREBASE.md):"
echo "   - Скачайте google-services.json для Android"
echo "   - Скачайте GoogleService-Info.plist для iOS"
echo "   - Добавьте GoogleService-Info.plist в Xcode проект"
echo ""
echo "2. Для запуска на симуляторе:"
echo "   flutter run -d \"iPhone 15 Pro\""
echo ""
echo "3. Для запуска на реальном устройстве:"
echo "   - Подключите iPhone"
echo "   - Включите режим разработчика на устройстве"
echo "   - flutter run"
echo ""
echo "Подробная документация:"
echo "- IOS_DEPLOYMENT_GUIDE.md - развёртывание на iOS"
echo "- SETUP_FLUTTER_AND_FIREBASE.md - настройка Firebase"
echo ""
