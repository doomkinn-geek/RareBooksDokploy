# --------------------------------------------------
# 1) Этап build: компиляция .NET 8 SDK, сборка проекта
# --------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Копируем .csproj-файлы для всех .NET-проектов, которые должны быть включены в сборку.
# У нас тут: RareBooksService.WebApi, RareBooksService.Common, RareBooksService.Data, RareBooksService.Parser
# (НЕ включаем sln, НЕ включаем .esproj-файлы фронтенда и т.д.)
COPY ["RareBooksService.WebApi/RareBooksService.WebApi.csproj", "RareBooksService.WebApi/"]
COPY ["RareBooksService.Common/RareBooksService.Common.csproj", "RareBooksService.Common/"]
COPY ["RareBooksService.Data/RareBooksService.Data.csproj",     "RareBooksService.Data/"]
COPY ["RareBooksService.Parser/RareBooksService.Parser.csproj", "RareBooksService.Parser/"]

# 1a) Выполняем restore для основного проекта .csproj со зависимостями, 
# этого, как правило, хватает для WebApi (который содержит зависимости на Common/Data/Parser).
# 
# Вариант A: (можно, т. к. зависимости, что все .csproj-зависимости разрешаются.)
# RUN dotnet restore "RareBooksService.Common/RareBooksService.Common.csproj"
# RUN dotnet restore "RareBooksService.Data/RareBooksService.Data.csproj"
# RUN dotnet restore "RareBooksService.Parser/RareBooksService.Parser.csproj"
# RUN dotnet restore "RareBooksService.WebApi/RareBooksService.WebApi.csproj"

# Вариант B: (более простой вариант restore на проект, у которого ProjectReference на Common/Data/Parser.)
RUN dotnet restore "RareBooksService.WebApi/RareBooksService.WebApi.csproj"

# 2) Копируем весь остальной исходный код (все папки RareBooksService.WebApi, .Common, .Data, .Parser)
COPY . .

# Переходим в папку WebApi
WORKDIR /src/RareBooksService.WebApi

# 3) Публикуем в папку /app/out (Release)
RUN dotnet publish -c Release -o /app/out

# --------------------------------------------------
# 2) Этап runtime: .NET 8 ASP.NET
# --------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app

# 4) Копируем результат с предыдущего этапа
COPY --from=build /app/out ./

# Экспонируем порт 80 внутри контейнера
EXPOSE 80

# 5) Запуск
ENTRYPOINT ["dotnet", "RareBooksService.WebApi.dll"]
