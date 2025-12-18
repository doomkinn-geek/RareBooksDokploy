# Автоматическое применение миграций

## Обзор

May Messenger Backend настроен на **автоматическое применение миграций базы данных** при каждом запуске сервиса.

## Как это работает

При старте приложения в `Program.cs`:

```csharp
// Apply pending migrations automatically on startup
using (var scope = app.Services.CreateScope())
{
    var context = services.GetRequiredService<AppDbContext>();
    
    // Проверка pending миграций
    var pendingMigrations = await context.Database.GetPendingMigrationsAsync();
    
    if (pendingMigrations.Any())
    {
        // Логирование
        logger.LogInformation("Applying {Count} pending database migrations...", 
            pendingMigrations.Count());
        
        // Применение миграций
        await context.Database.MigrateAsync();
        
        logger.LogInformation("Database migrations applied successfully");
    }
}
```

## Преимущества

✅ **Не нужно вручную применять миграции**  
✅ **Автоматическое обновление в Docker/Kubernetes**  
✅ **Защита от запуска с устаревшей схемой БД**  
✅ **Детальное логирование процесса**  
✅ **Безопасный откат при ошибке**

## Логи при запуске

### Когда есть новые миграции:

```
info: Program[0]
      Applying 1 pending database migrations...
info: Program[0]
        - 20241218120000_AddPerformanceIndexes
info: Program[0]
      Database migrations applied successfully
info: Program[0]
      Database is ready. Starting application...
```

### Когда БД актуальна:

```
info: Program[0]
      Database is up to date. No pending migrations.
info: Program[0]
      Database is ready. Starting application...
```

### При ошибке миграции:

```
fail: Program[0]
      An error occurred while migrating or initializing the database.
      System.Exception: ...
```

⚠️ **Важно**: При ошибке миграции приложение **продолжит запуск**, но будет логировать ошибку. Это позволяет:
- Health check endpoint'у отвечать
- Диагностировать проблему через логи
- Не блокировать запуск других контейнеров в Docker Compose

Health check `/health` покажет статус БД как "Unhealthy" если миграции не применились.

## Примеры использования

### Локальная разработка

```bash
cd _may_messenger_backend/src/MayMessenger.API

# Просто запустите - миграции применятся автоматически
dotnet run
```

### Docker

```bash
cd _may_messenger_backend

# Миграции применятся при старте контейнера
docker-compose up -d

# Посмотреть логи миграций
docker-compose logs backend | grep "migration"
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: maymessenger-api
spec:
  template:
    spec:
      containers:
      - name: api
        image: maymessenger/api:latest
        # Миграции применятся автоматически при старте pod
```

## Проверка применённых миграций

### Через логи приложения

```bash
# Docker
docker-compose logs backend | grep "migration"

# Kubernetes
kubectl logs deployment/maymessenger-api | grep "migration"
```

### Через Entity Framework CLI

```bash
cd src/MayMessenger.API

# Список всех миграций
dotnet ef migrations list

# История миграций в БД
dotnet ef database list
```

### Через PostgreSQL

```sql
-- Таблица истории миграций EF Core
SELECT * FROM "__EFMigrationsHistory" ORDER BY "MigrationId";
```

Результат:
```
MigrationId                             | ProductVersion
----------------------------------------|---------------
20251207192606_InitialCreate            | 8.0.0
20251213191331_AddFcmTokens             | 8.0.0
20251213213753_AddContactsAndPhoneN...  | 8.0.0
20251215220542_AddDeliveryReceiptEn...  | 8.0.0
20241218120000_AddPerformanceIndexes    | 8.0.0  ← Новая!
```

## Откат миграции

Если нужно откатить миграцию:

```bash
cd src/MayMessenger.API

# Откат к конкретной миграции
dotnet ef database update 20251215220542_AddDeliveryReceiptEntity

# Остановить приложение, откатить, затем запустить снова
```

## Создание новой миграции

```bash
cd src/MayMessenger.API

# Создать миграцию
dotnet ef migrations add YourMigrationName

# Миграция применится автоматически при следующем запуске приложения!
```

## CI/CD Pipeline

### GitHub Actions пример

```yaml
name: Deploy Backend

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Build Docker image
        run: docker build -t maymessenger/api:latest .
      
      - name: Deploy to production
        run: |
          # Миграции применятся автоматически при запуске контейнера
          docker-compose up -d
          
      - name: Check migration logs
        run: docker-compose logs backend | grep "migration"
```

## Troubleshooting

### Проблема: "Migration already applied"

**Решение**: Это нормально! Если миграция уже применена, она просто пропускается.

### Проблема: "Cannot connect to database"

**Решение**: 
1. Проверьте connection string в `appsettings.json`
2. Убедитесь что PostgreSQL запущен
3. Проверьте доступность порта 5432

```bash
# Проверка подключения
psql -h localhost -U postgres -d maymessenger -c "SELECT 1"
```

### Проблема: "Migration failed, application won't start"

**Решение**:
1. Посмотрите логи для деталей ошибки
2. Возможно нужно откатить проблемную миграцию
3. Исправьте миграцию и пересоздайте её

```bash
# Откат
dotnet ef database update PreviousMigrationName

# Удалить проблемную миграцию
dotnet ef migrations remove

# Создать исправленную версию
dotnet ef migrations add FixedMigrationName
```

## Best Practices

✅ **Всегда тестируйте миграции локально** перед деплоем  
✅ **Делайте backup БД** перед major миграциями  
✅ **Используйте транзакции** в миграциях (EF делает это автоматически)  
✅ **Логируйте все миграции** в CI/CD  
✅ **Мониторьте время выполнения** миграций в production  

## Мониторинг

Добавьте алерт на длительное время старта приложения:

```bash
# Prometheus метрика
startup_duration_seconds{phase="migrations"} > 60
```

Если миграция выполняется дольше минуты - это может указывать на проблемы с индексами или блокировками таблиц.

## Дополнительные ресурсы

- `MIGRATION_GUIDE.md` - Руководство по миграциям
- `INDEXES_README.md` - Документация по индексам
- [EF Core Migrations](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/)
- [Database Migration Best Practices](https://www.postgresql.org/docs/current/ddl.html)

