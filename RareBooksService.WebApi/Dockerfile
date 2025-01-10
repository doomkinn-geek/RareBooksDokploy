# --------------------------------------------------
# 1) Этап build: используем .NET 6 SDK, собираем проекты
# --------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src

# Копируем все нужные .csproj
COPY ["RareBooksService.WebApi/RareBooksService.WebApi.csproj", "RareBooksService.WebApi/"]
COPY ["RareBooksService.Common/RareBooksService.Common.csproj", "RareBooksService.Common/"]
COPY ["RareBooksService.Data/RareBooksService.Data.csproj",       "RareBooksService.Data/"]
COPY ["RareBooksService.Parser/RareBooksService.Parser.csproj",   "RareBooksService.Parser/"]

# Выполняем restore (тянем nuget-пакеты)
RUN dotnet restore "RareBooksService.WebApi/RareBooksService.WebApi.csproj"

# Копируем оставшиеся файлы (весь исходный код)
COPY . .

# Переходим в папку WebApi
WORKDIR /src/RareBooksService.WebApi

# Публикуем в папку /app/out (Release)
RUN dotnet publish -c Release -o /app/out

# --------------------------------------------------
# 2) Этап runtime: .NET 6 ASP.NET
# --------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:6.0
WORKDIR /app

# Копируем результат из предыдущего этапа
COPY --from=build /app/out ./

# Открываем порт 80 внутри контейнера
EXPOSE 80

# Запуск
ENTRYPOINT ["dotnet", "RareBooksService.WebApi.dll"]
