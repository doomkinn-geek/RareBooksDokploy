# 🚀 Депеша - Быстрый старт

## Автоматическая сборка (Рекомендуется)

```powershell
cd D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react
.\build-android.ps1
```

Скрипт автоматически:
- ✅ Проверит окружение (Node.js, Java, Android SDK)
- ✅ Установит зависимости
- ✅ Скомпилирует TypeScript
- ✅ Запустит Metro Bundler
- ✅ Соберет и установит APK
- ✅ Проверит результат

**Первая сборка:** ~10 минут  
**Последующие сборки:** ~2-3 минуты

---

## Требования (один раз)

### 1. JDK 17-20
```powershell
# Скачать: https://adoptium.net/temurin/releases/?version=17
# После установки проверить:
java -version
```

### 2. Android SDK
- Установить через Android Studio
- **SDK Platform 33** (API Level 33)
- **Build-Tools 33.0.0**
- Настроить ANDROID_HOME

### 3. Эмулятор или устройство
```powershell
# Список эмуляторов:
emulator -list-avds

# Запуск:
emulator -avd Pixel_6_API_33

# Или подключить реальное устройство через USB с включенной отладкой
```

**Полные инструкции:** См. `SETUP_GUIDE.md`

---

## Firebase (опционально)

Для push-уведомлений нужен `google-services.json`:

1. Откройте https://console.firebase.google.com/
2. Создайте проект "Depesha"
3. Добавьте Android app с package: `com.depesha`
4. Скачайте `google-services.json`
5. Разместите в `android/app/google-services.json`

**Подробная инструкция:** См. `FIREBASE_SETUP_DETAILED.md`

---

## Ручная сборка (если нужно)

```powershell
# 1. Установить зависимости
npm install

# 2. Запустить Metro (Terminal 1)
npm start

# 3. Собрать и установить (Terminal 2)
npm run android
```

---

## Полезные команды

```powershell
# Проверка устройств
adb devices

# Логи приложения
adb logcat | Select-String "ReactNative"

# Очистка сборки
cd android
.\gradlew clean
cd ..

# Переустановка зависимостей
Remove-Item -Recurse -Force node_modules
npm install

# Dev Menu в эмуляторе
# Ctrl+M → Enable Hot Reload / Debug
```

---

## Структура проекта

```
_may_messenger_native_react/
├── android/              # Android нативный код
│   └── app/
│       ├── build.gradle
│       └── google-services.json  ← Firebase (добавить)
├── src/
│   ├── api/              # API клиенты
│   ├── components/       # React компоненты
│   ├── screens/          # Экраны
│   ├── services/         # Сервисы (SignalR, FCM, SQLite)
│   └── store/            # Redux state
├── assets/               # Ассеты (иконки, изображения)
├── build-android.ps1     ← Автоматическая сборка
├── package.json
└── QUICK_START.md        ← Этот файл
```

---

## Troubleshooting

### "SDK location not found"
```powershell
echo "sdk.dir=$env:LOCALAPPDATA\Android\Sdk" | Out-File android\local.properties -Encoding utf8
```

### "Unable to load script"
```powershell
npm start -- --reset-cache
```

### "INSTALL_FAILED_UPDATE_INCOMPATIBLE"
```powershell
adb uninstall com.depesha
npm run android
```

**Больше решений:** См. `SETUP_GUIDE.md` раздел Troubleshooting

---

## Что дальше?

1. **Первый запуск:** `.\build-android.ps1`
2. **Firebase:** `FIREBASE_SETUP_DETAILED.md`
3. **Полная документация:** `COMPLETE_PROJECT_SUMMARY.md`

**Удачи! 🚀**

