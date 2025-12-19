# 🔥 Firebase - Подробная инструкция по настройке для Депеша

## Оглавление
1. [Создание Firebase проекта](#1-создание-firebase-проекта)
2. [Настройка Android приложения](#2-настройка-android-приложения)
3. [Настройка iOS приложения (опционально)](#3-настройка-ios-приложения-опционально)
4. [Настройка Cloud Messaging (FCM)](#4-настройка-cloud-messaging-fcm)
5. [Интеграция с бэкендом](#5-интеграция-с-бэкендом)
6. [Тестирование](#6-тестирование)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Создание Firebase проекта

### Шаг 1.1: Регистрация в Firebase Console

1. Откройте браузер и перейдите на https://console.firebase.google.com/
2. Войдите с вашим Google аккаунтом
3. Нажмите **"Add project"** (Добавить проект)

### Шаг 1.2: Заполнение информации о проекте

**Шаг 1 из 3: Название проекта**
- Project name: `Depesha` или `May Messenger`
- Нажмите **Continue**

**Шаг 2 из 3: Google Analytics**
- Включите Google Analytics (рекомендуется для статистики)
- Нажмите **Continue**

**Шаг 3 из 3: Google Analytics account**
- Выберите существующий аккаунт или создайте новый
- Примите условия использования
- Нажмите **Create project**

⏱️ **Создание проекта займет 30-60 секунд**

### Шаг 1.3: Завершение создания

Когда появится сообщение "Your new project is ready", нажмите **Continue**

---

## 2. Настройка Android приложения

### Шаг 2.1: Добавление Android приложения

1. В главном меню проекта нажмите на значок **Android** (робот)
2. Откроется форма "Add Firebase to your Android app"

### Шаг 2.2: Заполнение регистрационной формы

**Android package name:** (ОБЯЗАТЕЛЬНО!)
```
com.depesha
```
⚠️ **ВАЖНО:** Это должно точно совпадать с `applicationId` в `android/app/build.gradle`

**App nickname (optional):**
```
Depesha
```

**Debug signing certificate SHA-1 (optional):**
Пропустите на этом этапе (можно добавить позже для Firebase Auth)

Нажмите **Register app**

### Шаг 2.3: Скачивание конфигурационного файла

1. Firebase покажет кнопку **Download google-services.json**
2. Нажмите кнопку и сохраните файл
3. **ВАЖНО:** Переместите `google-services.json` в:
   ```
   D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react\android\app\
   ```

**Структура должна быть:**
```
_may_messenger_native_react/
└── android/
    └── app/
        ├── build.gradle
        ├── google-services.json  ← СЮДА!
        └── src/
```

### Шаг 2.4: Добавление Firebase SDK

Firebase попросит добавить зависимости. Они **УЖЕ УСТАНОВЛЕНЫ** в проекте!

Проверьте файлы:

**android/build.gradle:**
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

**android/app/build.gradle:**
```gradle
apply plugin: 'com.google.gms.google-services' // В конце файла
```

Если этих строк нет, добавьте их вручную.

Нажмите **Next**

### Шаг 2.5: Инициализация Firebase

Firebase покажет код инициализации. Он **УЖЕ РЕАЛИЗОВАН** в:
- `App.tsx` - инициализация Firebase
- `src/services/fcmService.ts` - обработка уведомлений

Нажмите **Next** → **Continue to console**

---

## 3. Настройка iOS приложения (опционально)

Если планируете iOS версию:

1. В Firebase Console нажмите **Add app** → iOS
2. iOS bundle ID: `com.depesha`
3. Скачайте `GoogleService-Info.plist`
4. Добавьте в `ios/` директорию
5. Установите CocoaPods зависимости:
   ```bash
   cd ios
   pod install
   cd ..
   ```

⚠️ **Для текущей задачи iOS не требуется**

---

## 4. Настройка Cloud Messaging (FCM)

### Шаг 4.1: Включение Cloud Messaging API

1. В Firebase Console перейдите в **Project settings** (значок ⚙️)
2. Вкладка **Cloud Messaging**
3. Найдите **Cloud Messaging API (Legacy)** статус
4. Если статус "Disabled", нажмите **Enable**

### Шаг 4.2: Получение Server Key для бэкенда

**Cloud Messaging API (Legacy):**
1. В той же вкладке **Cloud Messaging**
2. Раздел **Project credentials**
3. Найдите **Server key**
4. Скопируйте значение (начинается с `AAAA...`)

**⚠️ ВАЖНО: Сохраните этот ключ - он нужен для бэкенда!**

### Шаг 4.3: Получение нового API ключа (V1)

Firebase рекомендует использовать новый API (HTTP v1):

1. В **Cloud Messaging** найдите раздел **Firebase Cloud Messaging API**
2. Нажмите **Manage API in Google Cloud Console**
3. Включите **Firebase Cloud Messaging API**
4. Вернитесь в Firebase Console

### Шаг 4.4: Создание Service Account для бэкенда

1. **Project settings** → **Service accounts**
2. Нажмите **Generate new private key**
3. Подтвердите в диалоге
4. Скачается JSON файл (например, `depesha-firebase-adminsdk-xxxxx.json`)
5. **ВАЖНО:** Переименуйте файл в `firebase_config.json`

---

## 5. Интеграция с бэкендом

### Шаг 5.1: Размещение конфигурации на сервере

Скопируйте `firebase_config.json` на сервер:

```bash
# Windows → Linux сервер
scp firebase_config.json user@server:/app/MayMessenger/firebase_config.json

# Или через FileZilla/WinSCP
```

**Местоположение на сервере:**
```
/app/MayMessenger/
├── MayMessenger.API.dll
├── firebase_config.json  ← СЮДА
└── wwwroot/
```

### Шаг 5.2: Настройка конфигурации бэкенда

Файл: `appsettings.json` или `appsettings.Production.json`

```json
{
  "Firebase": {
    "ConfigPath": "firebase_config.json"
  }
}
```

Если файл в другом месте:
```json
{
  "Firebase": {
    "ConfigPath": "/app/MayMessenger/config/firebase_config.json"
  }
}
```

### Шаг 5.3: Проверка инициализации

После запуска бэкенда проверьте логи:

```bash
# Linux
sudo journalctl -u maymessenger -f | grep -i firebase

# Должно быть:
# Firebase initialized from /app/MayMessenger/firebase_config.json
```

Или через Health Check:
```bash
curl https://messenger.rare-books.ru/health
```

Ответ должен содержать:
```json
{
  "checks": [
    {
      "name": "firebase",
      "status": "Healthy"
    }
  ]
}
```

---

## 6. Тестирование

### Шаг 6.1: Сборка Android приложения

```powershell
cd D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react
.\build-android.ps1
```

### Шаг 6.2: Проверка FCM токена

1. Запустите приложение на эмуляторе/устройстве
2. Войдите в аккаунт
3. Проверьте логи:

```powershell
adb logcat | Select-String "FCM"
```

Должно быть:
```
[FCM] Token registered: e1A2B3C...
```

### Шаг 6.3: Отправка тестового уведомления

**Через Firebase Console:**
1. **Engage** → **Messaging** → **Create your first campaign**
2. **Firebase Notification messages**
3. Заполните:
   - **Notification title:** Тест
   - **Notification text:** Привет от Firebase!
4. **Send test message**
5. Введите FCM токен из логов
6. **Test**

**Через curl:**
```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "FCM_TOKEN_HERE",
    "notification": {
      "title": "Тест",
      "body": "Привет от Firebase!"
    }
  }'
```

### Шаг 6.4: Проверка в приложении

1. Отправьте сообщение от другого пользователя
2. Сверните приложение (background)
3. Должно прийти push-уведомление
4. Тап на уведомление → открывается чат

---

## 7. Troubleshooting

### Проблема: "google-services.json not found"

**Решение:**
```powershell
# Проверьте местоположение
ls android\app\google-services.json

# Если нет - скачайте снова из Firebase Console:
# Project settings → Your apps → Android → Download google-services.json
```

### Проблема: "Default FirebaseApp is not initialized"

**Причины:**
1. Отсутствует `google-services.json`
2. Не добавлен plugin в `android/app/build.gradle`

**Решение:**
```gradle
// android/app/build.gradle - в конце файла
apply plugin: 'com.google.gms.google-services'
```

Пересобрать:
```powershell
cd android
.\gradlew clean
cd ..
npm run android
```

### Проблема: "API project not found"

**Причина:** Cloud Messaging API не включен

**Решение:**
1. Firebase Console → Project settings → Cloud Messaging
2. **Manage API in Google Cloud Console**
3. **Enable Firebase Cloud Messaging API**

### Проблема: Firebase не инициализируется на бэкенде

**Проверка 1: Файл существует?**
```bash
ls -la /app/MayMessenger/firebase_config.json
```

**Проверка 2: Права доступа**
```bash
chmod 644 /app/MayMessenger/firebase_config.json
```

**Проверка 3: Корректный JSON**
```bash
cat /app/MayMessenger/firebase_config.json | jq .
# Должен вывести структурированный JSON без ошибок
```

### Проблема: Push-уведомления не приходят

**Чеклист:**
1. ✅ Firebase инициализирован на клиенте?
2. ✅ Firebase инициализирован на сервере?
3. ✅ FCM токен зарегистрирован? (проверьте БД таблицу FcmTokens)
4. ✅ Приложение в background? (foreground уведомления обрабатываются по-другому)
5. ✅ Internet разрешен в AndroidManifest.xml?

**Проверка FCM токена в БД:**
```sql
SELECT * FROM "FcmTokens" WHERE "UserId" = 'YOUR_USER_ID';
```

### Проблема: "Error 401: Unauthorized"

**Причина:** Неверный Server Key

**Решение:**
1. Firebase Console → Project settings → Cloud Messaging
2. Скопируйте **Server key** заново
3. Обновите `firebase_config.json` или используйте новый HTTP v1 API

---

## 📋 Чек-лист финальной проверки

### Android приложение:
- [ ] `google-services.json` в `android/app/`
- [ ] `apply plugin: 'com.google.gms.google-services'` в build.gradle
- [ ] Приложение собирается без ошибок
- [ ] FCM токен появляется в логах после входа

### Бэкенд:
- [ ] `firebase_config.json` на сервере
- [ ] Firebase инициализирован (проверка `/health`)
- [ ] `FirebaseService.IsInitialized == true`

### Firebase Console:
- [ ] Android app зарегистрирован с правильным package name
- [ ] Cloud Messaging API включен
- [ ] Service Account ключ создан и скачан

### Тестирование:
- [ ] Тестовое уведомление из Firebase Console работает
- [ ] Push-уведомление при новом сообщении приходит
- [ ] Tap на уведомление открывает чат

---

## 🎯 Что дальше?

### Рекомендации по production:

1. **Безопасность:**
   - Не коммитьте `google-services.json` в Git
   - Не коммитьте `firebase_config.json` в Git
   - Добавьте в `.gitignore`

2. **Мониторинг:**
   - Настройте Firebase Analytics
   - Включите Crashlytics для отслеживания ошибок

3. **Оптимизация:**
   - Настройте Firebase Performance Monitoring
   - Используйте Topics для группового таргетинга

4. **Масштабирование:**
   - Переключитесь на HTTP v1 API (более гибкий)
   - Настройте rate limiting для FCM запросов

---

## 📚 Полезные ссылки

- Firebase Console: https://console.firebase.google.com/
- Firebase Documentation: https://firebase.google.com/docs
- React Native Firebase: https://rnfirebase.io/
- FCM HTTP v1 API: https://firebase.google.com/docs/cloud-messaging/migrate-v1

---

**Дата создания:** 19 декабря 2025  
**Версия:** 1.0  
**Проект:** Депеша (May Messenger)

**Готово! Следуйте инструкции шаг за шагом и Firebase будет работать! 🔥🚀**

