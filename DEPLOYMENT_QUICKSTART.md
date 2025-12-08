# 🚀 Быстрый старт: Развертывание May Messenger

## Краткая инструкция

### 📦 1. Подготовка (локально)

```bash
# Создать архив backend
cd _may_messenger_backend
zip -r ../may_messenger_backend.zip .
cd ..
```

### 📤 2. Загрузка на сервер

```bash
# Загрузить все необходимые файлы
scp docker-compose.yml root@217.198.5.89:/root/RareBooksDokploy/docker-compose.yml.new
scp nginx/nginx_prod.conf root@217.198.5.89:/root/RareBooksDokploy/nginx/nginx_prod.conf.new
scp may_messenger_backend.zip root@217.198.5.89:/root/RareBooksDokploy/
scp deploy_maymessenger.sh root@217.198.5.89:/root/RareBooksDokploy/
scp verify_services.sh root@217.198.5.89:/root/RareBooksDokploy/
```

### 🎬 3. Развертывание на сервере

```bash
# Подключиться к серверу
ssh root@217.198.5.89
cd /root/RareBooksDokploy

# Распаковать архив
rm -rf MayMessenger
mkdir -p MayMessenger
unzip -q may_messenger_backend.zip -d MayMessenger/backend

# Применить конфигурации
cp docker-compose.yml.new docker-compose.yml
cp nginx/nginx_prod.conf.new nginx/nginx_prod.conf

# Запустить развертывание
chmod +x deploy_maymessenger.sh
./deploy_maymessenger.sh
```

### ✅ 4. Проверка

```bash
# Запустить проверку
chmod +x verify_services.sh
./verify_services.sh
```

Или вручную:

```bash
# Проверить May Messenger
curl -k https://messenger.rare-books.ru/health
curl -k https://messenger.rare-books.ru/swagger

# Проверить RareBooks
curl -k https://www.rare-books.ru/
```

## 📡 Endpoints

- **May Messenger API**: https://messenger.rare-books.ru/api/
- **May Messenger Swagger**: https://messenger.rare-books.ru/swagger
- **RareBooks**: https://www.rare-books.ru/

## 🔐 Учетные данные

- **Администратор**: +79604243127 / ppAKiH1Y
- **Invite код**: WELCOME2024

## 📚 Полная документация

См. [MAY_MESSENGER_DEPLOYMENT_GUIDE.md](MAY_MESSENGER_DEPLOYMENT_GUIDE.md)

## 🆘 Откат

```bash
chmod +x rollback_deployment.sh
./rollback_deployment.sh
```

## 📊 Мониторинг

```bash
# Статус сервисов
docker compose ps

# Логи May Messenger
docker compose logs -f maymessenger_backend

# Проверка логов
chmod +x check_messenger_logs.sh
./check_messenger_logs.sh
```

