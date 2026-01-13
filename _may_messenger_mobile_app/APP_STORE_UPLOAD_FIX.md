# Исправление ошибки загрузки в App Store

## Проблема
При загрузке IPA через Apple Transporter возникала ошибка:
```
Validation failed (409)
Missing Info.plist value. The Info.plist key 'BGTaskSchedulerPermittedIdentifiers' 
must contain a list of identifiers used to submit and handle tasks when 
'UIBackgroundModes' has a value of 'processing'.
```

## Причина
В `ios/Runner/Info.plist` был указан фоновый режим `processing` в `UIBackgroundModes`, но отсутствовал обязательный ключ `BGTaskSchedulerPermittedIdentifiers`.

## Решение
Удален режим `processing` из `UIBackgroundModes`, так как для мессенджера достаточно:
- `audio` - для воспроизведения голосовых сообщений в фоне
- `fetch` - для фоновых обновлений
- `remote-notification` - для push-уведомлений

Режим `processing` используется для сложных фоновых задач (Background Task Scheduler), которые не требуются для данного приложения.

## Изменения в Info.plist
**До:**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>fetch</string>
    <string>remote-notification</string>
    <string>processing</string> <!-- Удалено -->
</array>
```

**После:**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

## Результат
✅ IPA успешно пересобран: `build/ios/ipa/maymessenger.ipa` (37.4MB)
✅ Версия: 0.8.1 (Build 2)
✅ Готов к загрузке в App Store Connect

## Загрузка в App Store
Теперь можно загрузить IPA через Apple Transporter:
```bash
open build/ios/ipa/
# Перетащите файл maymessenger.ipa в Apple Transporter
```

## Примечание для будущего
Если понадобится использовать фоновую обработку (`processing` mode), необходимо будет добавить в `Info.plist`:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.maymessenger.mobileApp.refresh</string>
    <string>com.maymessenger.mobileApp.processing</string>
</array>
```

И зарегистрировать соответствующие задачи в коде приложения.

---
**Дата исправления:** 13 января 2026
