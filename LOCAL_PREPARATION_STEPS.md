# Шаги подготовки на локальной машине (Windows)

## 📋 Что было изменено

### Основные конфигурационные файлы:
1. ✅ `docker-compose.yml` - добавлены сервисы May Messenger
2. ✅ `nginx/nginx_prod.conf` - добавлена конфигурация для messenger.rare-books.ru

### Созданные скрипты развертывания:
1. ✅ `deploy_maymessenger.sh` - автоматическое развертывание
2. ✅ `verify_services.sh` - проверка работоспособности
3. ✅ `check_messenger_logs.sh` - просмотр и анализ логов
4. ✅ `rollback_deployment.sh` - откат изменений
5. ✅ `prepare_deployment_package.sh` - подготовка пакета

### Созданная документация:
1. ✅ `MAY_MESSENGER_DEPLOYMENT_GUIDE.md` - полное руководство
2. ✅ `DEPLOYMENT_QUICKSTART.md` - краткая инструкция
3. ✅ `CHANGES_SUMMARY.md` - резюме изменений
4. ✅ `LOCAL_PREPARATION_STEPS.md` - этот файл

---

## 🚀 Что нужно сделать сейчас

### Шаг 1: Создать архив backend мессенджера

#### В PowerShell:

```powershell
cd D:\_SOURCES\source\RareBooksServicePublic
cd _may_messenger_backend
Compress-Archive -Path * -DestinationPath ..\may_messenger_backend.zip -Force
cd ..
```

#### Или в Git Bash:

```bash
cd /d/_SOURCES/source/RareBooksServicePublic
cd _may_messenger_backend
zip -r ../may_messenger_backend.zip . -x "*.git*" "*/bin/*" "*/obj/*"
cd ..
```

#### Или используйте скрипт:

```bash
# В Git Bash
./prepare_deployment_package.sh
```

### Шаг 2: Загрузить файлы на сервер

Откройте **PowerShell** или **Git Bash** и выполните:

```bash
# Установите правильный путь к вашим файлам
cd D:\_SOURCES\source\RareBooksServicePublic

# Загрузка основных конфигураций
scp docker-compose.yml root@217.198.5.89:/root/RareBooksDokploy/docker-compose.yml.new
scp nginx/nginx_prod.conf root@217.198.5.89:/root/RareBooksDokploy/nginx/nginx_prod.conf.new

# Загрузка архива backend
scp may_messenger_backend.zip root@217.198.5.89:/root/RareBooksDokploy/

# Загрузка скриптов
scp deploy_maymessenger.sh root@217.198.5.89:/root/RareBooksDokploy/
scp verify_services.sh root@217.198.5.89:/root/RareBooksDokploy/
scp check_messenger_logs.sh root@217.198.5.89:/root/RareBooksDokploy/
scp rollback_deployment.sh root@217.198.5.89:/root/RareBooksDokploy/
```

**Примечание**: Вам будет предложено ввести пароль root пользователя для каждого файла.

### Альтернатива: Используйте SFTP клиент

Если предпочитаете GUI:

1. Откройте **WinSCP** или **FileZilla**
2. Подключитесь к серверу:
   - Host: `217.198.5.89`
   - User: `root`
   - Port: `22`
3. Перейдите в `/root/RareBooksDokploy/`
4. Загрузите файлы:
   - `docker-compose.yml` → `docker-compose.yml.new`
   - `nginx/nginx_prod.conf` → `nginx/nginx_prod.conf.new`
   - `may_messenger_backend.zip`
   - Все скрипты `.sh`

---

## 📝 Чек-лист перед загрузкой

Убедитесь, что следующие файлы существуют и актуальны:

### Обязательные файлы:
- [ ] `docker-compose.yml` (обновлен с сервисами May Messenger)
- [ ] `nginx/nginx_prod.conf` (обновлен с конфигурацией messenger.rare-books.ru)
- [ ] `may_messenger_backend.zip` (архив создан из `_may_messenger_backend/`)

### Скрипты (рекомендуется):
- [ ] `deploy_maymessenger.sh`
- [ ] `verify_services.sh`
- [ ] `check_messenger_logs.sh`
- [ ] `rollback_deployment.sh`

### Документация (опционально):
- [ ] `MAY_MESSENGER_DEPLOYMENT_GUIDE.md`
- [ ] `DEPLOYMENT_QUICKSTART.md`
- [ ] `CHANGES_SUMMARY.md`

---

## 🔍 Проверка файлов

### Проверить размер архива

```powershell
# В PowerShell
Get-Item may_messenger_backend.zip | Select-Object Name, Length
```

Архив должен быть несколько МБ (примерно 5-20 МБ).

### Проверить содержимое архива

```powershell
# В PowerShell
Expand-Archive may_messenger_backend.zip -DestinationPath .\test_extract -Force
Get-ChildItem .\test_extract -Recurse
Remove-Item .\test_extract -Recurse -Force
```

Должна быть следующая структура:
```
Dockerfile
MayMessenger.sln
src/
  MayMessenger.API/
  MayMessenger.Application/
  MayMessenger.Domain/
  MayMessenger.Infrastructure/
```

---

## ⏭️ Следующие шаги

После загрузки файлов на сервер:

1. **Подключитесь к серверу**:
   ```bash
   ssh root@217.198.5.89
   ```

2. **Перейдите в директорию проекта**:
   ```bash
   cd /root/RareBooksDokploy
   ```

3. **Следуйте инструкциям** из [DEPLOYMENT_QUICKSTART.md](DEPLOYMENT_QUICKSTART.md)

---

## 🆘 Помощь

### Если возникли проблемы с созданием архива

```powershell
# Проверьте, что вы в правильной директории
Get-Location

# Проверьте наличие _may_messenger_backend
Test-Path _may_messenger_backend

# Создайте архив с явным указанием путей
Compress-Archive -Path _may_messenger_backend\* -DestinationPath may_messenger_backend.zip -Force
```

### Если возникли проблемы с SCP

```bash
# Проверьте подключение к серверу
ssh root@217.198.5.89 "echo 'Connection OK'"

# Попробуйте загрузить один файл для теста
scp docker-compose.yml root@217.198.5.89:/tmp/test.yml

# Если работает, удалите тестовый файл
ssh root@217.198.5.89 "rm /tmp/test.yml"
```

### Если нужна помощь с SSH ключами

```bash
# Проверьте наличие SSH ключей
ls ~/.ssh/

# Если ключей нет, сгенерируйте новый
ssh-keygen -t ed25519 -C "your_email@example.com"

# Скопируйте ключ на сервер
ssh-copy-id root@217.198.5.89
```

---

## 📚 Дополнительная информация

### Полная документация
См. [MAY_MESSENGER_DEPLOYMENT_GUIDE.md](MAY_MESSENGER_DEPLOYMENT_GUIDE.md)

### Краткая инструкция
См. [DEPLOYMENT_QUICKSTART.md](DEPLOYMENT_QUICKSTART.md)

### Резюме изменений
См. [CHANGES_SUMMARY.md](CHANGES_SUMMARY.md)

---

## ✅ Готово к развертыванию

После выполнения всех шагов выше:

1. ✅ Архив `may_messenger_backend.zip` создан
2. ✅ Все файлы загружены на сервер
3. ✅ Готовы к запуску развертывания на сервере

**Следующий шаг**: Подключитесь к серверу и запустите `./deploy_maymessenger.sh`

---

**Дата создания**: Декабрь 2024  
**Версия**: 1.0

