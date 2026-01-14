---
name: Media Controls Fix
overview: Исправление дублирующихся индикаторов загрузки в медиа контролах и улучшение виджета отображения изображений с поддержкой адаптивных размеров для горизонтальных изображений.
todos:
  - id: fix-image-loading-indicators
    content: Исправить дублирующиеся индикаторы загрузки для изображений - убрать placeholder при upload overlay
    status: completed
  - id: fix-file-loading-indicators
    content: Убрать дублирующий LinearProgressIndicator для файлов, оставить только круговой
    status: completed
  - id: fix-audio-loading-indicators
    content: Не показывать sending индикатор в статусе когда идет upload аудио
    status: completed
  - id: improve-image-adaptive-size
    content: Заменить фиксированные размеры 200x200 на адаптивные с ConstrainedBox для горизонтальных изображений
    status: completed
  - id: add-image-shimmer
    content: Добавить shimmer-эффект при загрузке изображений вместо простого спиннера
    status: completed
  - id: add-image-fade-in
    content: Добавить плавное появление изображения (fade-in анимация)
    status: completed
  - id: add-hero-animation
    content: Добавить Hero-анимацию при переходе к полноэкранному просмотру изображения
    status: completed
---

# Исправление медиа контролов мессенджера

## Выявленные проблемы

### 1. Дублирующиеся индикаторы загрузки

**Аудио сообщения** ([`message_bubble.dart`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_mobile_app\lib\presentation\widgets\message_bubble.dart), строки 517-773):

- `CircularProgressIndicator` при `isUploading` (строки 521-550)
- `CircularProgressIndicator` при `_isDownloadingAudio || isLoading` (строки 552-599)
- Индикатор в статусе `MessageStatus.sending` (строка 400-407) - **дублирует информацию**

**Изображения** ([`message_bubble.dart`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_mobile_app\lib\presentation\widgets\message_bubble.dart), строки 1165-1263):

- `CachedNetworkImage.placeholder` с `CircularProgressIndicator` (строки 1193-1200)
- Overlay с прогрессом загрузки (строки 1230-1258)
- **Оба показываются одновременно при загрузке**

**Файлы** ([`message_bubble.dart`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_mobile_app\lib\presentation\widgets\message_bubble.dart), строки 788-917):

- `CircularProgressIndicator` вокруг иконки (строки 846-859)
- `LinearProgressIndicator` снизу (строки 900-910)
- **Оба показываются одновременно - избыточно**

### 2. Горизонтальные изображения ограничены

В `_buildImageWidget()` (строки 1176-1180, 1189-1192):

```dart
width: 200,
height: 200,
fit: BoxFit.cover,
```

Фиксированные размеры 200x200 с `BoxFit.cover` обрезают горизонтальные изображения.

---

## План исправлений

### Задача 1: Исправить дублирующиеся индикаторы загрузки

**Аудио:**

- Убрать индикатор из `_buildMessageStatusIcon()` когда идет загрузка аудио (при `uploadProgress != null`)
- Оставить только один индикатор прогресса в контенте аудио

**Изображения:**

- Убрать `placeholder` из `CachedNetworkImage` при отображении upload progress overlay
- Использовать `shimmer` эффект вместо двух индикаторов

**Файлы:**

- Убрать `LinearProgressIndicator` (строки 900-910)
- Оставить только круговой индикатор вокруг иконки с процентом

### Задача 2: Исправить отображение горизонтальных изображений

Заменить фиксированные размеры на адаптивные:

```dart
// Вместо фиксированных 200x200:
ConstrainedBox(
  constraints: BoxConstraints(
    maxWidth: 250,
    maxHeight: 300,
    minWidth: 100,
    minHeight: 100,
  ),
  child: AspectRatio(
    aspectRatio: imageAspectRatio ?? 1.0, // Нужно получить из metadata
    child: imageWidget,
  ),
)
```

Также использовать `BoxFit.contain` вместо `BoxFit.cover`.

### Задача 3: Современные улучшения для изображений

- **Shimmer-эффект** при загрузке вместо простого спиннера
- **Плавное появление** изображения (fade-in анимация)
- **Hero-анимация** при переходе к полноэкранному просмотру
- **Закругленные углы** (уже есть `borderRadius: 8`)

---

## Файлы для изменения

| Файл | Изменения |

|------|-----------|

| [`message_bubble.dart`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_mobile_app\lib\presentation\widgets\message_bubble.dart) | Основные исправления всех медиа контролов |

---

## Детали реализации

### `_buildImageWidget()` - новая версия:

- Добавить параметры для получения размеров изображения из metadata (если доступны)
- Использовать `ConstrainedBox` с адаптивными ограничениями
- Добавить `shimmer` пакет или создать простой shimmer-эффект через `AnimatedContainer`
- Добавить `FadeInImage` или обернуть в `AnimatedOpacity` для плавного появления
- Обернуть в `Hero` виджет для анимации перехода

### `_buildFileWidget()` - исправления:

- Удалить дублирующий `LinearProgressIndicator` (строки 900-910)
- Улучшить текст прогресса в основном индикаторе

### Аудио контрол - исправления:

- В `_buildMessageStatusIcon()` не показывать индикатор `sending` если `uploadProgress != null`