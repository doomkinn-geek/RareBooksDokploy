# PRD: Приведение веб-клиента May Messenger в соответствие с мобильным приложением

## Дата создания
22 декабря 2025

## Версия документа
1.0.0

---

## 1. ОПРЕДЕЛЕНИЕ ОБЛАСТИ И НАМЕРЕНИЙ

### 1.1 Цель проекта
Привести веб-клиент May Messenger (`_may_messenger_web_client`) в полное соответствие с функциональностью и UI/UX мобильного приложения (`_may_messenger_mobile_app`), устранив выявленные несоответствия в отображении сообщений, функциональности компонентов и общей архитектуре.

### 1.2 Основная задача
Реализовать единообразный пользовательский опыт между мобильным и веб-приложением, обеспечив одинаковую функциональность, визуальное представление и поведение компонентов.

### 1.3 Основные результаты

#### 1.3.1 Критические исправления
- Исправление ширины пузырей сообщений для корректного размещения текста
- Реализация динамической ширины контейнеров сообщений
- Улучшение word-wrap и text-overflow для длинных слов

#### 1.3.2 Функциональные дополнения
- Добавление поддержки изображений в сообщениях
- Реализация статусов сообщений (sending, sent, delivered, read, played, failed)
- Реализация функции повторной отправки (retry) для неудавшихся сообщений
- Добавление визуализации состояния "в сети" для участников
- Реализация отображения времени последнего посещения

#### 1.3.3 UI/UX улучшения
- Унификация стилей пузырей сообщений
- Добавление подсветки сообщений (highlight)
- Реализация отображения имени отправителя в групповых чатах
- Улучшение визуального отображения аудио-сообщений
- Реализация индикаторов статуса сообщений

### 1.4 Критерии успеха
- ✅ Веб-клиент визуально идентичен мобильному приложению
- ✅ Все функции мобильного приложения работают в веб-клиенте
- ✅ Пузыри сообщений корректно отображают текст любой длины
- ✅ Реализованы все статусы сообщений
- ✅ Работает retry механизм для неудачных отправок
- ✅ Отображаются изображения в сообщениях
- ✅ Соблюдена единая цветовая схема и типографика

### 1.5 Ограничения и зависимости

#### Ограничения
- Backend API (`_may_messenger_backend`) остаётся без изменений
- Сохранение существующей архитектуры хранилищ (stores) в веб-клиенте
- Совместимость с существующими браузерами (Chrome, Firefox, Safari, Edge - последние 2 версии)

#### Зависимости
- Backend API для получения статусов сообщений
- SignalR для real-time обновлений
- IndexedDB для локального кэширования

### 1.6 Внешние зависимости
- TypeScript 5.x
- React 18.x
- Vite 5.x
- Zustand (state management)
- TailwindCSS 3.x
- SignalR Client
- lucide-react (icons)

---

## 2. СТРУКТУРИРОВАННЫЙ ПЛАН ЗАДАЧ (TODO)

### Фаза 1: Аудит и документирование различий

#### TODO-1.1: Сравнительный анализ компонентов ✓
**Приоритет:** High  
**Оценка трудозатрат:** 2 часа  
**Статус:** Completed

**Входные данные:**
- Исходный код `message_bubble.dart`
- Исходный код `MessageBubble.tsx`
- Исходный код других виджетов мобильного приложения

**Процесс:**
1. Составление списка всех компонентов мобильного приложения
2. Сопоставление с компонентами веб-клиента
3. Документирование различий в функциональности
4. Создание матрицы соответствия

**Ожидаемый результат:**
- Документ с полным списком различий
- Матрица покрытия функциональности
- Приоритизированный список задач

**Критерии приемки:**
- Все компоненты проанализированы
- Различия задокументированы
- Приоритеты расставлены

---

### Фаза 2: Исправление пузырей сообщений

#### TODO-2.1: Исправление ширины и переноса текста в MessageBubble
**Приоритет:** Critical  
**Оценка трудозатрат:** 3 часа  
**Статус:** Pending

**Входные данные:**
- Текущий `MessageBubble.tsx`
- Дизайн из `message_bubble.dart` (строки 545-563)
- Требования к responsive дизайну

**Процесс:**
1. Изменить `max-w-[70%]` на динамическое значение с учётом содержимого
2. Добавить `word-wrap: break-word` и `overflow-wrap: anywhere`
3. Реализовать `min-width` для предотвращения слишком узких пузырей
4. Добавить адаптивность для мобильных устройств (max-width: 85% на малых экранах)
5. Настроить padding для оптимального отображения

**Требуемые инструменты:**
- VSCode с расширениями для TypeScript и React
- Chrome DevTools для тестирования

**Ожидаемый результат:**
```typescript
// Новые стили для MessageBubble
<div
  className={`rounded-2xl px-4 py-2 ${
    isOwnMessage
      ? 'bg-indigo-600 text-white'
      : 'bg-gray-200 text-gray-900'
  }`}
  style={{
    maxWidth: 'min(70%, 500px)',
    minWidth: '80px',
    wordWrap: 'break-word',
    overflowWrap: 'anywhere',
    hyphens: 'auto'
  }}
>
```

**Критерии приемки:**
- Длинные слова корректно переносятся
- Короткие сообщения не растягиваются
- Нет горизонтального overflow
- Визуально идентично мобильному приложению

**Методы верификации:**
- Тестирование с текстами различной длины
- Тестирование с URL и длинными словами
- Проверка на разных размерах экрана

---

#### TODO-2.2: Добавление отображения имени отправителя в пузыре
**Приоритет:** High  
**Оценка трудозатрат:** 1 час  
**Статус:** Pending

**Зависимости:** TODO-2.1

**Входные данные:**
- Обновлённый `MessageBubble.tsx`
- Логика из `message_bubble.dart` (строки 567-577)

**Процесс:**
1. Добавить условное отображение имени отправителя для входящих сообщений
2. Стилизовать имя (жирный шрифт, меньший размер, цвет primary)
3. Добавить отступ между именем и контентом
4. Получить display name из contacts provider или использовать senderName

**Ожидаемый результат:**
```typescript
{!isOwnMessage && (
  <div className="text-xs font-semibold mb-1 text-indigo-600">
    {message.senderName || 'Пользователь'}
  </div>
)}
```

**Критерии приемки:**
- Имя отображается только для входящих сообщений
- Стили соответствуют мобильному приложению
- Имя получается из правильного источника

---

#### TODO-2.3: Реализация подсветки сообщений (highlight)
**Приоритет:** Medium  
**Оценка трудозатрат:** 2 часа  
**Статус:** Pending

**Зависимости:** TODO-2.1

**Входные данные:**
- Логика из `message_bubble.dart` (строка 549, 557-558)
- Требования к анимации

**Процесс:**
1. Добавить prop `isHighlighted` в `MessageBubble`
2. Реализовать условный стиль с жёлтым фоном
3. Добавить плавную анимацию появления/исчезновения
4. Реализовать auto-dismiss через 3 секунды
5. Добавить прокрутку к выделенному сообщению

**Требуемые инструменты:**
- React hooks (useState, useEffect)
- TailwindCSS transitions

