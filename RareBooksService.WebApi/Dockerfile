# --------------------------------------------------
# 1) Этап build: компиляция .NET 8 SDK, сборка проекта
# --------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Копируем .csproj-файлы для всех .NET-проектов (для кеширования слоя restore)
COPY ["RareBooksService.WebApi/RareBooksService.WebApi.csproj", "RareBooksService.WebApi/"]
COPY ["RareBooksService.Common/RareBooksService.Common.csproj", "RareBooksService.Common/"]
COPY ["RareBooksService.Data/RareBooksService.Data.csproj",     "RareBooksService.Data/"]
COPY ["RareBooksService.Parser/RareBooksService.Parser.csproj", "RareBooksService.Parser/"]

# Восстанавливаем зависимости (кешируется при неизменных .csproj)
RUN dotnet restore "RareBooksService.WebApi/RareBooksService.WebApi.csproj" --runtime linux-x64

# Копируем ТОЛЬКО нужные папки для backend (избегаем копирования frontend)
COPY ["RareBooksService.WebApi/", "RareBooksService.WebApi/"]
COPY ["RareBooksService.Common/", "RareBooksService.Common/"]
COPY ["RareBooksService.Data/", "RareBooksService.Data/"]
COPY ["RareBooksService.Parser/", "RareBooksService.Parser/"]

# Переходим в папку WebApi
WORKDIR /src/RareBooksService.WebApi

# Публикуем в папку /app/out с оптимизациями
RUN dotnet publish -c Release -o /app/out \
    --runtime linux-x64 \
    --self-contained false \
    --no-restore

# --------------------------------------------------
# 2) Этап runtime: .NET 8 ASP.NET
# --------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app

# 4) Копируем результат с предыдущего этапа
COPY --from=build /app/out ./

# Устанавливаем curl для healthcheck внутри контейнера
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Экспонируем порт 80 внутри контейнера
EXPOSE 80

# 5) Запуск
ENTRYPOINT ["dotnet", "RareBooksService.WebApi.dll"]
