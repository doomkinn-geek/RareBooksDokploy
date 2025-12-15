# Миграция: Нормализация хешей номеров телефонов

## Проблема
Хеши номеров телефонов создавались без нормализации, из-за чего одинаковые номера в разных форматах давали разные хеши:
- `+79094924190` → хеш A
- `8 (909) 492-41-90` → хеш B
- `8-909-492-41-90` → хеш C

## Решение
Добавлена функция нормализации, которая:
1. Удаляет все символы кроме цифр и `+`
2. Заменяет начальную `8` на `+7` (для российских номеров)
3. Добавляет `+` перед номером, начинающимся с `7`

## Применение миграции

### Вариант 1: Через Docker (рекомендуется)
```bash
cd c:\rarebooks
docker compose exec postgres psql -U postgres -d maymessenger -f /docker-entrypoint-initdb.d/update_phone_hashes.sql
```

### Вариант 2: Через psql напрямую
```bash
psql -h localhost -U postgres -d maymessenger -f update_phone_hashes.sql
```

### Вариант 3: Через pgAdmin или DBeaver
1. Откройте файл `update_phone_hashes.sql`
2. Выполните SQL скрипт в базе данных `maymessenger`

## Проверка результата
После выполнения скрипт покажет первые 10 пользователей с их нормализованными номерами и новыми хешами:
```
Id | PhoneNumber | normalized | new_hash
```

## Откат
Если нужно откатить изменения, сохраните старые хеши перед миграцией:
```sql
-- Создать backup таблицу
CREATE TABLE "Users_backup" AS SELECT * FROM "Users";

-- При необходимости восстановить
UPDATE "Users" 
SET "PhoneNumberHash" = b."PhoneNumberHash" 
FROM "Users_backup" b 
WHERE "Users"."Id" = b."Id";
```

## Важно!
После применения миграции необходимо:
1. Перезапустить backend: `docker compose restart maymessenger_backend`
2. Установить новую версию мобильного приложения на все устройства
3. Все пользователи должны обновить приложение одновременно с обновлением backend
