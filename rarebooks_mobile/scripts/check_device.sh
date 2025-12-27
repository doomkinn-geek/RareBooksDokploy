#!/bin/bash
# Скрипт для проверки подключения Android устройства
# Использование: ./scripts/check_device.sh

echo "=== Проверка подключения Android устройства ==="
echo ""

# Проверка наличия adb
if ! command -v adb &> /dev/null; then
    echo "ОШИБКА: adb не найден в PATH!"
    echo "Убедитесь что Android SDK Platform Tools установлены."
    exit 1
fi

echo "✓ adb найден: $(which adb)"
echo ""

# Проверка подключенных устройств
echo "Проверка подключенных устройств..."
DEVICES=$(adb devices | tail -n +2 | grep -v '^$' | grep -v 'List of devices')

if [ -z "$DEVICES" ]; then
    echo "ОШИБКА: Устройства не найдены!"
    echo ""
    echo "Убедитесь что:"
    echo "  1. Устройство подключено через USB"
    echo "  2. Включена отладка по USB (Настройки > Для разработчиков > Отладка по USB)"
    echo "  3. Разрешена отладка на компьютере (если появился запрос)"
    echo ""
    echo "Попробуйте выполнить: adb devices"
    exit 1
fi

DEVICE_COUNT=$(echo "$DEVICES" | wc -l)
echo "✓ Найдено устройств: $DEVICE_COUNT"
echo ""

# Вывод списка устройств
echo "Список подключенных устройств:"
while IFS= read -r line; do
    DEVICE_ID=$(echo "$line" | awk '{print $1}')
    STATUS=$(echo "$line" | awk '{print $2}')
    
    if [ "$STATUS" = "device" ]; then
        echo "  ✓ $DEVICE_ID - готово к отладке"
        
        # Получение информации об устройстве
        MODEL=$(adb -s "$DEVICE_ID" shell getprop ro.product.model 2>/dev/null)
        ANDROID_VERSION=$(adb -s "$DEVICE_ID" shell getprop ro.build.version.release 2>/dev/null)
        echo "    Модель: $MODEL"
        echo "    Android: $ANDROID_VERSION"
    else
        echo "  ⚠ $DEVICE_ID - $STATUS"
    fi
    echo ""
done <<< "$DEVICES"

# Проверка Flutter
echo "Проверка Flutter..."
if ! command -v flutter &> /dev/null; then
    echo "ОШИБКА: flutter не найден в PATH!"
    exit 1
fi

echo "✓ Flutter найден: $(which flutter)"
echo ""

# Проверка устройств через Flutter
echo "Устройства, обнаруженные Flutter:"
flutter devices
echo ""

echo "=== Готово к отладке! ==="
echo ""
echo "Для запуска отладки:"
echo "  1. Откройте VS Code"
echo "  2. Нажмите F5 или выберите 'Run > Start Debugging'"
echo "  3. Выберите конфигурацию 'RareBooks Mobile (Debug)'"
echo ""

