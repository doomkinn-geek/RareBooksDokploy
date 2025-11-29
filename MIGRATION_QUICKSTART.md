# Быстрая миграция изображений в Docker Volume

## 🚀 Быстрый старт (Windows)

### Если изображений еще НЕТ (новая установка):

```powershell
# Просто пересоздайте контейнеры
docker-compose down
docker-compose up -d --build
```

✅ Готово! Все новые изображения будут сохраняться в отдельном volume.

---

### Если изображения УЖЕ ЕСТЬ (миграция):

#### Вариант 1: Автоматическая миграция (рекомендуется)

```powershell
# Запустите скрипт миграции
.\migrate_collection_images.ps1
```

Скрипт автоматически:
1. Создаст backup изображений
2. Пересоздаст контейнеры
3. Скопирует изображения в новый volume
4. Проверит корректность миграции

#### Вариант 2: Ручная миграция

```powershell
# 1. Создайте backup
$backupDir = "$env:USERPROFILE\collection_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -Path $backupDir -ItemType Directory -Force
docker cp rarebooks_backend:/app/wwwroot/collection_images/. $backupDir/

# 2. Пересоздайте контейнеры
docker-compose down
docker-compose up -d --build

# 3. Дождитесь готовности backend (2-3 минуты)
# Проверяйте статус:
docker ps

# 4. Скопируйте изображения обратно
docker cp $backupDir/. rarebooks_backend:/app/wwwroot/collection_images/

# 5. Установите права (опционально)
docker exec rarebooks_backend chmod -R 755 /app/wwwroot/collection_images

# 6. Проверьте
docker exec rarebooks_backend ls -la /app/wwwroot/collection_images

# 7. Удалите backup (после проверки)
Remove-Item -Path $backupDir -Recurse -Force
```

---

## 🔍 Проверка работы

### Проверить, что volume создан:

```powershell
docker volume ls | findstr collection_images
```

Должно быть: `rarebooksdokploy_collection_images`

### Проверить количество изображений:

```powershell
docker exec rarebooks_backend find /app/wwwroot/collection_images -type f | Measure-Object -Line
```

### Проверить размер:

```powershell
docker exec rarebooks_backend du -sh /app/wwwroot/collection_images
```

---

## 🧪 Тест надежности

Проверьте, что изображения НЕ теряются при пересоздании контейнера:

```powershell
# 1. Запомните количество изображений
$beforeCount = (docker exec rarebooks_backend find /app/wwwroot/collection_images -type f | Measure-Object -Line).Lines
Write-Host "До пересоздания: $beforeCount изображений"

# 2. Пересоздайте backend
docker-compose restart backend

# 3. Дождитесь готовности (1-2 минуты)
Start-Sleep -Seconds 120

# 4. Проверьте количество снова
$afterCount = (docker exec rarebooks_backend find /app/wwwroot/collection_images -type f | Measure-Object -Line).Lines
Write-Host "После пересоздания: $afterCount изображений"

# 5. Сравните
if ($beforeCount -eq $afterCount) {
    Write-Host "✅ Изображения сохранились!" -ForegroundColor Green
} else {
    Write-Host "❌ Изображения потеряны!" -ForegroundColor Red
}
```

---

## 💾 Резервное копирование

### Создать backup всех изображений:

```powershell
# В текущую директорию
docker run --rm `
  -v rarebooksdokploy_collection_images:/source:ro `
  -v ${PWD}:/backup `
  alpine tar czf /backup/collection_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').tar.gz -C /source .
```

### Восстановить из backup:

```powershell
# Замените FILENAME на имя вашего backup файла
docker run --rm `
  -v rarebooksdokploy_collection_images:/target `
  -v ${PWD}:/backup `
  alpine sh -c "cd /target && tar xzf /backup/FILENAME.tar.gz"
```

---

## 🐧 Linux / macOS

### Быстрая миграция:

```bash
# Запустите скрипт
chmod +x migrate_collection_images.sh
./migrate_collection_images.sh
```

### Или вручную:

```bash
# 1. Backup
docker cp rarebooks_backend:/app/wwwroot/collection_images ~/collection_backup

# 2. Пересоздание
docker-compose down && docker-compose up -d --build

# 3. Восстановление
docker cp ~/collection_backup/. rarebooks_backend:/app/wwwroot/collection_images/

# 4. Права
docker exec rarebooks_backend chown -R app:app /app/wwwroot/collection_images
docker exec rarebooks_backend chmod -R 755 /app/wwwroot/collection_images
```

---

## ⚠️ Важные заметки

### 1. При первом запуске после изменений:

```powershell
# Пересоздайте контейнеры с --build
docker-compose up -d --build
```

### 2. Если изображения не отображаются:

```powershell
# Проверьте права доступа
docker exec rarebooks_backend ls -la /app/wwwroot/collection_images

# Исправьте права
docker exec rarebooks_backend chmod -R 755 /app/wwwroot/collection_images
```

### 3. Место на диске:

```powershell
# Проверьте использование дискового пространства
docker system df -v | findstr collection
```

---

## 🆘 Troubleshooting

### Проблема: "Cannot connect to the Docker daemon"

**Решение:** Запустите Docker Desktop

### Проблема: Volume не создается

```powershell
# Проверьте docker-compose.yml
docker-compose config

# Пересоздайте с нуля
docker-compose down -v  # ОСТОРОЖНО: удалит все volumes!
docker-compose up -d --build
```

### Проблема: "Permission denied" при записи

```powershell
# Исправьте права
docker exec rarebooks_backend chmod -R 777 /app/wwwroot/collection_images
```

---

## 📊 Что изменилось

### В `docker-compose.yml`:

```yaml
backend:
  # ... другие настройки ...
  volumes:
    # НОВАЯ СТРОКА: постоянное хранилище для изображений
    - collection_images:/app/wwwroot/collection_images

# ... другие сервисы ...

volumes:
  db_books_data:
  db_users_data:
  collection_images:  # НОВЫЙ VOLUME
```

### Теперь структура хранения:

```
Docker Volumes (Persistent):
├─ db_books_data     → База данных книг
├─ db_users_data     → База данных пользователей
└─ collection_images → Изображения коллекций ✨ НОВОЕ!
```

---

## ✅ После миграции

Изображения теперь:
- ✅ **Сохраняются** при пересоздании контейнеров
- ✅ **Не затираются** при изменении кода
- ✅ **Хранятся отдельно** от кода приложения
- ✅ **Можно легко бэкапить** через Docker volume

🎉 **Проблема решена!**

