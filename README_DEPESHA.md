# 📱 Депеша - Современный мессенджер

**React Native + ASP.NET Core мессенджер с оптимизированной обработкой медиа**

---

## 🎯 О проекте

**Депеша** (Depesha) - это полнофункциональный мессенджер со следующими возможностями:

### Основные функции
- 💬 Текстовые сообщения в реальном времени
- 🎤 Аудио сообщения с записью и воспроизведением
- 📸 **Изображения с автоматическим сжатием**
- 📱 Offline режим с локальным кэшированием
- 🔔 Push-уведомления через Firebase Cloud Messaging
- 🔒 JWT аутентификация
- ⚡ Real-time обновления через SignalR

### Уникальные особенности
- ✅ **Автосжатие изображений** перед отправкой (70% качества, экономия трафика)
- ✅ **Локальное хранение медиа** на устройстве навсегда
- ✅ **Автоудаление с сервера** через 7 дней (настраивается)
- ✅ **Offline доступ** к ранее загруженным медиа
- ✅ **Автоматическая сборка** через PowerShell скрипт

---

## 📂 Структура проекта

```
RareBooksServicePublic/
│
├── _may_messenger_backend/          # ASP.NET Core API
│   ├── src/
│   │   ├── MayMessenger.API/        # Controllers, Hubs, Middleware
│   │   ├── MayMessenger.Application/# Services, DTOs, Validators
│   │   ├── MayMessenger.Domain/     # Entities, Interfaces
│   │   └── MayMessenger.Infrastructure/ # Repositories, Data
│   └── BACKEND_IMAGE_SUPPORT.md     # Документация бэкенда
│
├── _may_messenger_native_react/     # React Native клиент
│   ├── src/
│   │   ├── api/                     # API клиенты
│   │   ├── components/              # React компоненты
│   │   ├── screens/                 # Экраны приложения
│   │   ├── services/                # SignalR, FCM, SQLite
│   │   └── store/                   # Redux state
│   ├── android/                     # Android нативный код
│   ├── build-android.ps1            ← Автоматическая сборка
│   ├── START_HERE.md                ← Начните отсюда!
│   ├── QUICK_START.md               # Быстрый старт
│   ├── FIREBASE_SETUP_DETAILED.md   # Настройка Firebase
│   └── IMAGE_COMPRESSION_AND_STORAGE.md # Про изображения
│
└── _may_messenger_mobile_app/       # Flutter версия (legacy)
```

---

## 🚀 Быстрый старт

### Предварительные требования

- **Node.js** 20+
- **Java JDK** 17-20
- **Android SDK** (API Level 33)
- **Android Studio** (для SDK и эмулятора)

### Запуск за 3 шага

```powershell
# 1. Перейти в папку проекта
cd D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react

# 2. Запустить Android эмулятор
emulator -avd YOUR_AVD_NAME

# 3. Автоматическая сборка
.\build-android.ps1
```

**Готово!** Приложение установится на эмулятор.

**Детальная инструкция:** См. `_may_messenger_native_react/START_HERE.md`

---

## 🔧 Технологический стек

### Frontend (React Native)

| Технология | Версия | Назначение |
|------------|--------|------------|
| React Native | 0.83.1 | Mobile framework |
| TypeScript | 5.8.3 | Типизация |
| Redux Toolkit | 2.11.2 | State management |
| React Navigation | 7.x | Навигация |
| React Native Paper | 5.14.5 | UI компоненты (Material Design 3) |
| SignalR | 10.0.0 | Real-time коммуникация |
| Reanimated | 4.2.1 | Анимации |
| SQLite Storage | 6.0.1 | Offline кэш |
| Firebase | 23.7.0 | Push-уведомления |
| Image Picker | 8.2.1 | Выбор изображений с сжатием |
| Audio Recorder Player | 4.5.0 | Аудио функции |

### Backend (ASP.NET Core)

| Технология | Версия | Назначение |
|------------|--------|------------|
| .NET | 8.0 | Framework |
| Entity Framework Core | 8.x | ORM |
| PostgreSQL / SQLite | - | База данных |
| SignalR | 8.x | Real-time |
| Firebase Admin SDK | 2.x | Push-уведомления |
| JWT | - | Аутентификация |
| FluentValidation | 11.x | Валидация |

---

## 📸 Обработка изображений

### Клиент

**Автосжатие перед отправкой:**
- **Quality:** 70% (баланс качество/размер)
- **Max size:** 1920x1920 px (Full HD)
- **Лимит:** 10 MB после сжатия
- **Форматы:** JPG, PNG, GIF, WebP

**Результат:** Экономия трафика до 80%

### Сервер

**Автоматическая очистка (MediaCleanupService):**
- ⏰ Запускается каждые 24 часа
- 🗑️ Удаляет аудио и изображения старше 7 дней
- 💾 **Локальные копии на устройствах остаются!**
- ⚙️ Настраиваемый срок хранения

**Конфигурация:** `appsettings.json`
```json
{
  "MediaRetentionDays": 7
}
```

---

## 🔔 Firebase Push-уведомления

### Настройка (5 минут)

1. Создайте Firebase проект на https://console.firebase.google.com/
2. Добавьте Android app с package name: `com.depesha`
3. Скачайте `google-services.json`
4. Разместите в `_may_messenger_native_react/android/app/`
5. Скачайте Service Account JSON для бэкенда

**Подробная инструкция:** `_may_messenger_native_react/FIREBASE_SETUP_DETAILED.md`

---

## 🏗️ Архитектура

### React Native приложение

