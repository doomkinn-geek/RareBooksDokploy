---
name: Telegram-style Redesign
overview: Полная переработка дизайна приложения May Messenger в стиле Telegram с светло-зеленой цветовой схемой, поддержкой светлой и темной тем, и паттерновым фоном чата.
todos:
  - id: theme-system
    content: Create AppColors constants and update AppTheme with green color scheme for both themes
    status: completed
  - id: chat-background
    content: Create ChatBackground widget with Telegram-style pattern
    status: completed
  - id: message-bubble
    content: Redesign MessageBubble with Telegram-style bubbles (tails, shadows, colors)
    status: completed
  - id: chat-list
    content: Update ChatListItem with larger avatars, unread badges, better layout
    status: completed
  - id: message-input
    content: Redesign MessageInput with rounded field and green send button
    status: completed
  - id: main-screen
    content: Update MainScreen AppBar and FAB with green theme
    status: completed
  - id: chat-screen
    content: Update ChatScreen with green AppBar and chat background pattern
    status: completed
  - id: theme-switcher
    content: Add theme switcher to SettingsScreen with persistence
    status: completed
  - id: other-screens
    content: Update remaining screens (auth, new_chat, profile) with green theme
    status: completed
---

# Редизайн May Messenger в стиле Telegram

## Обзор изменений

Переработка всех UI компонентов для создания современного мессенджера в стиле Telegram с фирменной светло-зеленой цветовой схемой.

## 1. Система тем и цветов

**Файл:** [`app_theme.dart`](_may_messenger_mobile_app/lib/core/themes/app_theme.dart)Полная переработка цветовой схемы:

- **Primary color:** Светло-зеленый (#4CAF50 / #66BB6A)
- **Исходящие сообщения:** Зеленый (#DCF8C6 светлая / #056162 темная)
- **Входящие сообщения:** Белый (#FFFFFF светлая / #1E2C34 темная)
- **AppBar:** Зеленый (#128C7E стиль Telegram)
- **Фон списка чатов:** Белый/темно-серый
- **Акцентные элементы:** Teal (#009688)

Новые константы:

```dart
class AppColors {
  // Telegram-style green palette
  static const primaryGreen = Color(0xFF128C7E);
  static const lightGreen = Color(0xFF25D366);
  static const outgoingBubble = Color(0xFFDCF8C6);
  static const incomingBubble = Color(0xFFFFFFFF);
  // ... dark theme variants
}
```



## 2. Паттерн фона чата

**Новый файл:** `chat_background.dart`Создание виджета с паттерновым фоном в стиле Telegram:

- SVG/CustomPaint паттерн с иконками (конверты, облачка, сердечки)
- Легкий зеленоватый оттенок
- Поддержка обеих тем

## 3. Пузыри сообщений (Telegram-стиль)

**Файл:** [`message_bubble.dart`](_may_messenger_mobile_app/lib/presentation/widgets/message_bubble.dart)Изменения:

- Закругленные углы с "хвостиком" (как в Telegram)
- Зеленые исходящие, белые входящие
- Время сообщения справа внизу с галочками
- Тени для объема
- Стиль цитирования (reply)

## 4. Список чатов

**Файл:** [`chat_list_item.dart`](_may_messenger_mobile_app/lib/presentation/widgets/chat_list_item.dart)

- Увеличенные аватары (56px)
- Жирный заголовок + preview сообщения
- Время справа, счетчик непрочитанных (зеленый кружок)
- Разделители между чатами
- Индикатор онлайн (зеленая точка)

## 5. Поле ввода сообщения

**Файл:** [`message_input.dart`](_may_messenger_mobile_app/lib/presentation/widgets/message_input.dart)

- Закругленное поле ввода
- Иконки attach/emoji слева
- Кнопка отправки/микрофон справа (зеленая)
- Плавающий над клавиатурой

## 6. AppBar и навигация

**Файлы:** [`main_screen.dart`](_may_messenger_mobile_app/lib/presentation/screens/main_screen.dart), [`chat_screen.dart`](_may_messenger_mobile_app/lib/presentation/screens/chat_screen.dart)

- Зеленый AppBar (#128C7E)
- Белый текст и иконки
- Аватар + имя + статус в chat_screen
- FAB для нового чата (зеленый)

## 7. Настройки темы

**Файл:** [`settings_screen.dart`](_may_messenger_mobile_app/lib/presentation/screens/settings_screen.dart)

- Добавить переключатель темы (Светлая/Темная/Системная)
- Сохранение выбора в SharedPreferences

## 8. Прочие экраны

Обновить цветовую схему:

- `auth_screen.dart` - зеленые кнопки, логотип
- `new_chat_screen.dart` - зеленый AppBar
- `create_group_screen.dart` - зеленый AppBar
- `user_profile_screen.dart` - зеленый header

## Схема цветов

```javascript
Светлая тема:
├── AppBar: #128C7E (teal green)
├── Primary: #25D366 (WhatsApp green)
├── Исходящее сообщение: #DCF8C6 (pale green)
├── Входящее сообщение: #FFFFFF
├── Фон чата: паттерн на #ECE5DD
└── Акценты: #128C7E

Темная тема:
├── AppBar: #1F2C34
├── Primary: #00A884 (dark green)
├── Исходящее сообщение: #005C4B
├── Входящее сообщение: #1F2C34
├── Фон чата: паттерн на #0B141A
└── Акценты: #00A884


```