#!/bin/bash

# Скрипт для пересборки iOS приложения и тестирования push-уведомлений
# После настройки APNs ключа в Firebase Console

echo "🔧 Пересборка iOS приложения для активации push-уведомлений..."
echo ""

# Цвета
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Очистка
echo -e "${BLUE}📦 Шаг 1/5: Очистка кеша...${NC}"
flutter clean
echo -e "${GREEN}✅ Готово${NC}"
echo ""

# 2. Получение зависимостей
echo -e "${BLUE}📦 Шаг 2/5: Получение зависимостей...${NC}"
flutter pub get
echo -e "${GREEN}✅ Готово${NC}"
echo ""

# 3. Обновление CocoaPods
echo -e "${BLUE}📦 Шаг 3/5: Обновление CocoaPods...${NC}"
cd ios
pod deintegrate 2>/dev/null || true
pod install
cd ..
echo -e "${GREEN}✅ Готово${NC}"
echo ""

# 4. Сборка и установка
echo -e "${BLUE}📱 Шаг 4/5: Сборка и установка на iPhone...${NC}"
echo ""
echo -e "${YELLOW}⚠️  ВАЖНО: Подключите iPhone к Mac через USB!${NC}"
echo -e "${YELLOW}⚠️  При первом запуске РАЗРЕШИТЕ уведомления!${NC}"
echo ""
echo "Начинаю сборку и установку..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 ПРОВЕРЬТЕ ЛОГИ НИЖЕ:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✅ Если увидите оба сообщения - всё работает:${NC}"
echo "   APNs token received:"
echo "   FCM registration token:"
echo ""
echo -e "${YELLOW}⚠️  Если только первое - проверьте Firebase Console${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

flutter run --release

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
