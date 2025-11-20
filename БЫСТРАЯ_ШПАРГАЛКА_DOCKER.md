# ⚡ Быстрая шпаргалка Docker оптимизации

## 🚀 Начало работы (5 минут)

### Ubuntu/Linux:
```bash
# Шаг 1: Настройка (только один раз)
chmod +x setup-docker-optimization.sh
sudo ./setup-docker-optimization.sh
source ~/.bashrc

# Шаг 2: Сборка
chmod +x build-optimized.sh
./build-optimized.sh

# Шаг 3: Запуск
docker compose up -d
```

### Windows PowerShell:
```powershell
# Шаг 1: Настройка (только один раз)
# Добавьте в %USERPROFILE%\.docker\daemon.json:
# { "features": { "buildkit": true } }
# Перезапустите Docker Desktop

# Шаг 2: Сборка
.\build-optimized.ps1

# Шаг 3: Запуск
docker compose up -d
```

---

## 📝 Основные команды

```bash
# Оптимизированная сборка
./build-optimized.sh                    # Linux/Mac
.\build-optimized.ps1                   # Windows

# Сборка без кеша (если нужно)
docker compose build --no-cache --parallel

# Сборка только одного сервиса
docker compose build backend
docker compose build frontend

# Запуск
docker compose up -d                    # В фоне
docker compose up                       # С выводом логов

# Остановка
docker compose down                     # Остановка
docker compose down -v                  # Остановка + удаление volumes

# Перезапуск
docker compose restart                  # Перезапуск всех
docker compose restart backend          # Перезапуск одного

# Логи
docker compose logs -f                  # Все логи
docker compose logs -f backend          # Только backend
docker compose logs --tail=100 backend  # Последние 100 строк

# Статус
docker compose ps                       # Статус контейнеров
docker compose images                   # Образы
```

---

## 🔍 Диагностика

```bash
# Проверить BuildKit
docker buildx version

# Проверить размер образов
docker images | grep rarebooks

# Проверить использование диска
docker system df
docker system df -v

# Время сборки
time docker compose build

# Подробные логи сборки
docker compose build --progress=plain > build.log 2>&1

# Проверить кеш (должно быть много CACHED)
docker compose build --progress=plain 2>&1 | grep CACHED
```

---

## 🧹 Очистка

```bash
# Легкая очистка (неиспользуемое)
docker system prune -f

# Полная очистка (осторожно!)
docker system prune -af --volumes

# Очистка только build cache
docker builder prune -af

# Удалить конкретные образы
docker rmi rarebooks_backend:latest
docker rmi rarebooks_frontend:latest

# Удалить все остановленные контейнеры
docker compose down -v
```

---

## 🐛 Быстрое решение проблем

### Сборка медленная?
```bash
# 1. Включить BuildKit
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# 2. Очистить кеш
docker builder prune -af
docker system prune -af

# 3. Пересобрать
./build-optimized.sh
```

### Ошибка при сборке?
```bash
# 1. Очистить все
docker compose down -v
docker system prune -af

# 2. Собрать без кеша
docker compose build --no-cache

# 3. Запустить
docker compose up -d
```

### Контейнер не запускается?
```bash
# 1. Проверить логи
docker compose logs backend
docker compose logs frontend

# 2. Проверить healthcheck
docker compose ps

# 3. Перезапустить
docker compose restart backend
```

### Нет места на диске?
```bash
# 1. Проверить использование
docker system df

# 2. Удалить неиспользуемое
docker system prune -af --volumes

# 3. Удалить старые образы
docker image prune -af
```

---

## 📊 Мониторинг

```bash
# Статус в реальном времени
watch docker compose ps

# Использование ресурсов
docker stats

# Использование диска
docker system df -v

# Проверить health
docker compose ps --format "table {{.Name}}\t{{.Status}}"
```

---

## 🎯 Лучшие практики

1. **Всегда используйте `build-optimized.sh`** вместо обычного `docker compose build`
2. **Регулярно чистите** неиспользуемые образы и кеш
3. **Проверяйте логи** при проблемах: `docker compose logs -f`
4. **Используйте healthcheck** перед деплоем: `docker compose ps`
5. **Делайте backup** volumes перед `docker compose down -v`

---

## 🆘 Аварийное восстановление

```bash
# ПОЛНАЯ очистка и пересборка (ОСТОРОЖНО!)

# 1. Остановить все
docker compose down -v

# 2. Удалить все контейнеры
docker rm -f $(docker ps -aq)

# 3. Удалить все образы
docker rmi -f $(docker images -q)

# 4. Очистить все
docker system prune -af --volumes

# 5. Пересобрать
./build-optimized.sh

# 6. Запустить
docker compose up -d
```

---

## 📞 Нужна помощь?

- Подробное руководство: `DOCKER_OPTIMIZATION_GUIDE.md`
- Резюме изменений: `ОПТИМИЗАЦИЯ_DOCKER_РЕЗЮМЕ.md`
- Быстрое развертывание: `QUICK_OPTIMIZATION_DEPLOY.md`

---

## 🎉 Ожидаемые результаты

✅ Первая сборка: **3-5 минут**  
✅ Повторная сборка: **< 1 минуты**  
✅ Размер контекста: **↓ 80%**  
✅ Использование кеша: **90%+**

