---
name: React Native Улучшения
overview: "Комплексное улучшение React Native приложения: реализация отправки сообщений (текст/аудио/фото), работа с контактами, QR-коды, push-уведомления, статусы сообщений и UI улучшения"
todos:
  - id: text-messages
    content: Доработать отправку текстовых сообщений (иконки, индикаторы)
    status: completed
  - id: replace-audio
    content: Заменить react-native-audio-recorder-player на expo-av
    status: completed
  - id: audio-messages
    content: Реализовать запись и отправку аудио сообщений
    status: completed
  - id: image-messages
    content: Реализовать захват, сжатие и отправку изображений
    status: completed
  - id: message-statuses
    content: Добавить отображение и обновление статусов сообщений
    status: completed
  - id: contacts-integration
    content: Интегрировать телефонную книгу (имена, выбор контактов)
    status: completed
  - id: qr-codes
    content: Реализовать QR-коды (сканирование и генерация)
    status: completed
  - id: push-notifications
    content: Настроить push-уведомления Firebase
    status: completed
  - id: ui-improvements
    content: Добавить иконки, аватары и улучшить UI
    status: completed
  - id: final-build
    content: Собрать финальный standalone APK
    status: completed
---

# План улучшения React Native приложения

## 1. Отправка сообщений (ПРИОРИТЕТ)

### 1.1 Текстовые сообщения

**Текущее состояние:** Частично реализовано в [`src/screens/ChatScreen.tsx`](src/screens/ChatScreen.tsx) и [`src/store/slices/messagesSlice.ts`](src/store/slices/messagesSlice.ts)**Что доработать:**

- Добавить иконку отправки вместо текстовой кнопки
- Реализовать видимость индикатора отправки
- Добавить обработку ошибок с повтором отправки

**Референс:** Flutter [`lib/presentation/providers/messages_provider.dart`](lib/presentation/providers/messages_provider.dart) строки 289-378

### 1.2 Аудио сообщения

**Текущее состояние:** Компоненты созданы ([`src/components/AudioRecorder.tsx`](src/components/AudioRecorder.tsx)), но НЕ интегрированы в ChatScreen**План действий:**

1. **Заменить библиотеку:** Удалить `react-native-audio-recorder-player`, установить `expo-av`
   ```bash
                  npm uninstall react-native-audio-recorder-player
                  npm install expo-av --legacy-peer-deps
                  npx expo install expo-av
   ```




2. **Создать новый компонент:** `src/components/AudioRecorderExpo.tsx`

- Запись аудио через `Audio.Recording` из expo-av
- Формат: AAC, битрейт 128kbps
- Референс: Flutter использует `AudioRecorder` с `AudioEncoder.aacLc`

3. **Интегрировать в ChatScreen:**

- Добавить кнопку микрофона в input container
- Долгое нажатие = запись, отпустить = отправить
- Свайп влево = отменить

4. **API для отправки:**

- Создать `messagesApi.sendAudioMessage(token, chatId, audioFile)`
- Использовать FormData с multipart/form-data
- Endpoint: `POST /api/messages/audio`
- Референс: Flutter [`lib/data/datasources/api_datasource.dart`](lib/data/datasources/api_datasource.dart) строки 158-176

### 1.3 Отправка изображений

**Текущее состояние:** Компонент `ImagePicker` существует, но НЕ интегрирован**План действий:**

1. **Установить библиотеки:**
   ```bash
                  npm install react-native-image-picker --legacy-peer-deps
                  npm install react-native-image-resizer --legacy-peer-deps
   ```




2. **Создать `src/services/imageService.ts`:**

- Функция `capturePhoto()` - камера
- Функция `pickPhoto()` - галерея
- Функция `compressImage(uri)` - сжатие до max 1920px, quality 0.8

3. **Интегрировать в ChatScreen:**

- Добавить кнопку скрепки/камеры
- Показать модальное окно: "Камера" | "Галерея"
- После выбора - сжать и отправить

4. **API для отправки:**

- `messagesApi.sendImageMessage(token, chatId, imageFile)`
- FormData multipart/form-data
- Endpoint: `POST /api/messages/image` (нужно будет создать на backend)

## 2. Работа с контактами телефонной книги

### 2.1 Отображение имен из телефонной книги

**Референс:** Flutter [`lib/presentation/providers/contacts_names_provider.dart`](lib/presentation/providers/contacts_names_provider.dart)**План:**