**Ожидаемый результат:**
```typescript
<div
  className={`transition-all duration-300 ${
    isHighlighted ? 'bg-yellow-100' : ''
  }`}
>
```

**Критерии приемки:**
- Подсветка применяется к нужному сообщению
- Плавная анимация появления и исчезновения
- Auto-dismiss работает корректно
- Прокрутка к сообщению выполняется плавно

---

### Фаза 3: Реализация статусов сообщений

#### TODO-3.1: Добавление всех статусов сообщений в типы
**Приоритет:** High  
**Оценка трудозатрат:** 1 час  
**Статус:** Pending

**Входные данные:**
- `src/types/message.ts`
- Enum из backend: `Sending, Sent, Delivered, Read, Played, Failed`

**Процесс:**
1. Обновить `MessageStatus` enum в `src/types/message.ts`
2. Добавить недостающие статусы: `Played`
3. Убедиться в соответствии с backend enum
4. Обновить интерфейс `Message`

**Ожидаемый результат:**
```typescript
export enum MessageStatus {
  Sending = 0,
  Sent = 1,
  Delivered = 2,
  Read = 3,
  Played = 4,  // NEW
  Failed = 5
}
```

**Критерии приемки:**
- Enum полностью соответствует backend
- TypeScript компилируется без ошибок
- Нет breaking changes в существующем коде

---

#### TODO-3.2: Реализация визуализации статусов сообщений
**Приоритет:** High  
**Оценка трудозатрат:** 3 часа  
**Статус:** Pending

**Зависимости:** TODO-3.1

**Входные данные:**
- Логика из `message_bubble.dart` (строки 189-253)
- Иконки из lucide-react
- Обновлённые типы

**Процесс:**
1. Создать функцию `renderStatusIcon()` в `MessageBubble.tsx`
2. Реализовать отображение для каждого статуса:
   - Sending: Clock с анимацией pulse
   - Sent: одна галочка (Check)
   - Delivered: две серые галочки (CheckCheck)
   - Read: две зелёные галочки (CheckCheck)
   - Played: синяя иконка динамика (Volume2)
   - Failed: красная иконка ошибки (AlertCircle) с кнопкой Retry
3. Применить соответствующие цвета и размеры
4. Добавить позиционирование рядом с временем

**Требуемые инструменты:**
- lucide-react icons: `Check, CheckCheck, Clock, AlertCircle, Volume2, RotateCw`

**Ожидаемый результат:**
```typescript
const renderStatusIcon = () => {
  if (!isOwnMessage) return null;

  switch (message.status) {
    case MessageStatus.Sending:
      return <Clock className="w-4 h-4 text-white/70 animate-pulse" />;
    case MessageStatus.Sent:
      return <Check className="w-4 h-4 text-white/70" />;
    case MessageStatus.Delivered:
      return <CheckCheck className="w-4 h-4 text-gray-400" />;
    case MessageStatus.Read:
      return <CheckCheck className="w-4 h-4 text-green-400" />;
    case MessageStatus.Played:
      return <Volume2 className="w-4 h-4 text-blue-400" />;
    case MessageStatus.Failed:
      return <AlertCircle className="w-4 h-4 text-red-400" />;
    default:
      return null;
  }
};
```

**Критерии приемки:**
- Все статусы визуализированы корректно
- Иконки отображаются только для своих сообщений
- Цвета соответствуют дизайну мобильного приложения
- Размеры и позиционирование идентичны

**Методы верификации:**
- Визуальное сравнение с мобильным приложением
- Тестирование всех статусов
- Проверка в разных темах (если есть)

---

#### TODO-3.3: Реализация механизма Retry для неудавшихся сообщений
**Приоритет:** High  
**Оценка трудозатрат:** 4 часа  
**Статус:** Pending

**Зависимости:** TODO-3.2

**Входные данные:**
- Логика из `message_bubble.dart` (строки 229-252, 453-483)
- `messageStore.ts` для реализации retry логики
- API endpoints для повторной отправки

**Процесс:**
1. Создать функцию `retryMessage` в `messageStore.ts`
2. Реализовать логику повторной отправки с использованием `localId`
3. Добавить UI элемент кнопки Retry в `MessageBubble.tsx`
4. Обработать успешную и неуспешную повторную отправку
5. Обновить статус сообщения после retry
6. Добавить тосты/уведомления о результате

**Требуемые инструменты:**
- messageStore (Zustand)
- API client
- Toast/notification library

**Ожидаемый результат:**
```typescript
// В MessageBubble.tsx
{isOwnMessage && message.status === MessageStatus.Failed && (
  <button
    onClick={handleRetry}
    className="flex items-center gap-1 px-3 py-1 text-xs text-red-600 
               bg-red-50 hover:bg-red-100 rounded-full transition-colors mt-2"
    title="Повторить отправку"
  >
    <RotateCw className="w-3 h-3" />
    <span>Повторить</span>
  </button>
)}

// В messageStore.ts
retryMessage: async (localId: string) => {
  const message = get().findMessageByLocalId(localId);
  if (!message) return;
  
  set((state) => ({
    messages: state.messages.map(m => 
      m.localId === localId 
        ? { ...m, status: MessageStatus.Sending }
        : m
    )
  }));
  
  try {
    await messageApi.sendMessage(message.chatId, {
      content: message.content,
      type: message.type,
      localId: message.localId
    });
  } catch (error) {
    set((state) => ({
      messages: state.messages.map(m => 
        m.localId === localId 
          ? { ...m, status: MessageStatus.Failed }
          : m
      )
    }));
    throw error;
  }
}
```

**Критерии приемки:**
- Кнопка Retry отображается только для failed сообщений
- Повторная отправка работает корректно
- Статус обновляется в реальном времени
- Обрабатываются ошибки повторной отправки
- Уведомления отображаются пользователю

**Методы верификации:**
- Искусственное создание failed сообщения
- Тестирование retry в offline/online режимах
- Проверка обновления статуса через SignalR

---

### Фаза 4: Поддержка изображений в сообщениях

#### TODO-4.1: Добавление типа сообщения Image
**Приоритет:** High  
**Оценка трудозатрат:** 1 час  
**Статус:** Pending

**Входные данные:**
- `src/types/message.ts`
- Backend enum `MessageType`

**Процесс:**
1. Обновить `MessageType` enum, добавив `Image = 2`
2. Добавить поле `filePath` в интерфейс `Message`
3. Добавить поле `localImagePath` для локального кэша
4. Обновить все места использования типов

**Ожидаемый результат:**
```typescript
export enum MessageType {
  Text = 0,
  Audio = 1,
  Image = 2  // NEW
}

export interface Message {
  id: string;
  chatId: string;
  senderId: string;
  senderName?: string;
  content?: string;
  type: MessageType;
  filePath?: string;           // NEW
  localImagePath?: string;     // NEW
  status: MessageStatus;
  createdAt: Date;
  localId?: string;
}
```

**Критерии приемки:**
- Типы обновлены без breaking changes
- TypeScript компилируется без ошибок

---

#### TODO-4.2: Реализация отображения изображений в MessageBubble
**Приоритет:** High  
**Оценка трудозатрат:** 4 часа  
**Статус:** Pending

