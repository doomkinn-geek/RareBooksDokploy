# May Messenger - React Native

Улучшенная версия мессенджера на React Native с TypeScript, Redux Toolkit и современным UI.

## Особенности

✨ **Современный UI/UX** - Material Design 3 с React Native Paper  
🚀 **Оптимизированная производительность** - FlatList виртуализация, мемоизация  
📱 **Поддержка Android + iOS** - Кросс-платформенное приложение  
🔒 **TypeScript** - Полная типобезопасность  
🖼️ **Медиа сообщения** - Текст, аудио, изображения (частичная реализация)  
📡 **Real-time** - SignalR для мгновенных обновлений  
🔔 **Push-уведомления** - Firebase Cloud Messaging (требует настройки)  
⚡ **Offline режим** - Redux persist, очередь отправки

## Установка

### Требования

- Node.js 18+ ✅ (установлено: v22.19.0)
- npm 10+ ✅ (установлено: 10.9.3)
- Android Studio + Android SDK (API 33+)
- JDK 17-20
- Для iOS: macOS + Xcode

### 1. Установка зависимостей

Все зависимости уже установлены. Если нужно переустановить:

```powershell
npm install --legacy-peer-deps
```

### 2. Настройка Android окружения

#### Установить JDK

1. Скачать JDK 17: https://adoptium.net/
2. Установить и добавить в PATH

#### Настроить ANDROID_HOME

1. Открыть Android Studio
2. SDK Manager → Android SDK
3. Установить SDK Platform 33 (API 33)
4. Настроить переменные окружения:

```powershell
# Добавить в системные переменные
ANDROID_HOME = C:\Users\<ваше_имя>\AppData\Local\Android\Sdk
JAVA_HOME = C:\Program Files\Eclipse Adoptium\jdk-17

# Добавить в Path
%ANDROID_HOME%\platform-tools
%ANDROID_HOME%\tools
%ANDROID_HOME%\tools\bin
%JAVA_HOME%\bin
```

#### Создать эмулятор

1. Android Studio → Device Manager
2. Create Device → Pixel 6 (или любой)
3. System Image → API 33 → Download → Finish

### 3. Настройка react-native-vector-icons

```powershell
# Скопировать шрифты для Android
cd android
./gradlew clean
cd ..
```

В `android/app/build.gradle` уже должно быть добавлено (проверьте):

```gradle
project.ext.vectoricons = [
    iconFontNames: [ 'MaterialCommunityIcons.ttf' ]
]
apply from: "../../node_modules/react-native-vector-icons/fonts.gradle"
```

### 4. Настройка React Native Reanimated

В `babel.config.js` добавить (проверьте):

```javascript
module.exports = {
  presets: ['module:metro-react-native-babel-preset'],
  plugins: ['react-native-reanimated/plugin'],
};
```

## Запуск приложения

### Запуск Metro Bundler

```powershell
npm start
```

### Запуск на Android

В отдельном терминале:

```powershell
# Запустить эмулятор через Android Studio или
npm run android
```

### Запуск на iOS (только macOS)

```bash
cd ios
pod install
cd ..
npm run ios
```

## Структура проекта

```
src/
├── api/              # REST API клиенты (Axios)
│   ├── apiClient.ts  # Базовый HTTP клиент с interceptors
│   ├── authApi.ts    # Аутентификация
│   ├── chatsApi.ts   # Чаты
│   └── messagesApi.ts # Сообщения
├── components/       # Переиспользуемые компоненты
│   ├── AudioRecorder.tsx
│   └── ImagePicker.tsx
├── navigation/       # React Navigation
│   ├── RootNavigator.tsx  # Главный навигатор
│   └── MainNavigator.tsx  # Tabs навигатор
├── screens/          # Экраны
│   ├── AuthScreen.tsx        # Вход/Регистрация
│   ├── ChatsListScreen.tsx   # Список чатов
│   ├── ChatScreen.tsx        # Экран чата
│   ├── NewChatScreen.tsx     # Создание чата
│   └── SettingsScreen.tsx    # Настройки
├── services/         # Сервисы
│   ├── signalrService.ts # SignalR real-time
│   └── signalrHook.ts    # SignalR React hook
├── store/            # Redux Toolkit
│   ├── index.ts      # Store configuration
│   └── slices/       # Redux slices
│       ├── authSlice.ts
│       ├── chatsSlice.ts
│       ├── messagesSlice.ts
│       ├── signalrSlice.ts
│       └── offlineSlice.ts
├── theme/            # Material Design тема
│   └── index.ts
├── types/            # TypeScript типы
│   └── index.ts      # Все типы приложения
└── utils/            # Утилиты
    ├── constants.ts  # API endpoints, конфиги
    └── helpers.ts    # Вспомогательные функции

App.tsx              # Точка входа
```

