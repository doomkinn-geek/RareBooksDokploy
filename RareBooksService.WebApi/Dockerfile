# --------------------------------------------------
# 1) Этап build: используем .NET 6 SDK, собираем проекты
# --------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src

# Копируем .csproj-файлы для ВСЕХ .NET-проектов, которые должны участвовать в сборке.
# А именно: RareBooksService.WebApi, RareBooksService.Common, RareBooksService.Data, RareBooksService.Parser
# (Не копируем sln, не копируем .esproj-файлы фронтенда и т.д.)
COPY ["RareBooksService.WebApi/RareBooksService.WebApi.csproj", "RareBooksService.WebApi/"]
COPY ["RareBooksService.Common/RareBooksService.Common.csproj", "RareBooksService.Common/"]
COPY ["RareBooksService.Data/RareBooksService.Data.csproj",     "RareBooksService.Data/"]
COPY ["RareBooksService.Parser/RareBooksService.Parser.csproj", "RareBooksService.Parser/"]

# 1a) Выполняем restore для КАЖДОГО нужного .csproj по отдельности, 
# либо, как минимум, для WebApi (который подтянет зависимости на Common/Data/Parser).
# 
# Вариант A: (Лучше, т. к. гарантирует, что все .csproj-зависимости зарезолвятся.)
# RUN dotnet restore "RareBooksService.Common/RareBooksService.Common.csproj"
# RUN dotnet restore "RareBooksService.Data/RareBooksService.Data.csproj"
# RUN dotnet restore "RareBooksService.Parser/RareBooksService.Parser.csproj"
# RUN dotnet restore "RareBooksService.WebApi/RareBooksService.WebApi.csproj"

# Вариант B: (Часто хватает одного restore на проект, в котором ProjectReference на Common/Data/Parser.)
RUN dotnet restore "RareBooksService.WebApi/RareBooksService.WebApi.csproj"

# 2) Копируем весь оставшийся исходный код (все папки RareBooksService.WebApi, .Common, .Data, .Parser)
COPY . .

# Переходим в папку WebApi
WORKDIR /src/RareBooksService.WebApi

# 3) Публикуем в папку /app/out (Release)
RUN dotnet publish -c Release -o /app/out

# --------------------------------------------------
# 2) Этап runtime: .NET 6 ASP.NET
# --------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:6.0
WORKDIR /app

# 4) Копируем результат из предыдущего этапа
COPY --from=build /app/out ./

# Открываем порт 80 внутри контейнера
EXPOSE 80

# 5) Запуск
ENTRYPOINT ["dotnet", "RareBooksService.WebApi.dll"]
