#!/bin/bash

# Скрипт оптимизированной сборки Docker Compose

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Оптимизированная сборка Docker Compose"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Загружаем переменные окружения, если файл существует
if [ -f "docker-buildkit.env" ]; then
    source docker-buildkit.env
    echo "✓ Загружены переменные из docker-buildkit.env"
else
    # Включаем BuildKit вручную
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    export BUILDKIT_PROGRESS=plain
fi

# Проверяем, что BuildKit доступен
if ! docker buildx version &> /dev/null; then
    echo "⚠️  BuildKit не найден. Производительность может быть ниже."
    echo "   Установите: docker buildx install"
else
    echo "✓ BuildKit: $(docker buildx version | head -1)"
fi

echo "✓ Параллельная сборка: включена"
echo "✓ Кеширование слоев: включено"
echo ""

# Показываем текущий размер образов (если есть)
if docker images | grep -q "rarebooks"; then
    echo "📊 Текущие образы:"
    docker images | grep -E "REPOSITORY|rarebooks" | head -5
    echo ""
fi

# Засекаем время
START_TIME=$(date +%s)

# Сборка с параллелизацией
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Начинаем сборку образов..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

docker compose build --parallel

# Вычисляем время сборки
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Сборка завершена успешно!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⏱️  Время сборки: ${MINUTES}м ${SECONDS}с"
echo ""

# Показываем размеры новых образов
echo "📊 Размеры образов:"
docker images | grep -E "REPOSITORY|rarebooks" | head -5
echo ""

echo "🚀 Следующие шаги:"
echo "   1. Запустить контейнеры:"
echo "      docker compose up -d"
echo ""
echo "   2. Проверить статус:"
echo "      docker compose ps"
echo ""
echo "   3. Посмотреть логи:"
echo "      docker compose logs -f"
echo ""