**Зависимости:** TODO-4.1

**Входные данные:**
- Логика из `message_bubble.dart` (строки 323-387)
- `MessageBubble.tsx`
- Константы API из `src/utils/constants.ts`

**Процесс:**
1. Добавить рендеринг изображений в `MessageBubble`
2. Реализовать loading placeholder
3. Реализовать error placeholder
4. Добавить поддержку локальных изображений (localImagePath)
5. Оптимизировать размер отображаемых изображений (200x200px с cover)
6. Добавить скругление углов (border-radius: 8px)
7. Реализовать lazy loading

**Требуемые инструменты:**
- React lazy loading
- Image optimization library (опционально)

**Ожидаемый результат:**
```typescript
const renderMessageContent = () => {
  switch (message.type) {
    case MessageType.Text:
      return <p className="whitespace-pre-wrap break-words">{message.content}</p>;
    
    case MessageType.Audio:
      return <AudioPlayer filePath={message.filePath} isOwnMessage={isOwnMessage} />;
    
    case MessageType.Image:
      const imageUrl = message.localImagePath || 
        (message.filePath ? `${API_BASE_URL}${message.filePath}` : null);
      
      return (
        <div 
          className="w-[200px] h-[200px] rounded-lg overflow-hidden cursor-pointer"
          onClick={() => setFullScreenImage(imageUrl)}
        >
          {imageUrl ? (
            <img
              src={imageUrl}
              alt="Изображение"
              className="w-full h-full object-cover"
              loading="lazy"
              onError={(e) => {
                e.currentTarget.src = '/placeholder-error.png';
              }}
            />
          ) : (
            <div className="w-full h-full bg-gray-300 flex items-center justify-center">
              <span className="text-sm text-gray-600">Изображение недоступно</span>
            </div>
          )}
        </div>
      );
    
    default:
      return null;
  }
};
```

**Критерии приемки:**
- Изображения отображаются корректно
- Loading и error states работают
- Размеры соответствуют дизайну (200x200px)
- Lazy loading реализован
- Клик по изображению открывает полноэкранный просмотр

---

#### TODO-4.3: Реализация полноэкранного просмотра изображений
**Приоритет:** Medium  
**Оценка трудозатрат:** 3 часа  
**Статус:** Pending

**Зависимости:** TODO-4.2

**Входные данные:**
- Компонент `fullscreen_image_viewer.dart` из мобильного приложения
- Дизайн модального окна

**Процесс:**
1. Создать компонент `FullScreenImageViewer.tsx`
2. Реализовать модальное окно с затемнённым фоном
3. Добавить изображение в полном размере
4. Реализовать закрытие по клику вне изображения или по кнопке
5. Добавить информацию об отправителе и времени
6. Реализовать навигацию между изображениями (опционально)
7. Добавить zoom функционал (опционально)

**Требуемые инструменты:**
- React Portal для модального окна
- CSS для полноэкранного отображения

**Ожидаемый результат:**
```typescript
// FullScreenImageViewer.tsx
interface FullScreenImageViewerProps {
  imageUrl: string | null;
  onClose: () => void;
  senderName?: string;
  createdAt?: Date;
}

export const FullScreenImageViewer = ({ 
  imageUrl, 
  onClose, 
  senderName, 
  createdAt 
}: FullScreenImageViewerProps) => {
  if (!imageUrl) return null;
  
  return (
    <div 
      className="fixed inset-0 bg-black/90 z-50 flex items-center justify-center"
      onClick={onClose}
    >
      <button
        className="absolute top-4 right-4 text-white text-2xl"
        onClick={onClose}
      >
        ✕
      </button>
      
      <div className="max-w-[90vw] max-h-[90vh]">
        <img
          src={imageUrl}
          alt="Полноразмерное изображение"
          className="max-w-full max-h-full object-contain"
          onClick={(e) => e.stopPropagation()}
        />
        
        {(senderName || createdAt) && (
          <div className="text-white text-center mt-4">
            {senderName && <p className="font-semibold">{senderName}</p>}
            {createdAt && <p className="text-sm">{formatDateTime(createdAt)}</p>}
          </div>
        )}
      </div>
    </div>
  );
};
```

**Критерии приемки:**
- Полноэкранный просмотр работает корректно
- Закрытие по клику и по кнопке работает
- Изображение масштабируется корректно
- Информация об отправителе отображается

---

#### TODO-4.4: Добавление кнопки отправки изображений в MessageInput
**Приоритет:** High  
**Оценка трудозатрат:** 3 часа  
**Статус:** Pending

**Входные данные:**
- Компонент `image_picker_buttons.dart` из мобильного приложения
- `MessageInput.tsx`

**Процесс:**
1. Добавить кнопку выбора изображения в `MessageInput`
2. Реализовать input[type="file"] с accept="image/*"
3. Добавить preview выбранного изображения
4. Реализовать отправку изображения через API
5. Добавить loading state во время отправки
6. Реализовать локальное кэширование отправленных изображений
7. Обработать ошибки отправки

**Требуемые инструменты:**
- File API
- FormData для отправки файлов
- lucide-react: `Image` icon

**Ожидаемый результат:**
```typescript
// В MessageInput.tsx
const [selectedImage, setSelectedImage] = useState<File | null>(null);
const fileInputRef = useRef<HTMLInputElement>(null);

const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
  const file = e.target.files?.[0];
  if (file && file.type.startsWith('image/')) {
    setSelectedImage(file);
  }
};

const handleSendImage = async () => {
  if (!selectedImage) return;
  
  const formData = new FormData();
  formData.append('image', selectedImage);
  formData.append('chatId', selectedChatId);
  
  try {
    await messageApi.sendImageMessage(selectedChatId, formData);
    setSelectedImage(null);
  } catch (error) {
    console.error('Failed to send image:', error);
  }
};

// UI
<>
  <input
    ref={fileInputRef}
    type="file"
    accept="image/*"
    className="hidden"
    onChange={handleImageSelect}
  />
  
  <button
    type="button"
    onClick={() => fileInputRef.current?.click()}
    className="p-2 text-gray-600 hover:text-indigo-600"
  >
    <Image className="w-6 h-6" />
  </button>
  
  {selectedImage && (
    <ImagePreview
      file={selectedImage}
      onRemove={() => setSelectedImage(null)}
      onSend={handleSendImage}
    />
  )}
</>
```

**Критерии приемки:**
- Кнопка выбора изображения работает
- Preview отображается корректно
- Отправка изображений работает
- Loading state отображается
- Ошибки обрабатываются

---

### Фаза 5: Статус "в сети" и последнее посещение

#### TODO-5.1: Добавление полей статуса онлайн в типы Chat
**Приоритет:** Medium  
**Оценка трудозатрат:** 1 час  
**Статус:** Pending

**Входные данные:**
- `src/types/chat.ts`
- Модель `Chat` из мобильного приложения

**Процесс:**
1. Добавить поля в интерфейс `Chat`:
   - `otherParticipantId?: string`
   - `otherParticipantIsOnline?: boolean`
   - `otherParticipantLastSeenAt?: Date`
2. Обновить все места использования типа `Chat`

