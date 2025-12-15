# Инструкция по установке обновления

## Что исправлено
Теперь контакты находятся корректно, независимо от формата номера телефона в телефонной книге:
- ✅ `+7 (909) 492-41-90`
- ✅ `8 (909) 492-41-90`
- ✅ `8-909-492-41-90`
- ✅ Любой другой формат

## Быстрая установка (один шаг)

### 1. Запустите Docker Desktop

### 2. Выполните скрипт:
```powershell
cd c:\rarebooks
.\deploy_phone_normalization.ps1
```

Скрипт автоматически:
- ✅ Обновит backend
- ✅ Пересоздаст хеши номеров в базе данных
- ✅ Установит новое приложение на телефон

### 3. Перезапустите приложение
Полностью закройте и откройте May Messenger на телефоне.

## Проверка работы

### Тест:
1. Зарегистрируйте второго пользователя с номером `+79094924190`
2. Добавьте этот номер в телефонную книгу первого пользователя в любом формате:
   - Например: `8 909 492 41 90`
   - Или: `+7-909-492-41-90`
3. В первом телефоне: откройте May Messenger → "Личные" → "+"
4. **Результат**: Второй пользователь должен появиться в списке контактов

## Если что-то пошло не так

### Скрипт не запускается:
Выполните команды вручную:
```powershell
cd c:\rarebooks

# 1. Собрать backend
docker compose build maymessenger_backend

# 2. Остановить backend
docker compose stop maymessenger_backend

# 3. Применить миграцию базы данных
docker cp _may_messenger_backend\migrations\update_phone_hashes.sql rarebooks-postgres-1:/tmp/update_phone_hashes.sql
docker compose exec -T postgres psql -U postgres -d maymessenger -f /tmp/update_phone_hashes.sql

# 4. Запустить backend
docker compose up -d maymessenger_backend

# 5. Установить приложение
adb install -r _may_messenger_mobile_app\build\app\outputs\flutter-apk\app-release.apk
```

### Контакты всё ещё не находятся:
1. Убедитесь, что приложение полностью перезапущено
2. Убедитесь, что backend обновлён:
   ```powershell
   docker compose logs maymessenger_backend | Select-String "PhoneNumberHelper"
   ```
3. Проверьте логи:
   ```powershell
   curl -k https://messenger.rare-books.ru/api/Diagnostics/logs | ConvertFrom-Json
   ```

## Важно!
После обновления все зарегистрированные пользователи автоматически будут найдены в контактах (если их номера есть в телефонной книге).

## Вопросы?
Все подробности в файле `PHONE_NORMALIZATION_FIX.md`
