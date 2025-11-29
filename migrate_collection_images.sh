#!/bin/bash

# Скрипт миграции изображений коллекций в Docker volume
# Использование: ./migrate_collection_images.sh

set -e  # Остановиться при ошибке

echo "🚀 Начало миграции изображений коллекций в Docker volume"
echo "=================================================="
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Имена контейнеров и путей
BACKEND_CONTAINER="rarebooks_backend"
SOURCE_PATH="/app/wwwroot/collection_images"
TEMP_DIR="$HOME/temp_collection_images_backup_$(date +%Y%m%d_%H%M%S)"

# Проверка, что контейнер существует
if ! docker ps -a --format '{{.Names}}' | grep -q "^${BACKEND_CONTAINER}$"; then
    echo -e "${RED}❌ Контейнер ${BACKEND_CONTAINER} не найден!${NC}"
    echo "Убедитесь, что Docker контейнеры запущены."
    exit 1
fi

echo -e "${YELLOW}Шаг 1: Проверка наличия изображений в старом контейнере...${NC}"
if docker exec $BACKEND_CONTAINER test -d $SOURCE_PATH; then
    IMAGE_COUNT=$(docker exec $BACKEND_CONTAINER find $SOURCE_PATH -type f 2>/dev/null | wc -l)
    if [ "$IMAGE_COUNT" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  В контейнере нет изображений для миграции.${NC}"
        echo "Продолжить с обновлением конфигурации? (y/n)"
        read -r CONTINUE
        if [ "$CONTINUE" != "y" ]; then
            echo "Миграция отменена."
            exit 0
        fi
    else
        echo -e "${GREEN}✅ Найдено изображений: $IMAGE_COUNT${NC}"
        
        # Создаем временную директорию
        echo -e "${YELLOW}Шаг 2: Создание временной директории для backup...${NC}"
        mkdir -p "$TEMP_DIR"
        echo -e "${GREEN}✅ Создана: $TEMP_DIR${NC}"
        
        # Копируем изображения из контейнера
        echo -e "${YELLOW}Шаг 3: Копирование изображений из контейнера...${NC}"
        docker cp "${BACKEND_CONTAINER}:${SOURCE_PATH}/." "$TEMP_DIR/"
        echo -e "${GREEN}✅ Изображения скопированы${NC}"
        
        # Показываем размер
        BACKUP_SIZE=$(du -sh "$TEMP_DIR" | cut -f1)
        echo -e "${GREEN}   Размер backup: $BACKUP_SIZE${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Директория с изображениями не найдена в контейнере.${NC}"
    IMAGE_COUNT=0
fi

echo ""
echo -e "${YELLOW}Шаг 4: Остановка контейнеров...${NC}"
docker compose down
echo -e "${GREEN}✅ Контейнеры остановлены${NC}"

echo ""
echo -e "${YELLOW}Шаг 5: Пересоздание контейнеров с новой конфигурацией...${NC}"
docker compose up -d --build
echo -e "${GREEN}✅ Контейнеры пересозданы${NC}"

# Ждем, пока контейнер backend станет здоровым
echo ""
echo -e "${YELLOW}Шаг 6: Ожидание готовности backend (может занять до 2 минут)...${NC}"
COUNTER=0
MAX_WAIT=120
while [ $COUNTER -lt $MAX_WAIT ]; do
    if docker inspect --format='{{.State.Health.Status}}' $BACKEND_CONTAINER 2>/dev/null | grep -q "healthy"; then
        echo -e "${GREEN}✅ Backend готов к работе${NC}"
        break
    fi
    echo -n "."
    sleep 5
    COUNTER=$((COUNTER + 5))
done

if [ $COUNTER -ge $MAX_WAIT ]; then
    echo -e "${RED}❌ Backend не стал здоровым за отведенное время${NC}"
    echo "Проверьте логи: docker logs $BACKEND_CONTAINER"
    echo "Backup изображений сохранен в: $TEMP_DIR"
    exit 1
fi

# Если были изображения, копируем их обратно
if [ "$IMAGE_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Шаг 7: Копирование изображений в новый volume...${NC}"
    docker cp "$TEMP_DIR/." "${BACKEND_CONTAINER}:${SOURCE_PATH}/"
    echo -e "${GREEN}✅ Изображения скопированы в volume${NC}"
    
    echo ""
    echo -e "${YELLOW}Шаг 8: Установка правильных прав доступа...${NC}"
    docker exec $BACKEND_CONTAINER chown -R app:app $SOURCE_PATH 2>/dev/null || \
    docker exec $BACKEND_CONTAINER chown -R www-data:www-data $SOURCE_PATH 2>/dev/null || \
    echo -e "${YELLOW}⚠️  Не удалось установить владельца (возможно, не требуется)${NC}"
    
    docker exec $BACKEND_CONTAINER chmod -R 755 $SOURCE_PATH
    echo -e "${GREEN}✅ Права доступа установлены${NC}"
    
    echo ""
    echo -e "${YELLOW}Шаг 9: Проверка миграции...${NC}"
    NEW_IMAGE_COUNT=$(docker exec $BACKEND_CONTAINER find $SOURCE_PATH -type f 2>/dev/null | wc -l)
    
    if [ "$NEW_IMAGE_COUNT" -eq "$IMAGE_COUNT" ]; then
        echo -e "${GREEN}✅ Миграция успешна! Скопировано файлов: $NEW_IMAGE_COUNT${NC}"
    else
        echo -e "${RED}❌ Количество файлов не совпадает!${NC}"
        echo "   Ожидалось: $IMAGE_COUNT"
        echo "   Найдено: $NEW_IMAGE_COUNT"
        echo -e "${YELLOW}   Backup сохранен в: $TEMP_DIR${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${YELLOW}Шаг 10: Очистка временных файлов...${NC}"
    echo "Удалить временный backup? (y/n)"
    echo -e "${YELLOW}Путь: $TEMP_DIR${NC}"
    read -r DELETE_BACKUP
    
    if [ "$DELETE_BACKUP" = "y" ]; then
        rm -rf "$TEMP_DIR"
        echo -e "${GREEN}✅ Временные файлы удалены${NC}"
    else
        echo -e "${YELLOW}⚠️  Backup сохранен в: $TEMP_DIR${NC}"
        echo "   Не забудьте удалить его позже!"
    fi
fi

echo ""
echo "=================================================="
echo -e "${GREEN}🎉 Миграция завершена успешно!${NC}"
echo ""
echo "Проверка конфигурации:"
echo "  • Docker volume создан: $(docker volume ls | grep collection_images | awk '{print $2}')"
echo "  • Изображений в volume: $(docker exec $BACKEND_CONTAINER find $SOURCE_PATH -type f 2>/dev/null | wc -l)"
echo "  • Размер volume: $(docker exec $BACKEND_CONTAINER du -sh $SOURCE_PATH 2>/dev/null | cut -f1)"
echo ""
echo "Дополнительные команды:"
echo "  • Просмотр логов backend: docker logs -f $BACKEND_CONTAINER"
echo "  • Просмотр изображений: docker exec $BACKEND_CONTAINER ls -la $SOURCE_PATH"
echo "  • Создать backup: docker run --rm -v rarebooksdokploy_collection_images:/source:ro -v \$(pwd):/backup alpine tar czf /backup/collection_backup.tar.gz -C /source ."
echo ""
echo -e "${GREEN}✨ Теперь изображения сохранятся при обновлении кода!${NC}"