**Ожидаемый результат:**
```typescript
export interface Chat {
  id: string;
  type: ChatType;
  title: string;
  avatar?: string;
  participants?: ChatParticipant[];
  lastMessage?: Message;
  unreadCount: number;
  createdAt: Date;
  
  // NEW fields
  otherParticipantId?: string;
  otherParticipantIsOnline?: boolean;
  otherParticipantLastSeenAt?: Date;
}
```

**Критерии приемки:**
- Типы обновлены
- TypeScript компилируется без ошибок

---

#### TODO-5.2: Получение статуса онлайн через SignalR
**Приоритет:** Medium  
**Оценка трудозатрат:** 3 часа  
**Статус:** Pending

**Зависимости:** TODO-5.1

**Входные данные:**
- `signalRService.ts`
- SignalR hub методы для статуса онлайн

**Процесс:**
1. Добавить подписку на события `UserOnlineStatusChanged` в SignalR
2. Реализовать обновление chatStore при изменении статуса
3. Добавить обработку события в `chatStore.ts`
4. Реализовать периодический запрос статусов при необходимости

**Требуемые инструменты:**
- SignalR Client
- Zustand store

**Ожидаемый результат:**
```typescript
// В signalRService.ts
onUserOnlineStatusChanged: (callback: (userId: string, isOnline: boolean, lastSeenAt?: Date) => void) => {
  connection.on('UserOnlineStatusChanged', callback);
  return () => connection.off('UserOnlineStatusChanged', callback);
}

// В chatStore.ts
updateParticipantOnlineStatus: (userId: string, isOnline: boolean, lastSeenAt?: Date) => {
  set((state) => ({
    chats: state.chats.map(chat =>
      chat.otherParticipantId === userId
        ? {
            ...chat,
            otherParticipantIsOnline: isOnline,
            otherParticipantLastSeenAt: lastSeenAt
          }
        : chat
    )
  }));
}
```

**Критерии приемки:**
- SignalR события обрабатываются
- Статус обновляется в реальном времени
- Store корректно обновляется

---

#### TODO-5.3: Отображение статуса онлайн в ChatWindow
**Приоритет:** Medium  
**Оценка трудозатрат:** 2 часа  
**Статус:** Pending

**Зависимости:** TODO-5.2

**Входные данные:**
- Логика из `chat_screen.dart` (строки 183-203)
- `ChatWindow.tsx`

**Процесс:**
1. Добавить логику форматирования статуса "последнее посещение"
2. Отобразить статус в header чата
3. Применить соответствующие цвета (зелёный для онлайн, серый для офлайн)
4. Добавить анимацию для индикатора онлайн

**Ожидаемый результат:**
```typescript
// В ChatWindow.tsx
const getOnlineStatusText = (chat: Chat): string | null => {
  if (chat.type !== ChatType.Private || !chat.otherParticipantId) {
    return null;
  }
  
  if (chat.otherParticipantIsOnline) {
    return 'онлайн';
  }
  
  if (chat.otherParticipantLastSeenAt) {
    const now = new Date();
    const diff = Math.floor((now.getTime() - chat.otherParticipantLastSeenAt.getTime()) / 1000);
    
    if (diff < 60) return 'только что';
    if (diff < 3600) return `был(а) ${Math.floor(diff / 60)} мин назад`;
    if (diff < 86400) return `был(а) ${Math.floor(diff / 3600)} ч назад`;
    if (diff < 604800) return `был(а) ${Math.floor(diff / 86400)} дн назад`;
    return 'был(а) давно';
  }
  
  return null;
};

// UI
<div>
  <h2 className="font-semibold text-gray-900">{selectedChat?.title}</h2>
  {onlineStatusText && (
    <p className={`text-sm ${
      onlineStatusText === 'онлайн' ? 'text-green-500' : 'text-gray-500'
    }`}>
      {onlineStatusText === 'онлайн' && (
        <span className="inline-block w-2 h-2 bg-green-500 rounded-full mr-1 animate-pulse" />
      )}
      {onlineStatusText}
    </p>
  )}
</div>
```

**Критерии приемки:**
- Статус "онлайн" отображается с зелёным индикатором
- Статус "последнее посещение" форматируется корректно
- Анимация работает плавно

---

#### TODO-5.4: Отображение статуса онлайн в ChatList
**Приоритет:** Low  
**Оценка трудозатрат:** 2 часа  
**Статус:** Pending

**Зависимости:** TODO-5.2

**Входные данные:**
- Логика из `chat_list_item.dart` (строки 114-133)
- `ChatList.tsx`

**Процесс:**
1. Добавить зелёный индикатор онлайн статуса на аватар
2. Позиционировать индикатор в правом нижнем углу аватара
3. Добавить border для чёткости индикатора
4. Отображать только для приватных чатов

**Ожидаемый результат:**
```typescript
// В ChatList.tsx, компонент ChatListItem
<div className="relative w-12 h-12 bg-indigo-600 rounded-full flex items-center justify-center text-white font-semibold flex-shrink-0">
  {chat.title?.[0]?.toUpperCase() || '?'}
  
  {chat.type === ChatType.Private && chat.otherParticipantIsOnline && (
    <span className="absolute bottom-0 right-0 w-3 h-3 bg-green-500 border-2 border-white rounded-full" />
  )}
</div>
```

**Критерии приемки:**
- Индикатор отображается только для онлайн пользователей
- Позиционирование корректное
- Border создаёт чёткую границу с аватаром

---

### Фаза 6: Улучшения UI/UX

#### TODO-6.1: Унификация цветовой схемы
**Приоритет:** Medium  
**Оценка трудозатрат:** 2 часа  
**Статус:** Pending

**Входные данные:**
- Цветовая схема из `app_theme.dart`
- Текущий `tailwind.config.js`

**Процесс:**
1. Обновить `tailwind.config.js`, добавив custom цвета
2. Привести в соответствие с Material 3 цветами из мобильного приложения
3. Заменить hardcoded цвета на переменные Tailwind
4. Обеспечить поддержку тёмной темы (если требуется)

**Ожидаемый результат:**
```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#E3F2FD',
          100: '#BBDEFB',
          // ... Material 3 Blue palette
          600: '#1E88E5',  // Main primary color
          700: '#1976D2',
        },
        surface: {
          container: '#F5F5F5',
          'container-high': '#EEEEEE',
          'container-highest': '#E0E0E0',
        }
      }
    }
  }
}
```

**Критерии приемки:**
- Цвета соответствуют мобильному приложению
- Нет hardcoded значений цветов
- Поддержка тёмной темы (если требуется)

---

#### TODO-6.2: Улучшение типографики
**Приоритет:** Low  
**Оценка трудозатрат:** 1 час  
**Статус:** Pending

**Входные данные:**
- Типографика из мобильного приложения
- `index.css`

**Процесс:**
1. Обновить font-family в соответствии с мобильным приложением
2. Добавить font sizes как в Material 3
3. Добавить font weights
4. Обновить line-height для лучшей читаемости