1. **Установить библиотеку:**
   ```bash
                  npm install react-native-contacts --legacy-peer-deps
                  npx pod-install
   ```




2. **Создать `src/services/contactsService.ts`:**

- `requestPermission()` - запрос разрешения
- `getAllContacts()` - получить все контакты
- `syncContactsWithServer(token)` - отправить хэши на сервер
- `buildContactsMapping(registeredUsers)` - userId → displayName

3. **Создать Redux slice `src/store/slices/contactsSlice.ts`:**

- State: `{ mapping: { [userId: string]: string } }`
- Thunk: `syncContacts(token)`
- Selector: `selectContactName(userId)`

4. **Интегрировать:**

- В `ChatsListScreen`: показывать имена из mapping
- В `ChatScreen`: показывать имена отправителей из mapping
- Вызвать `syncContacts()` после логина

### 2.2 Выбор контактов при создании чата

**Референс:** Flutter [`lib/presentation/screens/new_chat_screen.dart`](lib/presentation/screens/new_chat_screen.dart)**План:**

1. **Обновить `NewChatScreen`:**

- Показать список зарегистрированных контактов из телефонной книги
- Фильтрация по имени
- При клике - создать чат через `POST /api/chats/create-or-get`

2. **UI компоненты:**

- Search bar вверху
- FlatList с аватарами (первая буква имени)
- Индикатор загрузки при синхронизации

## 3. QR коды для приглашений

### 3.1 Сканирование QR кода (Auth Screen)

**Референс:** Flutter [`lib/presentation/screens/auth_screen.dart`](lib/presentation/screens/auth_screen.dart) строки 39-82**План:**

1. **Установить библиотеку:**
   ```bash
                  npm install react-native-camera --legacy-peer-deps
   ```




2. **Обновить `AuthScreen`:**

- Добавить иконку QR Scanner рядом с полем invite code
- При клике - показать полноэкранный сканер
- Парсить URL `maymessenger://invite?code=XXXXX`
- Автоматически заполнить поле invite code

### 3.2 Генерация и отображение QR кода (Settings)

**Референс:** Flutter [`lib/presentation/widgets/qr_invite_dialog.dart`](lib/presentation/widgets/qr_invite_dialog.dart)**План:**

1. **Установить библиотеку:**
   ```bash
                  npm install react-native-qrcode-svg --legacy-peer-deps
   ```




2. **Создать `src/components/QRInviteDialog.tsx`:**

- Показать QR код с `maymessenger://invite?code=${inviteCode}`
- Кнопка "Копировать код"
- Кнопка "Поделиться" (Share API)

3. **Обновить `SettingsScreen`:**

- Добавить пункт "Пригласить друга"
- При клике - создать invite code через API
- Показать QRInviteDialog

4. **API:**

- `POST /api/invite/create` → возвращает `{ code, expiresAt }`

## 4. Push-уведомления Firebase

### 4.1 Регистрация FCM токена

**Референс:** Flutter [`lib/core/services/fcm_service.dart`](lib/core/services/fcm_service.dart)**План:**

1. **Проверить конфигурацию:**

- Firebase уже настроен (google-services.json существует)
- Пакет `@react-native-firebase/messaging` установлен

2. **Создать `src/services/fcmService.ts`:**

- `requestPermission()` - запрос разрешения
- `getToken()` - получить FCM токен
- `registerToken(token, jwtToken)` - отправить на сервер
- Endpoint: `POST /api/notifications/register-token`

3. **Обработка уведомлений:**

- Foreground: показать локальное уведомление
- Background/Quit: обработать через Firebase onBackgroundMessage
- OnTap: открыть соответствующий чат

4. **Интеграция:**

- Вызвать `registerToken()` после успешного логина
- Подписаться на `onTokenRefresh`

### 4.2 Локальные уведомления

**План:**

1. **Установить:**
   ```bash
                  npm install @notifee/react-native --legacy-peer-deps
   ```




2. **Создать канал для Android:**

- Channel ID: `messages_channel`
- Importance: HIGH
- Звук, вибрация

## 5. Статусы сообщений (отправлено/доставлено/прочитано)

### 5.1 Отображение статусов

**Референс:** Flutter [`lib/presentation/widgets/message_bubble.dart`](lib/presentation/widgets/message_bubble.dart) строки 162-195**План:**

