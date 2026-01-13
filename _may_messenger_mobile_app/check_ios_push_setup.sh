#!/bin/bash

# Скрипт проверки настройки iOS push-уведомлений
# Использование: ./check_ios_push_setup.sh

echo "🔍 Проверка настройки iOS push-уведомлений..."
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# 1. Проверка GoogleService-Info.plist
echo "📋 1. Проверка GoogleService-Info.plist..."
if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo -e "${GREEN}✅ GoogleService-Info.plist существует${NC}"
    
    # Проверка Bundle ID
    BUNDLE_ID=$(grep -A 1 "BUNDLE_ID" ios/Runner/GoogleService-Info.plist | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
    if [ "$BUNDLE_ID" = "com.maymessenger.mobileApp" ]; then
        echo -e "${GREEN}✅ Bundle ID правильный: $BUNDLE_ID${NC}"
    else
        echo -e "${RED}❌ Bundle ID неправильный: $BUNDLE_ID${NC}"
        echo -e "${RED}   Должен быть: com.maymessenger.mobileApp${NC}"
        ERRORS=$((ERRORS+1))
    fi
    
    # Проверка что файл добавлен в Xcode проект
    if grep -q "GoogleService-Info.plist" ios/Runner.xcodeproj/project.pbxproj; then
        echo -e "${GREEN}✅ Файл добавлен в Xcode проект${NC}"
    else
        echo -e "${RED}❌ Файл НЕ добавлен в Xcode проект${NC}"
        echo -e "${YELLOW}   Откройте: open ios/Runner.xcworkspace${NC}"
        echo -e "${YELLOW}   Правый клик на Runner → Add Files → выберите GoogleService-Info.plist${NC}"
        ERRORS=$((ERRORS+1))
    fi
else
    echo -e "${RED}❌ GoogleService-Info.plist НЕ найден${NC}"
    echo -e "${YELLOW}   Скачайте из Firebase Console и скопируйте в ios/Runner/${NC}"
    ERRORS=$((ERRORS+1))
fi
echo ""

# 2. Проверка Entitlements
echo "📋 2. Проверка Entitlements..."
if [ -f "ios/Runner/Runner.entitlements" ]; then
    echo -e "${GREEN}✅ Runner.entitlements существует${NC}"
    
    if grep -q "aps-environment" ios/Runner/Runner.entitlements; then
        APS_ENV=$(grep -A 1 "aps-environment" ios/Runner/Runner.entitlements | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        if [ "$APS_ENV" = "production" ]; then
            echo -e "${GREEN}✅ aps-environment: production${NC}"
        else
            echo -e "${YELLOW}⚠️  aps-environment: $APS_ENV (должно быть production для Release)${NC}"
            WARNINGS=$((WARNINGS+1))
        fi
    else
        echo -e "${RED}❌ aps-environment не найден в Runner.entitlements${NC}"
        ERRORS=$((ERRORS+1))
    fi
else
    echo -e "${RED}❌ Runner.entitlements НЕ найден${NC}"
    ERRORS=$((ERRORS+1))
fi

if [ -f "ios/Runner/RunnerDebug.entitlements" ]; then
    echo -e "${GREEN}✅ RunnerDebug.entitlements существует${NC}"
    
    if grep -q "aps-environment" ios/Runner/RunnerDebug.entitlements; then
        APS_ENV=$(grep -A 1 "aps-environment" ios/Runner/RunnerDebug.entitlements | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        if [ "$APS_ENV" = "development" ]; then
            echo -e "${GREEN}✅ aps-environment: development${NC}"
        else
            echo -e "${YELLOW}⚠️  aps-environment: $APS_ENV (должно быть development для Debug)${NC}"
            WARNINGS=$((WARNINGS+1))
        fi
    fi
else
    echo -e "${RED}❌ RunnerDebug.entitlements НЕ найден${NC}"
    ERRORS=$((ERRORS+1))
fi
echo ""

# 3. Проверка Info.plist
echo "📋 3. Проверка Info.plist..."
if [ -f "ios/Runner/Info.plist" ]; then
    echo -e "${GREEN}✅ Info.plist существует${NC}"
    
    # Проверка UIBackgroundModes
    if grep -q "UIBackgroundModes" ios/Runner/Info.plist; then
        echo -e "${GREEN}✅ UIBackgroundModes настроены${NC}"
        
        if grep -q "remote-notification" ios/Runner/Info.plist; then
            echo -e "${GREEN}✅ remote-notification включен${NC}"
        else
            echo -e "${RED}❌ remote-notification НЕ включен${NC}"
            ERRORS=$((ERRORS+1))
        fi
    else
        echo -e "${RED}❌ UIBackgroundModes не найдены${NC}"
        ERRORS=$((ERRORS+1))
    fi
    
    # Проверка FirebaseAppDelegateProxyEnabled
    if grep -q "FirebaseAppDelegateProxyEnabled" ios/Runner/Info.plist; then
        echo -e "${GREEN}✅ FirebaseAppDelegateProxyEnabled настроен${NC}"
    else
        echo -e "${YELLOW}⚠️  FirebaseAppDelegateProxyEnabled не найден${NC}"
        WARNINGS=$((WARNINGS+1))
    fi
else
    echo -e "${RED}❌ Info.plist НЕ найден${NC}"
    ERRORS=$((ERRORS+1))
fi
echo ""

# 4. Проверка AppDelegate.swift
echo "📋 4. Проверка AppDelegate.swift..."
if [ -f "ios/Runner/AppDelegate.swift" ]; then
    echo -e "${GREEN}✅ AppDelegate.swift существует${NC}"
    
    if grep -q "import Firebase" ios/Runner/AppDelegate.swift; then
        echo -e "${GREEN}✅ Firebase импортирован${NC}"
    else
        echo -e "${RED}❌ Firebase НЕ импортирован${NC}"
        ERRORS=$((ERRORS+1))
    fi
    
    if grep -q "FirebaseApp.configure()" ios/Runner/AppDelegate.swift; then
        echo -e "${GREEN}✅ Firebase инициализирован${NC}"
    else
        echo -e "${RED}❌ Firebase НЕ инициализирован${NC}"
        ERRORS=$((ERRORS+1))
    fi
    
    if grep -q "registerForRemoteNotifications" ios/Runner/AppDelegate.swift; then
        echo -e "${GREEN}✅ Регистрация в APNs настроена${NC}"
    else
        echo -e "${RED}❌ Регистрация в APNs НЕ настроена${NC}"
        ERRORS=$((ERRORS+1))
    fi
else
    echo -e "${RED}❌ AppDelegate.swift НЕ найден${NC}"
    ERRORS=$((ERRORS+1))
fi
echo ""

# 5. Проверка Podfile
echo "📋 5. Проверка Podfile..."
if [ -f "ios/Podfile" ]; then
    echo -e "${GREEN}✅ Podfile существует${NC}"
    
    if grep -q "use_frameworks!" ios/Podfile; then
        echo -e "${GREEN}✅ use_frameworks! настроен${NC}"
    else
        echo -e "${RED}❌ use_frameworks! НЕ настроен${NC}"
        ERRORS=$((ERRORS+1))
    fi
    
    if grep -q "platform :ios" ios/Podfile; then
        IOS_VERSION=$(grep "platform :ios" ios/Podfile | sed "s/.*platform :ios, '\(.*\)'.*/\1/")
        echo -e "${GREEN}✅ iOS платформа: $IOS_VERSION${NC}"
    else
        echo -e "${YELLOW}⚠️  iOS платформа не указана${NC}"
        WARNINGS=$((WARNINGS+1))
    fi
else
    echo -e "${RED}❌ Podfile НЕ найден${NC}"
    ERRORS=$((ERRORS+1))
fi
echo ""

# 6. Проверка Xcode проекта
echo "📋 6. Проверка Xcode проекта..."
if grep -q "CODE_SIGN_ENTITLEMENTS" ios/Runner.xcodeproj/project.pbxproj; then
    echo -e "${GREEN}✅ Entitlements подключены в Xcode${NC}"
else
    echo -e "${RED}❌ Entitlements НЕ подключены в Xcode${NC}"
    ERRORS=$((ERRORS+1))
fi

if grep -q "DM754J3JJS" ios/Runner.xcodeproj/project.pbxproj; then
    echo -e "${GREEN}✅ Development Team настроена${NC}"
else
    echo -e "${YELLOW}⚠️  Development Team не найдена${NC}"
    WARNINGS=$((WARNINGS+1))
fi
echo ""

# Итоги
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 РЕЗУЛЬТАТЫ ПРОВЕРКИ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ ВСЁ НАСТРОЕНО ПРАВИЛЬНО!${NC}"
    echo ""
    echo "🎯 Следующие шаги:"
    echo "   1. Создайте APNs ключ: https://developer.apple.com/account/resources/authkeys/list"
    echo "   2. Загрузите ключ в Firebase Console: https://console.firebase.google.com"
    echo "   3. Пересоберите приложение: flutter clean && flutter run --release"
    echo ""
    echo "📚 Подробнее: QUICK_APNS_FIX.md"
else
    echo -e "${RED}❌ Ошибки: $ERRORS${NC}"
    echo -e "${YELLOW}⚠️  Предупреждения: $WARNINGS${NC}"
    echo ""
    echo "🔧 Что делать:"
    if [ $ERRORS -gt 0 ]; then
        echo "   1. Исправьте ошибки выше"
    fi
    echo "   2. См. подробную инструкцию: SETUP_IOS_PUSH_NOTIFICATIONS.md"
    echo "   3. Быстрое решение: QUICK_APNS_FIX.md"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ⚠️ КРИТИЧЕСКИ ВАЖНО
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}⚠️  КРИТИЧЕСКИ ВАЖНО ДЛЯ iOS УВЕДОМЛЕНИЙ${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Даже если все проверки выше прошли успешно, уведомления"
echo "НЕ будут работать без APNs ключа в Firebase Console!"
echo ""
echo "🔑 Обязательно выполните:"
echo ""
echo "1️⃣  Создайте APNs ключ (.p8):"
echo "    https://developer.apple.com/account/resources/authkeys/list"
echo ""
echo "2️⃣  Загрузите ключ в Firebase:"
echo "    https://console.firebase.google.com"
echo "    → Project settings → Cloud Messaging → Upload APNs key"
echo ""
echo "3️⃣  Пересоберите приложение:"
echo "    flutter clean && flutter run --release"
echo ""
echo "📋 Пошаговая инструкция: APNS_SETUP_CHECKLIST.md"
echo "⚡️ Быстрое решение: QUICK_APNS_FIX.md"
echo ""

if [ $ERRORS -gt 0 ]; then
    exit 1
else
    exit 0
fi