**Ожидаемый результат:**
```css
/* index.css */
:root {
  /* Typography Scale - Material 3 */
  --font-display-large: 57px;
  --font-headline-large: 32px;
  --font-headline-medium: 28px;
  --font-title-large: 22px;
  --font-body-large: 16px;
  --font-body-medium: 14px;
  --font-label-medium: 12px;
  
  /* Line Heights */
  --line-height-tight: 1.25;
  --line-height-normal: 1.5;
  --line-height-relaxed: 1.75;
}
```

**Критерии приемки:**
- Типографика соответствует мобильному приложению
- Шрифты читаемы на всех экранах
- Консистентность во всём приложении

---

#### TODO-6.3: Добавление плавных анимаций и переходов
**Приоритет:** Low  
**Оценка трудозатрат:** 2 часа  
**Статус:** Pending

**Входные данные:**
- Анимации из мобильного приложения
- TailwindCSS transitions

**Процесс:**
1. Добавить transitions для hover states
2. Реализовать плавные появления/исчезновения элементов
3. Добавить анимации для loading states
4. Реализовать spring animations (если требуется)

**Критерии приемки:**
- Анимации плавные и не лагают
- Соответствуют UX мобильного приложения
- Не влияют на производительность

---

### Фаза 7: Оптимизация и тестирование

#### TODO-7.1: Оптимизация производительности
**Приоритет:** Medium  
**Оценка трудозатрат:** 4 часа  
**Статус:** Pending

**Процесс:**
1. Добавить React.memo для компонентов сообщений
2. Реализовать виртуализацию списка сообщений (react-window)
3. Оптимизировать re-renders в Zustand stores
4. Добавить debounce для typing indicators
5. Оптимизировать загрузку изображений

**Требуемые инструменты:**
- React DevTools Profiler
- react-window или react-virtual
- lodash.debounce

**Критерии приемки:**
- Плавная прокрутка чатов с большим количеством сообщений
- Минимум unnecessary re-renders
- Быстрая загрузка изображений

---

#### TODO-7.2: Тестирование на разных экранах и устройствах
**Приоритет:** High  
**Оценка трудозатрат:** 3 часа  
**Статус:** Pending

**Процесс:**
1. Протестировать на desktop (1920x1080, 1366x768)
2. Протестировать на tablet (768x1024)
3. Протестировать на mobile (375x667, 414x896)
4. Проверить все breakpoints Tailwind
5. Протестировать в разных браузерах

**Критерии приемки:**
- Корректное отображение на всех экранах
- Responsive дизайн работает
- Нет горизонтального scroll
- Все элементы кликабельны на мобильных

---

#### TODO-7.3: Написание модульных тестов
**Приоритет:** Medium  
**Оценка трудозатрат:** 6 часов  
**Статус:** Pending

**Процесс:**
1. Написать тесты для MessageBubble
2. Написать тесты для MessageInput
3. Написать тесты для stores (chatStore, messageStore)
4. Написать тесты для signalRService
5. Достичь coverage > 70%

**Требуемые инструменты:**
- Vitest
- React Testing Library
- MSW (Mock Service Worker)

**Критерии приемки:**
- Все критические компоненты покрыты тестами
- Coverage > 70%
- Все тесты проходят

---

#### TODO-7.4: E2E тестирование основных сценариев
**Приоритет:** Low  
**Оценка трудозатрат:** 4 часа  
**Статус:** Pending

**Процесс:**
1. Настроить Playwright или Cypress
2. Написать E2E тесты для:
   - Отправка текстового сообщения
   - Отправка аудио сообщения
   - Отправка изображения
   - Retry failed message
   - Создание нового чата
3. Запустить в CI/CD (если есть)

**Требуемые инструменты:**
- Playwright или Cypress
- Mock backend (опционально)

**Критерии приемки:**
- Основные сценарии покрыты E2E тестами
- Тесты стабильны и проходят

---

### Фаза 8: Документирование и деплой

#### TODO-8.1: Обновление документации
**Приоритет:** Low  
**Оценка трудозатрат:** 2 часа  
**Статус:** Pending

**Процесс:**
1. Обновить README.md с новыми функциями
2. Документировать API endpoints для изображений
3. Создать changelog с перечислением всех изменений
4. Добавить скриншоты UI

**Ожидаемый результат:**
- Актуальный README.md
- CHANGELOG.md с версиями
- Документация API

---

#### TODO-8.2: Сборка и деплой production версии
**Приоритет:** High  
**Оценка трудозатрат:** 2 часа  
**Статус:** Pending

**Процесс:**
1. Выполнить production build: `npm run build`
2. Протестировать production build локально
3. Оптимизировать bundle size (если нужно)
4. Задеплоить на production сервер
5. Проверить работу на production

**Критерии приемки:**
- Production build успешно создаётся
- Нет ошибок в console
- Все функции работают на production

---

## 3. МЕТАДАННЫЕ ВЫПОЛНЕНИЯ

### Сводная таблица задач

| ID | Задача | Приоритет | Оценка | Фаза | Зависимости |
|---|---|---|---|---|---|
| TODO-1.1 | Сравнительный анализ | High | 2ч | 1 | - |
| TODO-2.1 | Исправление ширины MessageBubble | Critical | 3ч | 2 | TODO-1.1 |
| TODO-2.2 | Отображение имени отправителя | High | 1ч | 2 | TODO-2.1 |
| TODO-2.3 | Подсветка сообщений | Medium | 2ч | 2 | TODO-2.1 |
| TODO-3.1 | Добавление статусов в типы | High | 1ч | 3 | - |
| TODO-3.2 | Визуализация статусов | High | 3ч | 3 | TODO-3.1 |
| TODO-3.3 | Механизм Retry | High | 4ч | 3 | TODO-3.2 |
| TODO-4.1 | Тип сообщения Image | High | 1ч | 4 | - |
| TODO-4.2 | Отображение изображений | High | 4ч | 4 | TODO-4.1 |
| TODO-4.3 | Полноэкранный просмотр | Medium | 3ч | 4 | TODO-4.2 |
| TODO-4.4 | Отправка изображений | High | 3ч | 4 | TODO-4.1 |
| TODO-5.1 | Поля статуса онлайн | Medium | 1ч | 5 | - |
| TODO-5.2 | Получение статуса через SignalR | Medium | 3ч | 5 | TODO-5.1 |
| TODO-5.3 | Отображение статуса в ChatWindow | Medium | 2ч | 5 | TODO-5.2 |
| TODO-5.4 | Отображение статуса в ChatList | Low | 2ч | 5 | TODO-5.2 |
| TODO-6.1 | Унификация цветовой схемы | Medium | 2ч | 6 | - |
| TODO-6.2 | Улучшение типографики | Low | 1ч | 6 | - |
| TODO-6.3 | Анимации и переходы | Low | 2ч | 6 | - |
| TODO-7.1 | Оптимизация производительности | Medium | 4ч | 7 | - |
| TODO-7.2 | Тестирование на устройствах | High | 3ч | 7 | Все предыдущие |
| TODO-7.3 | Модульные тесты | Medium | 6ч | 7 | - |
| TODO-7.4 | E2E тестирование | Low | 4ч | 7 | TODO-7.3 |
| TODO-8.1 | Обновление документации | Low | 2ч | 8 | - |
| TODO-8.2 | Деплой | High | 2ч | 8 | Все предыдущие |

