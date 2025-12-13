# Исправление: Firebase Setup Page 404

## Проблема
При открытии `https://messenger.rare-books.ru/messenger/setup/` возникает ошибка "Firebase setup page not found. Please contact admin."

## Причина
Папка `FirebaseSetup/index.html` не копировалась в Docker образ при сборке, так как не была указана в `.csproj` файле.

## Решение

### Исправлено в MayMessenger.API.csproj
Добавлен `ItemGroup` для копирования папки `FirebaseSetup` в выходной каталог:

```xml
<ItemGroup>
  <Content Include="FirebaseSetup\**\*">
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
  </Content>
</ItemGroup>
```

### Деплой исправления

```bash
cd /root/rarebooks

# 1. Получить изменения
git pull origin master

# 2. Пересобрать backend
docker compose build maymessenger_backend

# 3. Перезапустить
docker compose up -d maymessenger_backend

# 4. Проверить
curl -I https://messenger.rare-books.ru/messenger/setup/
```

### Проверка внутри контейнера

```bash
# Проверить, что файл существует в контейнере
docker exec maymessenger_backend ls -la /app/FirebaseSetup/

# Должен показать:
# -rw-r--r-- 1 root root  XXXX Jan 1 00:00 index.html
```

## Альтернативное решение (если проблема повторится)

Можно также добавить прямое копирование в Dockerfile:

```dockerfile
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Copy Firebase setup files
COPY src/MayMessenger.API/FirebaseSetup /app/FirebaseSetup

# Create wwwroot/audio directory for audio files
RUN mkdir -p /app/wwwroot/audio

ENTRYPOINT ["dotnet", "MayMessenger.API.dll"]
```

Но первый метод (через `.csproj`) более правильный, так как он использует встроенные механизмы .NET.
