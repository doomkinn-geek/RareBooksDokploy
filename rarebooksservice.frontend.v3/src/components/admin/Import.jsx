// src/admin/Import.jsx
import React, { useState, useEffect } from 'react';
import {
  Box, Typography, Button, LinearProgress, Alert
} from '@mui/material';
import {
  initImport, uploadImportChunk, finishImport,
  getImportProgress, cancelImport
} from '../../api';

const Import = () => {
  const [importTaskId, setImportTaskId] = useState(null);
  const [importFile, setImportFile] = useState(null);
  const [importUploadProgress, setImportUploadProgress] = useState(0);
  const [importProgress, setImportProgress] = useState(0);
  const [importMessage, setImportMessage] = useState('');
  const [isImporting, setIsImporting] = useState(false);
  const [pollIntervalId, setPollIntervalId] = useState(null);

  // Шаг 1: Инициализация импорта
  const initImportTask = async (fileSize) => {
    const taskId = await initImport(fileSize);
    setImportTaskId(taskId);
    return taskId;
  };

  // Шаг 2: Загрузка файла по кускам (chunk'ам)
  const uploadFileChunks = async (file, taskId) => {
    const chunkSize = 1024 * 256; // 256 KB
    let offset = 0;
    while (offset < file.size) {
      const slice = file.slice(offset, offset + chunkSize);

      // можно добавить onUploadProgress при желании
      await uploadImportChunk(taskId, slice, () => {/* handle each chunk progress */});

      offset += chunkSize;
      const overallPct = Math.round((offset * 100) / file.size);
      setImportUploadProgress(overallPct);
    }
  };

  // Шаг 3: Завершение загрузки
  const finishUpload = async (taskId) => {
    await finishImport(taskId);
  };

  // Опрос прогресса на сервере
  const pollImportProgress = async (taskId) => {
    if (!taskId) return;
    try {
      const data = await getImportProgress(taskId);
      // прогресс загрузки
      if (data.uploadProgress >= 0) {
        setImportUploadProgress(data.uploadProgress);
      }
      // прогресс обработки
      if (data.importProgress >= 0) {
        setImportProgress(data.importProgress);
      }
      // вспомогательное сообщение
      if (data.message) {
        setImportMessage(data.message);
      }

      // если сервер сказал, что всё закончено (или отменено/ошибка) — остановим опрос
      if (data.isFinished || data.isCancelledOrError) {
        clearInterval(pollIntervalId);
        setPollIntervalId(null);
        setIsImporting(false);
      }
    } catch (err) {
      console.error('Ошибка опроса импорта:', err);
    }
  };

  // Запуск импорта (по нажатию кнопки)
  const handleImportData = async () => {
    if (!importFile) {
      alert('Не выбран файл');
      return;
    }
    setIsImporting(true);
    setImportUploadProgress(0);
    setImportProgress(0);
    setImportMessage('');

    try {
      // Шаг 1: init
      const newTaskId = await initImportTask(importFile.size);

      // Шаг 2: upload
      await uploadFileChunks(importFile, newTaskId);

      // Шаг 3: finish
      await finishUpload(newTaskId);

      // Шаг 4: запустим периодический опрос статуса
      const pid = setInterval(() => {
        pollImportProgress(newTaskId);
      }, 500);
      setPollIntervalId(pid);
    } catch (err) {
      console.error('Import error:', err);
      setIsImporting(false);
      
      // Более детальная обработка ошибок
      if (!err.response) {
        // Нет ответа от сервера или ошибка сети
        setImportMessage('Ошибка соединения с сервером. Проверьте подключение и SSL-сертификаты.');
      } else if (err.response.status === 403) {
        // Ошибка аутентификации
        setImportMessage('Ошибка доступа. Возможно, истек срок действия сессии.');
      } else {
        // Другие ошибки
        setImportMessage(`Ошибка импорта: ${err.message || 'Неизвестная ошибка'}`);
      }
    }
  };

  // Обработчик для выбора файла
  const handleSelectImportFile = (e) => {
    if (e.target.files && e.target.files.length > 0) {
      setImportFile(e.target.files[0]);
    } else {
      setImportFile(null);
    }
    setImportUploadProgress(0);
    setImportProgress(0);
    setImportMessage('');
  };

  // Отмена импорта
  const handleCancelImport = async () => {
    if (!importTaskId) return;
    try {
      await cancelImport(importTaskId);
      alert('Импорт отменён');
      setIsImporting(false);
      if (pollIntervalId) {
        clearInterval(pollIntervalId);
        setPollIntervalId(null);
      }
    } catch (err) {
      console.error('Ошибка при отмене импорта:', err);
    }
  };

  return (
    <Box>
      <Typography variant="h5" component="h2" gutterBottom sx={{ fontWeight: 'bold', color: '#2c3e50', mb: 3 }}>
        Импорт данных
      </Typography>

      <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, maxWidth: 400 }}>
        {/* Кнопка выбора файла */}
        <Button variant="outlined" component="label">
          Выбрать файл для импорта
          <input type="file" hidden onChange={handleSelectImportFile} />
        </Button>

        {importFile && (
          <Typography>Выбран файл: {importFile.name}</Typography>
        )}

        {/* Кнопка запуска/отмены импорта */}
        {isImporting ? (
          <Button
            variant="contained"
            color="error"
            onClick={handleCancelImport}
          >
            Отменить импорт
          </Button>
        ) : (
          <Button
            variant="contained"
            onClick={handleImportData}
          >
            Начать импорт
          </Button>
        )}

        {/* Отображаем прогресс загрузки и обработки, если > 0 */}
        {(importUploadProgress > 0 || importProgress > 0) && (
          <Box>
            <Typography variant="body2">
              Загрузка: {importUploadProgress}%
            </Typography>
            <LinearProgress variant="determinate" value={importUploadProgress} />
            
            <Typography variant="body2" sx={{ mt: 2 }}>
              Обработка: {importProgress}%
            </Typography>
            <LinearProgress variant="determinate" value={importProgress} />
          </Box>
        )}

        {/* Сообщения от сервера */}
        {importMessage && (
          <Alert severity="info" sx={{ mt: 2 }}>
            {importMessage}
          </Alert>
        )}
      </Box>
    </Box>
  );
};

export default Import;
