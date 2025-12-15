# Исправление: Поиск контактов по номеру телефона

## Проблема
Контакты не находились из-за различий в форматах номеров телефонов:
- **При регистрации**: `+79094924190` (нормализованный формат)
- **В телефонной книге**: `+7 (909) 492-41-90`, `8-909-492-41-90`, `8 909 492 41 90` и т.д.
- **Результат**: Разные хеши → контакты не находятся

## Решение
Добавлена **единая функция нормализации номеров** перед хешированием:

### Правила нормализации:
1. Удаляет все символы кроме цифр и `+`
2. Заменяет `8` в начале на `+7` (российские номера)
3. Добавляет `+` перед номером, начинающимся с `7`

### Примеры:
```
+7 (909) 492-41-90  → +79094924190
8 (909) 492-41-90   → +79094924190
8-909-492-41-90     → +79094924190
+7-909-492-41-90    → +79094924190
```

## Изменённые файлы

### Backend:
- ✅ `MayMessenger.Infrastructure/Utils/PhoneNumberHelper.cs` (новый файл)
- ✅ `MayMessenger.Infrastructure/Services/AuthService.cs` (нормализация при регистрации)
- ✅ `MayMessenger.API/Controllers/ContactsController.cs` (удалён неиспользуемый метод)

### Mobile:
- ✅ `lib/data/services/contacts_service.dart` (нормализация перед хешированием контактов)

### Миграция:
- ✅ `migrations/update_phone_hashes.sql` (пересоздание хешей для существующих пользователей)
- ✅ `migrations/README_phone_normalization.md` (инструкции)

## Развертывание

### Автоматическое (рекомендуется):
```powershell
cd c:\rarebooks
.\deploy_phone_normalization.ps1
```

Скрипт автоматически:
1. Проверит Docker
2. Соберёт backend
3. Остановит backend для миграции
4. Применит SQL миграцию (пересоздаст хеши)
5. Запустит обновлённый backend
6. Установит APK на подключённое устройство

### Ручное развертывание:

#### 1. Backend:
```powershell
cd c:\rarebooks
# Запустить Docker Desktop

# Собрать и запустить backend
docker compose build maymessenger_backend
docker compose stop maymessenger_backend

# Применить SQL миграцию
docker cp _may_messenger_backend\migrations\update_phone_hashes.sql rarebooks-postgres-1:/tmp/update_phone_hashes.sql
docker compose exec -T postgres psql -U postgres -d maymessenger -f /tmp/update_phone_hashes.sql

# Запустить backend
docker compose up -d maymessenger_backend
```

#### 2. Mobile:
```powershell
# APK уже собран
adb install -r _may_messenger_mobile_app\build\app\outputs\flutter-apk\app-release.apk
```

## Проверка работы

### 1. Регистрация тестового пользователя:
```
Телефон: +79094924190
Имя: Test User
Пароль: test123
```

### 2. Добавить контакт в телефонную книгу:
В любом формате:
- `8 (909) 492-41-90`
- `+7-909-492-41-90`
- `8-909-492-41-90`

### 3. Проверить в приложении:
1. Перейти во вкладку "Личные"
2. Нажать кнопку "+"
3. Контакт "Test User" должен появиться в списке

## Техническая информация

### Алгоритм хеширования:
```
Исходный номер → Нормализация → SHA256 → Hex (lowercase)
```

### Примеры хешей:
```
+79094924190 → SHA256 → e8a6f7b9...
8 909 492 41 90 → нормализация → +79094924190 → SHA256 → e8a6f7b9... (тот же хеш!)
```

### SQL проверка:
```sql
SELECT 
    "PhoneNumber",
    "PhoneNumberHash",
    "DisplayName"
FROM "Users"
WHERE "PhoneNumber" LIKE '%9094924190%';
```

## Важные замечания

1. **Все устройства должны обновиться одновременно**
   - Backend и mobile используют одинаковую логику нормализации
   - Старая версия mobile не будет находить контакты с новыми хешами

2. **SQL миграция обязательна**
   - Пересоздаёт хеши для всех существующих пользователей
   - Без неё старые пользователи не будут найдены

3. **Откат невозможен без backup**
   - Рекомендуется создать backup базы данных перед миграцией
   - См. `migrations/README_phone_normalization.md`

## Диагностика проблем

### Backend не запускается:
```powershell
docker compose logs maymessenger_backend
```

### Контакты всё ещё не находятся:
1. Проверить, что SQL миграция выполнена успешно
2. Проверить логи backend при синхронизации контактов:
   ```powershell
   curl -k https://messenger.rare-books.ru/api/Diagnostics/logs | ConvertFrom-Json
   ```
3. Перезагрузить приложение на телефоне

### Проверить хеш конкретного номера:

**В mobile (Dart):**
```dart
final service = ContactsService(Dio());
final hash = service.hashPhoneNumber('+79094924190');
print(hash);
```

**В backend (C#):**
```csharp
var normalized = PhoneNumberHelper.Normalize("+79094924190");
var hash = ComputeSHA256(normalized);
```

## Статус
✅ **Готово к развертыванию**

- [x] Backend обновлён
- [x] Mobile обновлён
- [x] SQL миграция создана
- [x] Документация готова
- [x] Скрипт развертывания создан
