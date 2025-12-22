FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 5000
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Install EF Core tools (for migration creation during development/debug)
# Note: In production, migrations are created locally and applied automatically on startup
RUN dotnet tool install --global dotnet-ef --version 8.0.*
ENV PATH="$PATH:/root/.dotnet/tools"

# Copy csproj files and restore
COPY ["src/MayMessenger.API/MayMessenger.API.csproj", "src/MayMessenger.API/"]
COPY ["src/MayMessenger.Application/MayMessenger.Application.csproj", "src/MayMessenger.Application/"]
COPY ["src/MayMessenger.Domain/MayMessenger.Domain.csproj", "src/MayMessenger.Domain/"]
COPY ["src/MayMessenger.Infrastructure/MayMessenger.Infrastructure.csproj", "src/MayMessenger.Infrastructure/"]

RUN dotnet restore "src/MayMessenger.API/MayMessenger.API.csproj"

# Copy everything else and build
COPY . .
WORKDIR "/src/src/MayMessenger.API"
RUN dotnet build "MayMessenger.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "MayMessenger.API.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Create wwwroot directories for media files (matches volume mounts)
RUN mkdir -p /app/wwwroot/audio && \
    mkdir -p /app/wwwroot/images

ENTRYPOINT ["dotnet", "MayMessenger.API.dll"]