**Общая оценка трудозатрат:** 61 час (примерно 8 рабочих дней)

### Возможности параллельного выполнения

**Могут выполняться параллельно:**
- Фаза 2 (TODO-2.x) и Фаза 3 (TODO-3.1)
- TODO-4.1 и TODO-5.1 (оба - обновление типов)
- TODO-6.1, TODO-6.2, TODO-6.3 (все UI улучшения независимы)
- TODO-7.3 и TODO-7.1 (тесты и оптимизация)

**Критический путь:**
1. TODO-1.1 → TODO-2.1 → TODO-2.2
2. TODO-3.1 → TODO-3.2 → TODO-3.3
3. TODO-4.1 → TODO-4.2 → TODO-4.3
4. TODO-7.2 (зависит от всех функциональных задач)
5. TODO-8.2 (финальный деплой)

---

## 4. ФУНКЦИОНАЛЬНЫЕ ТРЕБОВАНИЯ (PRD)

### 4.1 Описание функций и обоснование

#### 4.1.1 Исправление отображения пузырей сообщений

**Описание:**  
Пузыри сообщений должны корректно отображать текст любой длины, включая длинные слова и URL, без горизонтального overflow и с правильным переносом строк.

**Обоснование:**  
В текущей версии веб-клиента длинные слова выходят за пределы пузыря или создают горизонтальную прокрутку, что создаёт плохой UX. Мобильное приложение корректно обрабатывает эту ситуацию.

**Ожидаемое поведение:**
- Максимальная ширина пузыря: 70% ширины экрана или 500px (что меньше)
- Минимальная ширина: 80px для коротких сообщений
- Автоматический перенос слов с использованием `word-wrap: break-word` и `overflow-wrap: anywhere`
- Поддержка переносов в длинных URL

---

#### 4.1.2 Статусы сообщений

**Описание:**  
Визуализация всех шести статусов сообщений с соответствующими иконками и цветами.

**Обоснование:**  
Пользователи должны видеть текущее состояние отправленного сообщения (отправляется, отправлено, доставлено, прочитано, воспроизведено, ошибка).

**Статусы:**
1. **Sending** (0) - Отправляется: Clock icon с анимацией pulse, цвет white/70
2. **Sent** (1) - Отправлено: одна галочка (Check), цвет white/70
3. **Delivered** (2) - Доставлено: две галочки (CheckCheck), цвет gray-400
4. **Read** (3) - Прочитано: две галочки (CheckCheck), цвет green-400
5. **Played** (4) - Воспроизведено: иконка динамика (Volume2), цвет blue-400
6. **Failed** (5) - Ошибка: иконка ошибки (AlertCircle), цвет red-400 + кнопка Retry

**User Flow:**
1. Пользователь отправляет сообщение → статус Sending
2. Сообщение достигает сервера → статус Sent
3. Получатель получает сообщение → статус Delivered (SignalR уведомление)
4. Получатель открывает чат → статус Read (SignalR уведомление)
5. Для аудио: получатель воспроизводит → статус Played (SignalR уведомление)
6. При ошибке → статус Failed, пользователь может нажать Retry

---

#### 4.1.3 Retry механизм для неудавшихся сообщений

**Описание:**  
Пользователи могут повторно отправить сообщения, которые не удалось отправить с первого раза.

**Обоснование:**  
Сетевые проблемы могут привести к неудачной отправке. Вместо того, чтобы заставлять пользователя переписывать сообщение, нужно предоставить простой способ повторной отправки.

**User Flow:**
1. Сообщение не отправляется (сетевая ошибка, 5xx) → статус Failed
2. Под пузырём сообщения появляется кнопка "Повторить" с иконкой RotateCw
3. Пользователь нажимает "Повторить"
4. Показывается тост "Повторная отправка..."
5. Статус меняется на Sending
6. Попытка отправки через API
7. Успех → статус Sent, сообщение синхронизируется с сервером
8. Провал → статус снова Failed, тост с ошибкой

**Технические детали:**
- Используется `localId` для идентификации сообщения
- Сообщения с Failed статусом сохраняются в IndexedDB
- При retry отправляется тот же `localId` для предотвращения дубликатов на сервере

---

#### 4.1.4 Поддержка изображений в сообщениях

**Описание:**  
Пользователи могут отправлять и просматривать изображения в чатах.

**Обоснование:**  
Это базовая функция современных мессенджеров, уже реализованная в мобильном приложении.

**User Flow - Отправка:**
1. Пользователь нажимает кнопку изображения (Image icon) в MessageInput
2. Открывается file picker (accept="image/*")
3. Пользователь выбирает изображение
4. Показывается preview с кнопками "Отправить" и "Отмена"
5. Пользователь нажимает "Отправить"
6. Изображение загружается на сервер через multipart/form-data
7. После успешной загрузки показывается в чате

**User Flow - Просмотр:**
1. Изображение отображается в пузыре сообщения (200x200px, cover)
2. Пользователь кликает на изображение
3. Открывается полноэкранный просмотр
4. Показывается изображение в полном размере с информацией об отправителе
5. Пользователь может закрыть нажатием вне изображения или кнопкой ✕

**Технические детали:**
- Формат: JPEG, PNG, WebP, GIF
- Максимальный размер: 10MB (backend ограничение)
- Локальное кэширование отправленных изображений в IndexedDB
- Lazy loading для оптимизации производительности

---

#### 4.1.5 Статус "в сети" и последнее посещение

**Описание:**  
Отображение текущего онлайн статуса собеседника и времени последнего посещения.

**Обоснование:**  
Пользователи хотят знать, доступен ли собеседник для разговора в данный момент.

**Отображение в ChatWindow:**
- Если онлайн: "онлайн" зелёным цветом + пульсирующий зелёный кружок
- Если офлайн < 1 мин: "только что" серым
- Если офлайн < 60 мин: "был(а) X мин назад"
- Если офлайн < 24 ч: "был(а) X ч назад"
- Если офлайн < 7 дн: "был(а) X дн назад"
- Если офлайн > 7 дн: "был(а) давно"

**Отображение в ChatList:**
- Зелёный индикатор на аватаре для онлайн пользователей
- Только для приватных чатов

**Технические детали:**
- Статус обновляется через SignalR событие `UserOnlineStatusChanged`
- Fallback: периодический запрос к API (каждые 30 сек) если SignalR недоступен
- Кэширование статусов в chatStore

---

### 4.2 Нефункциональные требования

#### 4.2.1 Производительность
- **Загрузка приложения:** < 3 сек на 4G
- **Отправка сообщения:** < 500ms (оптимистичное обновление UI)
- **Прокрутка сообщений:** 60 FPS на списках > 100 сообщений
- **Загрузка изображений:** progressive loading с placeholder
- **Bundle size:** < 500KB (gzipped)

#### 4.2.2 Масштабируемость
- Поддержка чатов с > 10,000 сообщений (виртуализация)
- Поддержка > 100 активных чатов одновременно
- Эффективное использование памяти (garbage collection для старых сообщений)

