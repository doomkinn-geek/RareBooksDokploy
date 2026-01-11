# Firebase iOS Configuration

## Где разместить GoogleService-Info.plist

После скачивания `GoogleService-Info.plist` из Firebase Console, разместите его здесь:

```
_may_messenger_mobile_app/ios/Runner/GoogleService-Info.plist
```

## Как получить GoogleService-Info.plist

1. Откройте [Firebase Console](https://console.firebase.google.com/)
2. Выберите ваш проект (MayMessenger)
3. Перейдите в **Project Settings** (значок шестерёнки)
4. Прокрутите вниз до секции **Your apps**
5. Выберите ваше iOS приложение (или добавьте новое, если нужно)
   - Bundle ID: `com.maymessenger.mobileApp`
6. Нажмите **Download GoogleService-Info.plist**
7. Скопируйте файл в `_may_messenger_mobile_app/ios/Runner/GoogleService-Info.plist`

## Важно: Добавление в Xcode

**После копирования файла необходимо добавить его в Xcode проект:**

1. Откройте `ios/Runner.xcworkspace` в Xcode
2. Правый клик на папке **Runner** → **Add Files to "Runner"...**
3. Выберите `GoogleService-Info.plist`
4. Убедитесь, что отмечено:
   - ✅ Copy items if needed
   - ✅ Runner в секции "Add to targets"
5. Нажмите **Add**

## Важные замечания

- **НЕ** добавляйте этот файл в git (он уже в `.gitignore`)
- Файл содержит конфиденциальную конфигурацию Firebase
- Храните резервную копию в безопасном месте
- Каждому разработчику нужна своя копия для локальной разработки

## Проверка содержимого

После размещения файла убедитесь, что он содержит:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>BUNDLE_ID</key>
    <string>com.maymessenger.mobileApp</string>
    <key>PROJECT_ID</key>
    <string>your-project-id</string>
    <key>GOOGLE_APP_ID</key>
    <string>1:xxxx:ios:xxxx</string>
    ...
</dict>
</plist>
```

**Bundle ID ДОЛЖЕН совпадать с** `com.maymessenger.mobileApp`.

## Настройка Push Notifications

Для работы push-уведомлений на iOS:

1. В Apple Developer Portal создайте APNs Key
2. Скачайте .p8 файл ключа
3. В Firebase Console → Project Settings → Cloud Messaging
4. Загрузите .p8 ключ, укажите Key ID и Team ID

Подробная инструкция в файле `IOS_DEPLOYMENT_GUIDE.md`.
