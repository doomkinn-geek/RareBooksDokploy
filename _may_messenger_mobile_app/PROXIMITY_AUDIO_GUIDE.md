# Руководство по автоматическому переключению динамиков

## Обзор

Система автоматического переключения аудио между основным динамиком и разговорным (earpiece) при поднесении устройства к уху.

## Архитектура

### Компоненты

1. **ProximityAudioService** (`lib/core/services/proximity_audio_service.dart`)
   - Мониторинг датчика приближения
   - Управление маршрутизацией аудио
   - Работает через Platform Channels для нативного контроля

2. **MainActivity.kt** (`android/app/src/main/kotlin/com/depesha/MainActivity.kt`)
   - Нативный код для Android
   - Прямое управление AudioManager
   - Поддержка Android 12+ (setCommunicationDevice)

3. **GlobalAudioService** (`lib/core/services/global_audio_service.dart`)
   - Интеграция с proximity service
   - Автоматический запуск/остановка мониторинга

## Как это работает

### Android

1. **Переключение на earpiece:**
   - Устанавливается режим `MODE_IN_COMMUNICATION`
   - Отключается громкая связь (`isSpeakerphoneOn = false`)
   - На Android 12+ используется `setCommunicationDevice()` с `TYPE_BUILTIN_EARPIECE`
   - На более старых версиях аудио автоматически маршрутизируется на earpiece

2. **Переключение на speaker:**
   - Устанавливается режим `MODE_NORMAL`
   - Включается громкая связь (`isSpeakerphoneOn = true`)
   - На Android 12+ очищается коммуникационное устройство

### iOS

Использует `audio_session` с конфигурацией:
- **Earpiece:** режим `voiceChat` с категорией `playAndRecord`
- **Speaker:** режим `spokenAudio` с опцией `defaultToSpeaker`

## Использование

### Автоматический режим

Система автоматически активируется при воспроизведении аудиосообщения:

```dart
// Запускается автоматически в GlobalAudioService
await proximityService.startMonitoring();
```

### Ручное управление

```dart
final proximityService = ref.read(proximityAudioServiceProvider);

// Начать мониторинг
await proximityService.startMonitoring();

// Остановить мониторинг
await proximityService.stopMonitoring();

// Проверить текущий маршрут
final route = proximityService.currentRoute; // speaker | earpiece | bluetooth

// Проверить положение телефона
final isNear = proximityService.isNearEar;
```

## Разрешения

### Android

Добавлено в `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

### iOS

Настроено в `Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

## Отладка

### Логи

Сервис выводит логи с префиксом `ProximityAudioService`:

```
ProximityAudioService: Switched to earpiece
ProximityAudioService: Switched to speaker
ProximityAudioService: Audio route restored
```

### Проверка работы

1. Запустите воспроизведение аудиосообщения
2. Поднесите телефон к уху (закройте датчик приближения)
3. Звук должен переключиться на разговорный динамик
4. Отодвиньте телефон - звук вернется на основной динамик

### Возможные проблемы

**Проблема:** Датчик не срабатывает
- **Решение:** Проверьте, что датчик приближения работает (можно проверить в режиме звонка)

**Проблема:** Аудио не переключается на earpiece
- **Решение Android:** Убедитесь, что приложение имеет разрешение `MODIFY_AUDIO_SETTINGS`
- **Решение iOS:** Проверьте настройки AVAudioSession в Info.plist

**Проблема:** Аудио тихое в earpiece
- **Решение:** Это нормально - разговорный динамик имеет меньшую громкость

## Технические детали

### Platform Channel

**Канал:** `ru.rare_books.messenger/audio_routing`

**Методы:**
- `setAudioRouteEarpiece` - переключить на разговорный динамик
- `setAudioRouteSpeaker` - переключить на основной динамик
- `restoreAudioRoute` - восстановить нормальный режим

### Состояния AudioManager (Android)

- `MODE_NORMAL` - обычное воспроизведение (speaker)
- `MODE_IN_COMMUNICATION` - режим связи (earpiece)

### Категории AVAudioSession (iOS)

- `playback` - воспроизведение через speaker
- `playAndRecord` - запись и воспроизведение (для earpiece)

## Совместимость

- **Android:** API 21+ (Android 5.0+)
  - Полная поддержка на Android 12+ (API 31+)
  - Базовая поддержка на более старых версиях

- **iOS:** iOS 11+

## Производительность

- Датчик приближения потребляет минимум энергии
- Переключение аудио происходит мгновенно (<100ms)
- Нет влияния на качество звука