#### 4.2.3 Безопасность
- HTTPS для всех запросов
- Sanitization HTML в текстовых сообщениях (предотвращение XSS)
- Валидация файлов на клиенте (тип, размер)
- Secure WebSocket (wss://)
- Content Security Policy headers

#### 4.2.4 Доступность (A11y)
- Keyboard navigation для всех элементов
- ARIA labels для интерактивных элементов
- Контраст текста соответствует WCAG 2.1 AA
- Screen reader friendly

#### 4.2.5 Совместимость браузеров
- Chrome/Edge: последние 2 версии
- Firefox: последние 2 версии
- Safari: последние 2 версии
- Поддержка мобильных браузеров (iOS Safari, Chrome Mobile)

#### 4.2.6 Offline поддержка
- Кэширование сообщений в IndexedDB
- Offline queue для отправляемых сообщений
- Синхронизация при восстановлении соединения
- Визуальная индикация offline статуса

---

### 4.3 User Interaction Flows

#### 4.3.1 Отправка текстового сообщения
```
1. Пользователь вводит текст в MessageInput
   └─> [Typing indicator] отправляется другим участникам (SignalR)
2. Пользователь нажимает Enter или кнопку Send
3. Сообщение мгновенно появляется в UI со статусом Sending
   └─> [Optimistic Update] сообщение добавляется в messageStore с localId
4. API запрос отправляется на backend
   └─> [POST /api/messages]
5. Backend обрабатывает и возвращает сообщение с serverId
6. Статус обновляется на Sent
7. SignalR уведомляет получателей → статус Delivered у отправителя
8. Получатель открывает чат → статус Read у отправителя
```

#### 4.3.2 Отправка аудио сообщения
```
1. Пользователь нажимает и удерживает кнопку микрофона
2. Запрашивается разрешение на микрофон (если не дано)
3. Начинается запись, показывается UI записи
   └─> [Red dot] мигает
   └─> [Timer] отображает длительность
   └─> [Waveform] визуализация (опционально)
4. Пользователь может:
   a) Отпустить кнопку → отправка аудио
   b) Свайп влево → отмена записи
   c) Свайп вверх → блокировка записи
5. При отправке: аудио файл загружается на backend
6. Статусы: Sending → Sent → Delivered → Read → Played
```

#### 4.3.3 Отправка изображения
```
1. Пользователь нажимает кнопку Image
2. Открывается file picker
3. Пользователь выбирает изображение
4. Показывается preview с options:
   └─> [Send button]
   └─> [Cancel button]
5. Пользователь нажимает Send
6. Изображение мгновенно появляется в UI (локальный preview)
7. Загрузка на backend через multipart/form-data
8. Progress bar показывает прогресс загрузки
9. После успешной загрузки обновляется filePath
10. Статусы: Sending → Sent → Delivered → Read
```

#### 4.3.4 Retry неудавшегося сообщения
```
1. Сообщение не отправилось → статус Failed
2. Под пузырём появляется кнопка "Повторить"
3. Пользователь нажимает "Повторить"
4. Тост: "Повторная отправка..."
5. Статус → Sending
6. Попытка повторной отправки через API
7. Success: статус → Sent
   OR
   Failure: статус → Failed, тост с ошибкой
```

---

### 4.4 Edge Cases и Failure Scenarios

#### 4.4.1 Потеря интернет соединения
**Сценарий:** Пользователь отправляет сообщение, но интернет пропал

**Обработка:**
1. Сообщение добавляется в offline queue
2. Статус → Failed
3. Показывается banner: "Нет подключения к интернету"
4. При восстановлении соединения:
   - Автоматически пытаемся отправить сообщения из queue
   - Обновляем статусы
   - Синхронизируем с сервером

**Ожидаемое поведение:**
- Сообщения не теряются
- Пользователь может продолжать писать
- После восстановления всё синхронизируется

---

#### 4.4.2 Отправка очень большого изображения
**Сценарий:** Пользователь пытается отправить изображение > 10MB

**Обработка:**
1. Валидация на клиенте перед отправкой
2. Показывается ошибка: "Изображение слишком большое. Максимум 10MB"
3. Предложение сжать изображение (опционально)

**Ожидаемое поведение:**
- Изображение не отправляется
- Понятное сообщение об ошибке
- Возможность выбрать другое изображение

---

#### 4.4.3 Получение сообщения в закрытом чате
**Сценарий:** Пользователь находится в чате A, приходит сообщение в чат B

**Обработка:**
1. SignalR получает событие `ReceiveMessage`
2. Сообщение добавляется в messageStore для чата B
3. chatStore обновляет `unreadCount` для чата B
4. chatStore обновляет `lastMessage` для чата B
5. Чат B перемещается наверх списка (sort by lastMessage.createdAt)
6. Показывается push notification (если разрешено)

**Ожидаемое поведение:**
- Счётчик непрочитанных обновляется
- Чат перемещается наверх
- Пользователь получает уведомление

---

#### 4.4.4 Удалённое изображение/аудио
**Сценарий:** Сервер удалил файл (retention policy), пользователь пытается открыть

**Обработка:**
1. При клике на изображение/аудио: запрос к серверу
2. Сервер возвращает 404 Not Found
3. Показывается placeholder: "Файл больше не доступен"
4. Для аудио: кнопка play неактивна

**Ожидаемое поведение:**
- Приложение не падает
- Понятное сообщение пользователю
- Возможность продолжить работу

---

#### 4.4.5 Конфликт localId и serverId
**Сценарий:** Сообщение отправлено, но ответ с serverId не пришёл, SignalR получил это же сообщение

**Обработка:**
1. При получении сообщения через SignalR проверяем localId
2. Если найдено сообщение с таким localId:
   - Обновляем id на serverId
   - Обновляем статус
   - Не дублируем сообщение
3. Если не найдено:
   - Добавляем как новое сообщение

**Ожидаемое поведение:**
- Нет дубликатов сообщений
- Корректная синхронизация
- Правильные статусы

---

#### 4.4.6 Очень длинное сообщение (> 5000 символов)
**Сценарий:** Пользователь вставляет огромный текст из буфера обмена

**Обработка:**
1. Валидация на клиенте: maxLength 5000
2. Если больше: показывается ошибка "Сообщение слишком длинное (макс. 5000 символов)"
3. Текст обрезается до 5000 символов

**Ожидаемое поведение:**
- Текст не теряется
- Понятное ограничение
- Возможность разбить на несколько сообщений

---

#### 4.4.7 Быстрые повторные клики на Retry
**Сценарий:** Пользователь нервно кликает Retry несколько раз

**Обработка:**
1. Disable кнопки Retry после первого клика
2. Debounce функции retry (500ms)
3. Показывать loading state

**Ожидаемое поведение:**
- Только одна попытка отправки
- Нет дублирующихся запросов
- Визуальная обратная связь

---

#### 4.4.8 SignalR disconnected
**Сценарий:** SignalR соединение разорвалось, но HTTP запросы работают

**Обработка:**
1. Показывается warning banner: "Соединение потеряно. Попытка переподключения..."
2. Автоматические попытки переподключения (exponential backoff)
3. Fallback на polling для получения новых сообщений
4. При восстановлении: синхронизация пропущенных событий

**Ожидаемое поведение:**
- Пользователь может продолжать работу
- Сообщения отправляются
- После восстановления всё синхронизируется

---

## 5. QUALITY ENFORCEMENT RULES

### 5.1 Code Quality Standards

#### TypeScript
- ✅ Strict mode enabled (`"strict": true`)
- ✅ Явные типы для всех props и state
- ✅ Нет использования `any` (кроме исключительных случаев с комментарием)
- ✅ Интерфейсы предпочтительнее type aliases для объектов
- ✅ Enum для фиксированных наборов значений

#### React Best Practices
- ✅ Функциональные компоненты + hooks (не классовые)
- ✅ React.memo для компонентов с частыми re-renders
- ✅ useCallback для функций, передаваемых в дочерние компоненты
- ✅ useMemo для дорогих вычислений
- ✅ Правильные dependency arrays в useEffect
- ✅ Cleanup функции в useEffect где необходимо

#### CSS/Styling
- ✅ Использование Tailwind utility classes
- ✅ Избегать inline styles (кроме динамических значений)
- ✅ Responsive дизайн через Tailwind breakpoints
- ✅ Консистентные spacing values (4, 8, 12, 16, 24, 32, 48px)

#### Naming Conventions
- ✅ Components: PascalCase (`MessageBubble.tsx`)
- ✅ Functions: camelCase (`handleRetry`)
- ✅ Constants: UPPER_SNAKE_CASE (`API_BASE_URL`)
- ✅ Types/Interfaces: PascalCase (`Message`, `MessageStatus`)
- ✅ Files: kebab-case для utils (`format-date.ts`), PascalCase для компонентов

---

### 5.2 Testing Requirements

- ✅ Unit tests для всех utility functions (coverage 100%)
- ✅ Component tests для критических компонентов (coverage > 80%)
- ✅ Integration tests для stores
- ✅ E2E tests для основных user flows
- ✅ Все тесты должны быть зелёными перед merge

---

### 5.3 Performance Requirements

- ✅ Lighthouse Score > 90 (Performance, Accessibility, Best Practices)
- ✅ First Contentful Paint < 1.5s
- ✅ Time to Interactive < 3s
- ✅ Cumulative Layout Shift < 0.1
- ✅ Bundle size < 500KB (gzipped)

---

### 5.4 Accessibility Requirements

- ✅ Keyboard navigation работает для всех элементов
- ✅ ARIA labels для всех интерактивных элементов
- ✅ Цветовой контраст соответствует WCAG 2.1 AA (4.5:1 для текста)
- ✅ Focus indicators видны и понятны
- ✅ Альтернативные тексты для изображений

---

### 5.5 Documentation Requirements

- ✅ JSDoc комментарии для всех публичных функций
- ✅ README.md обновлён с новыми функциями
- ✅ CHANGELOG.md ведётся для каждой версии
- ✅ Inline комментарии для сложной логики
- ✅ Примеры использования для сложных компонентов

---

## 6. OUTPUT FORMAT

### 6.1 Primary Format: Markdown

Этот документ представлен в формате Markdown с:
- Чёткой иерархией заголовков
- Таблицами для сводных данных
- Списками для структурированной информации
- Code blocks для примеров кода
- Emoji для визуальных индикаторов (✅, ⚠️, 🔴)

### 6.2 Alternative Format: JSON (on request)

При необходимости этот PRD может быть экспортирован в JSON схему для автоматизированной обработки:

```json
{
  "project": {
    "name": "May Messenger Web Client Alignment",
    "version": "1.0.0",
    "created": "2025-12-22"
  },
  "phases": [
    {
      "id": 1,
      "name": "Аудит и документирование",
      "tasks": [...]
    },
    ...
  ],
  "requirements": {
    "functional": [...],
    "nonFunctional": [...]
  }
}
```

---

## 7. EXECUTION READINESS CHECKLIST

Перед началом выполнения убедитесь:

- ✅ Все зависимости установлены (`npm install`)
- ✅ Backend API доступен и работает
- ✅ SignalR hub настроен и работает
- ✅ Есть доступ к тестовой базе данных
- ✅ Настроена среда разработки (VSCode + расширения)
- ✅ Git настроен, создана ветка для разработки
- ✅ Команда ознакомлена с PRD
- ✅ Приоритеты согласованы со stakeholders
- ✅ Выделено время для выполнения (~8 рабочих дней)

---

## 8. РИСКИ И МИТИГАЦИЯ

| Риск | Вероятность | Влияние | Митигация |
|---|---|---|---|
| Backend API изменится | Средняя | Высокое | Версионирование API, contracts |
| Performance проблемы на больших чатах | Средняя | Среднее | Виртуализация, lazy loading |
| SignalR disconnects | Высокая | Среднее | Robust reconnection logic, fallback polling |
| Браузерная совместимость | Низкая | Среднее | Polyfills, graceful degradation |
| Превышение оценки времени | Средняя | Среднее | Буфер 20%, приоритизация Critical задач |

---

## 9. SUCCESS METRICS

### Метрики успеха проекта:
1. ✅ **Функциональная полнота:** 100% функций из мобильного приложения реализованы
2. ✅ **Визуальное соответствие:** < 5% отклонений в UI от мобильного приложения
3. ✅ **Производительность:** Lighthouse Score > 90
4. ✅ **Качество кода:** TypeScript strict mode, 0 errors, < 10 warnings
5. ✅ **Тестовое покрытие:** > 70% coverage
6. ✅ **User Satisfaction:** Положительные отзывы от тестировщиков
7. ✅ **Bug Rate:** < 5 критических багов на релиз
8. ✅ **Deployment Success:** Production deploy без rollback

---

## 10. MAINTENANCE PLAN

### После завершения проекта:

1. **Мониторинг производительности:**
   - Настроить Sentry/Rollbar для отслеживания ошибок
   - Lighthouse CI для регрессии производительности
   - Analytics для user behavior

2. **Регулярные обновления:**
   - Зависимости: ежемесячно
   - Security patches: немедленно
   - Browser support: следовать рыночной доле

3. **Документирование:**
   - Обновление README при добавлении функций
   - CHANGELOG при каждом релизе
   - API documentation синхронизирована с backend

4. **Code reviews:**
   - Все PR требуют ревью
   - Checklist для reviewers
   - Automated checks (linting, tests)

---

## ЗАКЛЮЧЕНИЕ

Этот PRD предоставляет полный, детальный и исполняемый план для приведения веб-клиента May Messenger в соответствие с мобильным приложением. Документ структурирован для использования LLM-агентами и человеческими разработчиками, содержит все необходимые детали для выполнения без дополнительных уточнений.

**Следующие шаги:**
1. Согласование PRD со stakeholders
2. Создание ветки в Git: `feature/web-client-alignment`
3. Начало выполнения с Фазы 1 (TODO-1.1)
4. Регулярные статус-апдейты после завершения каждой фазы

**Контакты для вопросов:**
- Technical Lead: [указать]
- Product Manager: [указать]
- Backend Team: [указать]

---

*Документ создан: 22 декабря 2025*  
*Версия: 1.0.0*  
*Следующий review: После завершения Фазы 3*

