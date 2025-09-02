#!/bin/bash
echo "Перезапуск nginx контейнера..."
docker restart nginx_container
echo "Ожидание запуска nginx..."
sleep 5
echo "Проверка статуса nginx..."
docker ps | grep nginx_container
echo ""
echo "Nginx перезапущен! Теперь попробуйте снова выполнить инициализацию."
