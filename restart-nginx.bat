@echo off
echo Перезапуск nginx контейнера...
docker restart nginx_container
echo Ожидание запуска nginx...
timeout /t 5 /nobreak > nul
echo Проверка статуса nginx...
docker ps | findstr nginx_container
echo.
echo Nginx перезапущен! Теперь попробуйте снова выполнить инициализацию.
pause
