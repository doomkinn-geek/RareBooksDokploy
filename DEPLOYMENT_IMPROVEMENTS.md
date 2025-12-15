# Инструкция по развертыванию улучшений May Messenger

## Обзор изменений

Реализовано 8 критичных улучшений:
1. ✅ Порядок вкладок: "Личные" слева, "Группы" справа
2. ✅ Audio player сбрасывается после окончания воспроизведения
3. ✅ Новый чат появляется в списке сразу после создания
4. ✅ Сообщения помечаются как прочитанные при прокрутке чата
5. ✅ Создание групп через контакты (как и личные чаты)
6. ✅ Групповые статусы: delivered (хотя бы 1), read (все прочитали)
7. ✅ Push уведомления открывают соответствующий чат
8. ✅ Исправлена ошибка сборки с launch_background

## Backend изменения

### Новая миграция БД

Добавлена таблица `DeliveryReceipts` для отслеживания доставки и прочтения сообщений каждым участником (критично для групп).

```sql
CREATE TABLE "DeliveryReceipts" (
    "Id" uuid PRIMARY KEY,
    "MessageId" uuid NOT NULL REFERENCES "Messages"("Id") ON DELETE CASCADE,
    "UserId" uuid NOT NULL REFERENCES "Users"("Id") ON DELETE CASCADE,
    "DeliveredAt" timestamp,
    "ReadAt" timestamp,
    "CreatedAt" timestamp NOT NULL,
    "UpdatedAt" timestamp NOT NULL
);

CREATE UNIQUE INDEX "IX_DeliveryReceipts_MessageId_UserId" ON "DeliveryReceipts" ("MessageId", "UserId");
CREATE INDEX "IX_DeliveryReceipts_MessageId" ON "DeliveryReceipts" ("MessageId");
```

### Развертывание backend на Ubuntu

```bash
# 1. Перейти в папку backend на сервере
cd ~/rarebooks/_may_messenger_backend

# 2. Остановить контейнеры
docker compose down

# 3. Получить обновления из git
git pull origin master

# 4. Применить миграцию БД
docker compose up -d postgres
sleep 5

# 5. Применить миграцию через dotnet
cd src/MayMessenger.Infrastructure
dotnet ef database update --startup-project ../MayMessenger.API --connection "Host=localhost;Port=5432;Database=maymessenger;Username=postgres;Password=postgres"

# 6. Перезапустить все сервисы
cd ~/rarebooks
docker compose up -d --build

# 7. Проверить логи
docker compose logs -f messenger_backend
```

### Альтернативный метод (если dotnet ef не установлен)

```bash
# После git pull и перезапуска контейнеров миграция применится автоматически
cd ~/rarebooks/_may_messenger_backend
git pull origin master
docker compose down
docker compose up -d --build

# Миграция применится при старте приложения
docker compose logs -f messenger_backend | grep "Migration"
```

## Mobile изменения

### Установка нового APK

```powershell
# На Windows ПК (с подключенным телефоном через ADB)
adb install -r _may_messenger_mobile_app\build\app\outputs\flutter-apk\app-release.apk
```

### Ключевые изменения в UI

1. **Вкладки**: "Личные" теперь слева (первая), "Группы" справа (вторая)
2. **Создание групп**: Используются контакты из телефонной книги (как для личных чатов)
3. **Audio player**: Автоматически сбрасывается к началу после окончания воспроизведения
4. **Статусы прочтения**: 
   - Автоматически помечаются при открытии чата
   - Автоматически помечаются при прокрутке до конца
5. **Push уведомления**: При нажатии открывается соответствующий чат с сообщением

## Измененные файлы

### Backend (коммит 30f7509)
- `ChatHub.cs` - групповые статусы с DeliveryReceipts
- `ChatsController.cs` - SignalR событие NewChatCreated
- `Program.cs` - регистрация DeliveryReceiptRepository
- `AppDbContext.cs` - конфигурация DeliveryReceipt
- `IUnitOfWork.cs` + `UnitOfWork.cs` - добавлен DeliveryReceipts репозиторий
- **Новые файлы:**
  - `DeliveryReceipt.cs` - entity для отслеживания статусов
  - `IDeliveryReceiptRepository.cs` - интерфейс репозитория
  - `DeliveryReceiptRepository.cs` - реализация репозитория
  - Миграция `AddDeliveryReceiptEntity`

### Mobile (коммиты 30f7509 + c5f5868)
- `main_screen.dart` - порядок вкладок
- `message_bubble.dart` - сброс audio player
- `chat_screen.dart` - mark as read при прокрутке
- `new_chat_screen.dart` - loadChats после создания
- `main.dart` - navigatorKey и FCM callback
- `messages_provider.dart` - метод markMessagesAsRead
- `signalr_provider.dart` - подписка на NewChatCreated
- `signalr_service.dart` - метод onNewChatCreated
- **Новый файл:**
  - `create_group_screen.dart` - создание групп через контакты
- **Удален:**
  - `create_chat_screen.dart` - старый экран (заменен на create_group_screen)

## Проверка работы

### 1. Новый чат появляется сразу
- Создать личный чат через "Личные" → FAB
- Чат должен появиться в списке без перезапуска

### 2. Создание группы через контакты
- Перейти на вкладку "Группы" → FAB
- Выбрать участников из контактов
- Ввести название группы
- Группа должна появиться в списке сразу

### 3. Статусы прочтения
- Отправить сообщение
- Получатель открывает чат
- Статус меняется на "прочитано" (2 зеленые галочки)
- Счетчик непрочитанных сбрасывается

### 4. Audio player
- Воспроизвести аудио до конца
- Плеер должен сброситься (показать кнопку "play")

### 5. Push навигация
- Получить push уведомление
- Нажать на него
- Должен открыться соответствующий чат с сообщением

### 6. Групповые статусы
- В группе из 3 человек отправить сообщение
- Когда 1 участник получил: статус "delivered" (2 серые галочки)
- Когда все участники прочитали: статус "read" (2 зеленые галочки)

## Коммиты

- `30f7509` - huge fixes (backend + mobile)
- `c5f5868` - mobile improvements (иконки, drawable-v21, удаление старого экрана)
- `fb8a4c0` - sender sees own messages fix

## Важные заметки

1. **Миграция БД обязательна** - без неё backend не запустится
2. **Групповые статусы** требуют DeliveryReceipts в БД
3. **Push навигация** работает только если список чатов обновлен (теперь обновляется автоматически)
4. **drawable-v21** папка необходима для Android 5.0+ (API 21+)