1. **Обновить `AnimatedMessageBubble.tsx`:**

- Добавить функцию `renderStatusIcon(status)`
- Sending: `<ActivityIndicator size="small" />`
- Sent: `<Icon name="check" />` (1 галочка серая)
- Delivered: `<Icon name="check-all" />` (2 галочки серые)
- Read: `<Icon name="check-all" color="green" />` (2 галочки зеленые)
- Failed: `<Icon name="alert-circle" color="red" />`

2. **Показывать только для своих сообщений**

### 5.2 Обновление статусов через SignalR

**Референс:** Flutter [`lib/data/datasources/signalr_service.dart`](lib/data/datasources/signalr_service.dart)**План:**

1. **Обновить `src/services/signalrService.ts`:**

- Подписаться на событие `"MessageStatusChanged"`
- Payload: `{ messageId, status }`
- Dispatch `updateMessageStatus({ messageId, status })`

2. **Отправка статуса "прочитано":**

- При открытии ChatScreen - отметить все сообщения как прочитанные
- SignalR: `connection.invoke("MarkAsRead", messageId, chatId)`
- REST fallback: `POST /api/messages/mark-read` с массивом ID

## 6. UI улучшения

### 6.1 Иконки и изображения

**План:**

1. **Установить иконки:**

- Уже установлен `react-native-vector-icons`
- Добавить иконки в navigation tabs, кнопки отправки

2. **Аватары пользователей:**

- Показывать первую букву displayName
- Цвет фона = hash(userId) % 10 предустановленных цветов
- Компонент: `src/components/Avatar.tsx`

3. **Превью чатов:**

- Показать аватар собеседника слева
- Последнее сообщение (текст или "🎤 Аудио" или "📷 Фото")
- Время последнего сообщения
- Badge с непрочитанными

### 6.2 Обновить компоненты

**Файлы для обновления:**

- [`src/screens/ChatsListScreen.tsx`](src/screens/ChatsListScreen.tsx) - добавить аватары
- [`src/screens/ChatScreen.tsx`](src/screens/ChatScreen.tsx) - добавить кнопки аудио/фото
- [`src/navigation/MainNavigator.tsx`](src/navigation/MainNavigator.tsx) - иконки в tabs

## 7. Обновление build.gradle

**Цель:** Исправить проблему сборки Release APK с react-native-audio-recorder-player**План:**

1. После замены на expo-av, удалить старые записи из `android/app/build.gradle`
2. Очистить кэш: `cd android && ./gradlew clean`
3. Пересобрать: `./gradlew assembleRelease`

## Последовательность реализации

### Этап 1: Отправка сообщений (критично)

1. Доработать текстовые сообщения + иконки
2. Заменить audio библиотеку на expo-av
3. Реализовать аудио запись и отправку
4. Реализовать отправку фото с сжатием

### Этап 2: UI и статусы

5. Добавить аватары и иконки
6. Реализовать отображение статусов сообщений
7. Обновить статусы через SignalR

### Этап 3: Контакты и QR

8. Интеграция с телефонной книгой
9. Выбор контактов при создании чата
10. QR-коды (сканирование и генерация)

### Этап 4: Push-уведомления

11. Регистрация FCM токена
12. Обработка foreground/background уведомлений

### Этап 5: Финальная сборка

13. Собрать финальный APK
14. Тестирование на реальном устройстве

## Зависимости для установки

```bash
# Audio (замена)
npm uninstall react-native-audio-recorder-player
npm install expo-av --legacy-peer-deps

# Images
npm install react-native-image-picker react-native-image-resizer --legacy-peer-deps

# Contacts
npm install react-native-contacts --legacy-peer-deps

# QR
npm install react-native-camera react-native-qrcode-svg --legacy-peer-deps

# Notifications
npm install @notifee/react-native --legacy-peer-deps
```



## Ключевые файлы для создания/изменения

**Новые файлы:**

- `src/components/AudioRecorderExpo.tsx`
- `src/components/Avatar.tsx`
- `src/components/QRInviteDialog.tsx`
- `src/components/QRScanner.tsx`
- `src/services/contactsService.ts`
- `src/services/imageService.ts`
- `src/services/fcmService.ts`
- `src/store/slices/contactsSlice.ts`

**Изменить:**

- `src/screens/ChatScreen.tsx` - добавить аудио/фото кнопки
- `src/screens/AuthScreen.tsx` - добавить QR Scanner