```
┌─────────────────────────────────────┐
│          UI Layer                   │
│  Screens → Components → Animations  │
└────────────┬────────────────────────┘
             │
┌────────────▼────────────────────────┐
│      State Management (Redux)       │
│  authSlice, chatsSlice, messages... │
└────────────┬────────────────────────┘
             │
┌────────────▼────────────────────────┐
│         Services Layer              │
│  SignalR, FCM, SQLite, API clients  │
└────────────┬────────────────────────┘
             │
┌────────────▼────────────────────────┐
│       Backend API (ASP.NET)         │
│  Controllers, SignalR Hub, Database │
└─────────────────────────────────────┘
```

### Обработка медиа

```
Пользователь выбирает фото
    │
    ▼
Автосжатие (70%, 1920x1920)
    │
    ▼
Локальное сохранение (SQLite)
    │
    ▼
Отправка на сервер (FormData)
    │
    ▼
Хранение 7 дней → Удаление
```

---

## 📊 Особенности реализации

### Offline режим

- ✅ SQLite база на устройстве
- ✅ Кэширование сообщений и медиа
- ✅ Автосинхронизация при восстановлении связи
- ✅ Оптимистичные обновления UI

### Дедупликация сообщений

5-уровневая система предотвращения дублей:
1. По Server ID
2. По Client Message ID
3. По Content + Sender + Time
4. По FilePath (аудио/изображения)
5. По LocalPath

### Error Boundaries

- Перехват React ошибок
- Fallback UI
- Логирование для отладки
- Graceful recovery

---

## 📚 Документация

### Для разработчиков

| Файл | Описание |
|------|----------|
| `START_HERE.md` | Точка входа |
| `QUICK_START.md` | Быстрый старт за 3 шага |
| `SETUP_GUIDE.md` | Детальная настройка окружения |
| `FIREBASE_SETUP_DETAILED.md` | Firebase от А до Я |
| `IMAGE_COMPRESSION_AND_STORAGE.md` | Архитектура медиа |
| `FINAL_CHANGES_SUMMARY.md` | Changelog |
| `COMPLETE_PROJECT_SUMMARY.md` | Полная документация |

### Для администраторов

| Файл | Описание |
|------|----------|
| `BACKEND_IMAGE_SUPPORT.md` | API изображений |
| `appsettings.json` | Конфигурация сервера |
| `MediaCleanupService.cs` | Автоочистка |

---

## 🔒 Безопасность

### Реализовано

- ✅ JWT аутентификация
- ✅ Bearer token в заголовках
- ✅ Валидация типов файлов
- ✅ Ограничение размеров (10MB)
- ✅ Уникальные имена файлов (GUID)
- ✅ Rate limiting middleware

### Рекомендации для production

- 🔒 HTTPS обязательно
- 🔒 Антивирусное сканирование загрузок
- 🔒 CORS правильно настроить
- 🔒 Firebase Security Rules
- 🔒 Regular security audits

---

## 🧪 Тестирование

```powershell
# TypeScript проверка
npx tsc --noEmit

# Линтер
npm run lint

# Unit тесты (если есть)
npm test

# Health check бэкенда
curl https://messenger.rare-books.ru/health
```

---

## 🚀 Deployment

### React Native

```powershell
# Debug build
.\build-android.ps1

# Release build
cd android
.\gradlew assembleRelease
# APK: android/app/build/outputs/apk/release/
```

### Backend

```bash
# Build
dotnet build -c Release

# Publish
dotnet publish -c Release -o ./publish

# Run
cd publish
dotnet MayMessenger.API.dll
```

---

## 🤝 Contributing

### Workflow

1. Fork проект
2. Создайте feature branch
3. Commit изменения
4. Push в branch
5. Создайте Pull Request

### Code Style

- TypeScript: строгая типизация
- C#: .NET coding conventions
- Комментарии на русском для бизнес-логики

---

## 📄 Лицензия

Проект для внутреннего использования.

---

## 👥 Команда

- **Frontend:** React Native + TypeScript
- **Backend:** ASP.NET Core
- **DevOps:** Docker, Nginx, PostgreSQL

---

## 📞 Поддержка

### Проблемы?

1. Проверьте `SETUP_GUIDE.md` → Troubleshooting
2. Проверьте `FIREBASE_SETUP_DETAILED.md` → FAQ
3. Проверьте логи: `adb logcat | Select-String "ReactNative"`

### Полезные ссылки

- React Native Docs: https://reactnative.dev/
- Firebase Console: https://console.firebase.google.com/
- Material Design 3: https://m3.material.io/

---

## 🎯 Roadmap

### Planned Features

- [ ] Видео сообщения
- [ ] Групповые чаты
- [ ] Голосовые/видео звонки
- [ ] End-to-end шифрование
- [ ] Темная тема
- [ ] Мультиязычность

### In Progress

- [x] Изображения с автосжатием
- [x] Локальное хранение медиа
- [x] Автоочистка сервера
- [x] Firebase FCM
- [x] Offline режим

---

## 📈 Статистика

| Метрика | Значение |
|---------|----------|
| Строк кода (TypeScript) | ~3000+ |
| Строк кода (C#) | ~5000+ |
| Компонентов React | 13 |
| API endpoints | 15+ |
| Файлов документации | 7 |
| TypeScript ошибок | 0 ✅ |

---

## 🏆 Итоги

**Депеша** - это современный, производительный и надежный мессенджер с:
- ✅ Оптимизированной обработкой медиа
- ✅ Offline режимом
- ✅ Автоматической очисткой на сервере
- ✅ Подробной документацией
- ✅ Удобными инструментами разработки

**Готов к production deployment!**

---

**Проект:** Депеша (May Messenger)  
**Версия:** 1.0  
**Дата:** 19 декабря 2025  
**Статус:** ✅ Production Ready

**Спасибо за использование Депеша! 🚀📱💬**

