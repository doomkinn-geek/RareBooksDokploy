# Улучшения отображения прогресса импорта книг

## Обзор изменений

Система импорта книг была улучшена для **детального отображения прогресса обработки каждого файла** из архива. Теперь пользователь видит не только общий прогресс, но и информацию о текущем обрабатываемом файле.

## ⭐ Что было улучшено

**ДО**: Показывался только общий прогресс импорта без детализации по файлам.

**ПОСЛЕ**: Отображается полная информация:
- Номер текущего файла из общего количества (например, "3/7")
- Имя текущего обрабатываемого файла
- Прогресс обработки текущего файла
- Общий прогресс импорта с учетом всех файлов

## 🔧 Изменения в коде

### 1. Расширение ImportProgressDto

**Добавлены новые поля для детализации:**

```csharp
public class ImportProgressDto
{
    // Существующие поля
    public double UploadProgress { get; set; }
    public double ImportProgress { get; set; }
    public bool IsFinished { get; set; }
    public bool IsCancelledOrError { get; set; }
    public string Message { get; set; }
    
    // НОВЫЕ поля для отображения информации о файлах
    public int CurrentFileIndex { get; set; }       // Номер текущего файла (1, 2, 3...)
    public int TotalFilesCount { get; set; }        // Общее количество файлов в архиве
    public string CurrentFileName { get; set; }     // Имя текущего файла (part_1.db)
    public double CurrentFileProgress { get; set; }  // Прогресс текущего файла (0-100%)
}
```

### 2. Расширение ImportTaskInfo

**Добавлены поля для хранения состояния:**

```csharp
private class ImportTaskInfo
{
    // Существующие поля...
    
    // НОВЫЕ поля для отслеживания файлов
    public int CurrentFileIndex { get; set; } = 0;      // Номер текущего файла
    public int TotalFilesCount { get; set; } = 0;       // Общее количество файлов
    public string CurrentFileName { get; set; } = "";   // Имя текущего файла
    public double CurrentFileProgress { get; set; } = 0.0; // Прогресс файла
}
```

### 3. Улучшенная логика обработки файлов

**Установка информации о файлах:**

```csharp
// Устанавливаем общее количество файлов
taskInfo.TotalFilesCount = chunkFiles.Length;

// В цикле обработки каждого файла
for (int fileIndex = 0; fileIndex < sortedChunkFiles.Length; fileIndex++)
{
    var chunkFile = sortedChunkFiles[fileIndex];
    
    // Обновляем информацию о текущем файле
    taskInfo.CurrentFileIndex = fileIndex + 1;
    taskInfo.CurrentFileName = Path.GetFileName(chunkFile);
    taskInfo.CurrentFileProgress = 0.0;
    
    _logger.LogInformation("Обработка файла {CurrentFile}/{TotalFiles}: {ChunkFile}", 
        taskInfo.CurrentFileIndex, taskInfo.TotalFilesCount, taskInfo.CurrentFileName);
}
```

### 4. Умный расчет прогресса

**Двухуровневый прогресс:**

```csharp
// Прогресс текущего файла (0-100%)
taskInfo.CurrentFileProgress = (double)booksProcessedInFile / books.Count * 100.0;

// Общий прогресс с учетом всех файлов
double fileProgressWeight = 100.0 / taskInfo.TotalFilesCount;
double completedFilesProgress = (taskInfo.CurrentFileIndex - 1) * fileProgressWeight;
double currentFileProgress = (taskInfo.CurrentFileProgress / 100.0) * fileProgressWeight;
taskInfo.ImportProgress = completedFilesProgress + currentFileProgress;
```

### 5. Детальное логирование

**Улучшенные сообщения в логах:**

```csharp
_logger.LogInformation("Всего будет импортировано {Count} книг из {FileCount} файлов", 
    totalBooksCount, chunkFiles.Length);

_logger.LogInformation("Файл {CurrentFile}/{TotalFiles} обработан. Добавлено/обновлено: {AddedBooks}, пропущено: {SkippedBooks}", 
    taskInfo.CurrentFileIndex, taskInfo.TotalFilesCount, addedBooks, skippedBooks);
```

## 📊 Примеры отображения прогресса

### В процессе импорта:
```json
{
  "uploadProgress": 100.0,
  "importProgress": 45.5,
  "currentFileIndex": 3,
  "totalFilesCount": 7,
  "currentFileName": "part_3.db",
  "currentFileProgress": 78.2,
  "message": "Импорт в процессе...",
  "isFinished": false,
  "isCancelledOrError": false
}
```

### При завершении:
```json
{
  "uploadProgress": 100.0,
  "importProgress": 100.0,
  "currentFileIndex": 7,
  "totalFilesCount": 7,
  "currentFileName": "Завершено",
  "currentFileProgress": 100.0,
  "message": "Импорт завершен. Обработано 7 файлов. Добавлено 15234 книг, пропущено 127 книг.",
  "isFinished": true,
  "isCancelledOrError": false
}
```

## 🎯 Преимущества для пользователя

### Прозрачность процесса
- ✅ Видно сколько файлов уже обработано из общего количества
- ✅ Видно имя текущего обрабатываемого файла  
- ✅ Видно прогресс обработки текущего файла
- ✅ Видно точный общий прогресс импорта

### Лучшее понимание времени
- ✅ Можно оценить сколько времени осталось до завершения
- ✅ Понятно на каком этапе находится процесс
- ✅ Видно если какой-то файл обрабатывается дольше других

### Диагностика проблем
- ✅ Если импорт "завис", видно на каком файле
- ✅ В логах подробная информация о каждом файле
- ✅ Можно отследить проблемные файлы в архиве

## 🔄 Логика расчета прогресса

### Формула общего прогресса:
```
Общий прогресс = (Завершенные файлы × Вес файла) + (Текущий файл × Вес файла × Прогресс файла)

где:
- Вес файла = 100% / Общее количество файлов
- Завершенные файлы = CurrentFileIndex - 1  
- Прогресс файла = CurrentFileProgress / 100
```

### Пример расчета:
При обработке 3-го файла из 5 с прогрессом 60%:
- Вес файла = 100% / 5 = 20%
- Завершенные файлы = 3 - 1 = 2
- Общий прогресс = (2 × 20%) + (60% × 20%) = 40% + 12% = 52%

## 📋 Интеграция с фронтендом

**Новые поля в API ответе** позволят фронтенду отображать:

```javascript
// Пример отображения в React
const progressText = `Файл ${currentFileIndex}/${totalFilesCount}: ${currentFileName}`;
const fileProgressBar = `${currentFileProgress.toFixed(1)}%`;
const overallProgressBar = `${importProgress.toFixed(1)}%`;
```

## 🎯 Результат

**Теперь импорт книг предоставляет полную прозрачность процесса**, позволяя пользователям точно понимать что происходит на каждом этапе обработки архива с несколькими файлами.

Это особенно важно при импорте больших архивов, когда процесс может занимать продолжительное время и пользователю важно видеть детальный прогресс. 