## API конфигурация

Файл: `src/utils/constants.ts`

```typescript
export const API_CONFIG = {
  BASE_URL: 'https://messenger.rare-books.ru',
  API_URL: 'https://messenger.rare-books.ru/api',
  HUB_URL: 'https://messenger.rare-books.ru/hubs/chat',
};

// Для локальной разработки раскомментируйте:
// export const API_CONFIG = {
//   BASE_URL: 'http://10.0.2.2:5279',  // Android emulator
//   API_URL: 'http://10.0.2.2:5279/api',
//   HUB_URL: 'http://10.0.2.2:5279/hubs/chat',
// };
```

**Важно для Android эмулятора:**
- `localhost` → `10.0.2.2`
- `127.0.0.1` → `10.0.2.2`

## Исправленные проблемы Flutter-версии

### ✅ Дублирование сообщений
- Централизованная дедупликация в Redux middleware
- 5 уровней проверки: ID, localId, content+time, filePath, localPath

### ✅ Превью чата
- Автоматическое обновление в `chatsSlice.reducer`
- Обновление при отправке, получении и подтверждении сообщений

### ✅ Производительность
- FlatList с виртуализацией (`windowSize={10}`)
- React.memo для компонентов
- Debounce для typing indicators

### ✅ SignalR reconnect
- Автоматический reconnect с exponential backoff
- Восстановление подписок после переподключения

## Текущий статус

### ✅ Реализовано
- ✅ Аутентификация (Login, Register)
- ✅ Список чатов с preview
- ✅ Экран чата с текстовыми сообщениями
- ✅ SignalR real-time обновления
- ✅ Redux Toolkit state management
- ✅ React Navigation
- ✅ Material Design 3 UI
- ✅ TypeScript типобезопасность
- ✅ API клиенты (Axios)
- ✅ Оптимистичные обновления

### 🚧 В разработке
- 🚧 Аудио сообщения (stub реализация)
- 🚧 Изображения (stub реализация)
- 🚧 Firebase Push notifications
- 🚧 SQLite offline cache
- 🚧 Анимации (Reanimated)

## Тестирование

### Проверка TypeScript

```powershell
npx tsc --noEmit
```

### Проверка линтера

```powershell
npm run lint
```

### Проверка окружения

```powershell
npx react-native doctor
```

## Troubleshooting

### Metro Bundler не запускается

```powershell
npx react-native start --reset-cache
```

### Gradle build ошибки

```powershell
cd android
./gradlew clean
cd ..
```

### Не находит зависимости

```powershell
rm -rf node_modules
rm package-lock.json
npm install --legacy-peer-deps
```

### Android emulator не подключается

1. Проверить эмулятор запущен
2. `adb devices` - должен показать устройство
3. `adb reverse tcp:8081 tcp:8081` - для Metro

## Следующие шаги

1. **Завершить аудио** - интегрировать react-native-audio-recorder-player
2. **Завершить изображения** - интегрировать react-native-image-picker + Fast Image
3. **Настроить FCM** - добавить google-services.json, firebase config
4. **Добавить SQLite** - кэш сообщений для offline
5. **Анимации** - использовать Reanimated для плавных переходов
6. **Unit тесты** - Jest + React Native Testing Library

## Полезные команды

```powershell
# Запуск Metro
npm start

# Сборка Android
npm run android

# Проверка TypeScript
npx tsc --noEmit

# Очистка кэша
npm start -- --reset-cache

# Проверка окружения
npx react-native doctor

# Список эмуляторов
emulator -list-avds

# Запуск эмулятора
emulator -avd Pixel_6_API_33
```

## Документация

- [React Native](https://reactnative.dev/)
- [React Navigation](https://reactnavigation.org/)
- [Redux Toolkit](https://redux-toolkit.js.org/)
- [React Native Paper](https://callstack.github.io/react-native-paper/)
- [SignalR для JavaScript](https://learn.microsoft.com/en-us/aspnet/core/signalr/javascript-client)

## Лицензия

MIT

## Автор

May Messenger Team
