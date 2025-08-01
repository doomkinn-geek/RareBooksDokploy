import React, { useState, useEffect } from 'react';
import {
    Box, Typography, Paper, Button,
    LinearProgress, Alert, CircularProgress
} from '@mui/material';
import axios from 'axios';
import { API_URL } from '../../api';
import Cookies from 'js-cookie';

const Export = () => {
    const [exportTaskId, setExportTaskId] = useState(null);
    const [progress, setProgress] = useState(null);
    const [exportError, setExportError] = useState(null);
    const [exportInternalError, setExportInternalError] = useState(null);
    const [isExporting, setIsExporting] = useState(false);
    const [intervalId, setIntervalId] = useState(null);
    const [isLoading, setIsLoading] = useState(true);
    // Новые состояния для отслеживания прогресса загрузки файла
    const [isDownloading, setIsDownloading] = useState(false);
    const [downloadProgress, setDownloadProgress] = useState(0);

    // Проверяем текущий статус экспорта при загрузке компонента
    useEffect(() => {
        checkExportStatus();
    }, []);

    // Очищаем интервал при размонтировании компонента
    useEffect(() => {
        return () => {
            if (intervalId) {
                clearInterval(intervalId);
            }
        };
    }, [intervalId]);

    // Проверка, есть ли активный экспорт
    const checkExportStatus = async () => {
        setIsLoading(true);
        try {
            const token = Cookies.get('token');
            const response = await axios.get(
                `${API_URL}/admin/export-status`,
                { headers: { Authorization: `Bearer ${token}` } }
            );
            
            if (response.data && response.data.isExporting) {
                setIsExporting(true);
                setExportTaskId(response.data.taskId);
                setProgress(response.data.progress);
                startPollingProgress(response.data.taskId);
            }
        } catch (err) {
            console.error('Error checking export status:', err);
            // Если не удалось получить статус, предполагаем, что экспорт не выполняется
        } finally {
            setIsLoading(false);
        }
    };

    const startExport = async () => {
        setExportError(null);
        setExportInternalError(null);
        setProgress(null);
        setIsExporting(true);

        try {
            const token = Cookies.get('token');
            const response = await axios.post(
                `${API_URL}/admin/export-data`,
                null,
                { headers: { Authorization: `Bearer ${token}` } }
            );
            
            const taskId = response.data.taskId;
            setExportTaskId(taskId);
            startPollingProgress(taskId);
        } catch (err) {
            console.error('Error starting export:', err);
            setExportInternalError('Ошибка при запуске экспорта: ' + (err.response?.data || err.message));
            setIsExporting(false);
        }
    };

    const startPollingProgress = (taskId) => {
        // Остановим предыдущий интервал, если он существует
        if (intervalId) {
            clearInterval(intervalId);
        }

        const newIntervalId = setInterval(async () => {
            try {
                if (!taskId) {
                    console.error('No export task ID available');
                    clearInterval(newIntervalId);
                    setIsExporting(false);
                    return;
                }

                const token = Cookies.get('token');
                const response = await axios.get(
                    `${API_URL}/admin/export-progress/${taskId}`,
                    { headers: { Authorization: `Bearer ${token}` } }
                );

                const { progress: currentProgress, isError, errorDetails } = response.data;
                
                setProgress(currentProgress);
                if (isError) {
                    setExportError(errorDetails || 'Произошла ошибка при экспорте');
                    clearInterval(newIntervalId);
                    setIsExporting(false);
                    return;
                }

                // Если прогресс 100%, завершаем
                if (currentProgress === 100) {
                    clearInterval(newIntervalId);
                    setIsExporting(false);
                    // Используем рабочий метод скачивания через форму вместо axios
                    console.log('Экспорт завершен, автоматически скачиваем через форму');
                    
                    // Небольшая задержка перед автоматическим скачиванием
                    setTimeout(() => {
                        downloadExportFileDirect(taskId);
                    }, 1000);
                }
            } catch (err) {
                console.error('Error polling export progress:', err);
                
                let errorMessage = 'Ошибка при получении прогресса экспорта';
                
                if (err.response?.status === 502) {
                    errorMessage = 'Сервер временно недоступен (502). Экспорт может продолжаться в фоне. Обновите страницу через несколько минут.';
                    // Не останавливаем polling для 502 ошибок - сервер может восстановиться
                    return;
                } else if (err.response?.status >= 500) {
                    errorMessage = 'Ошибка сервера. Экспорт может быть прерван.';
                } else if (err.code === 'ECONNABORTED') {
                    errorMessage = 'Превышено время ожидания ответа сервера.';
                } else if (err.message === 'Network Error') {
                    errorMessage = 'Ошибка сети. Проверьте подключение.';
                } else if (err.response?.data) {
                    errorMessage += ': ' + err.response.data;
                } else if (err.message) {
                    errorMessage += ': ' + err.message;
                }
                
                setExportInternalError(errorMessage);
                clearInterval(newIntervalId);
                setIsExporting(false);
            }
        }, 2000); // Увеличиваем интервал до 2 секунд, чтобы снизить нагрузку
        
        setIntervalId(newIntervalId);
    };

    const downloadExportFile = async (taskId) => {
        try {
            const token = Cookies.get('token');
            const downloadTaskId = taskId || exportTaskId; // Используем переданный taskId или сохраненный
            
            if (!downloadTaskId) {
                setExportInternalError('ID задачи экспорта не найден');
                return;
            }
            
            console.log(`Начинается скачивание файла экспорта для TaskId: ${downloadTaskId}`);
            
            // Устанавливаем состояние загрузки
            setIsDownloading(true);
            setDownloadProgress(0);
            
            console.log(`Отправляем запрос на скачивание: ${API_URL}/admin/download-exported-file/${downloadTaskId}`);
            
            const response = await axios.get(
                `${API_URL}/admin/download-exported-file/${downloadTaskId}`,
                {
                    headers: { Authorization: `Bearer ${token}` },
                    responseType: 'blob',
                    timeout: 300000, // 5 минут timeout для больших файлов
                    onDownloadProgress: (progressEvent) => {
                        if (progressEvent.total) {
                            const progress = Math.round((progressEvent.loaded / progressEvent.total) * 100);
                            setDownloadProgress(progress);
                            console.log(`Прогресс скачивания: ${progress}% (${progressEvent.loaded}/${progressEvent.total} байт)`);
                        } else {
                            console.log(`Загружено: ${progressEvent.loaded} байт (размер неизвестен)`);
                        }
                    }
                }
            );
            
            console.log('Ответ получен от сервера:', {
                status: response.status,
                statusText: response.statusText,
                contentType: response.headers['content-type'],
                contentLength: response.headers['content-length'],
                dataSize: response.data?.size
            });

            // Проверяем, что ответ содержит данные
            if (!response.data || response.data.size === 0) {
                console.error('Получен пустой файл от сервера');
                throw new Error('Получен пустой файл');
            }

            console.log(`Создаем blob для скачивания, размер: ${response.data.size} байт`);
            const blob = new Blob([response.data]);
            console.log(`Blob создан, размер: ${blob.size} байт`);
            
            const url = window.URL.createObjectURL(blob);
            console.log(`URL создан: ${url}`);
            
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', `export_${downloadTaskId}.zip`);
            console.log(`Добавляем ссылку в DOM и инициируем скачивание`);
            
            document.body.appendChild(link);
            link.click();
            link.remove();
            window.URL.revokeObjectURL(url);
            
            console.log('Скачивание файла инициировано успешно');
            
            // Сбрасываем состояние загрузки после небольшой задержки,
            // чтобы пользователь успел увидеть 100%
            setTimeout(() => {
                setIsDownloading(false);
                setDownloadProgress(0);
                console.log('Состояние загрузки сброшено');
            }, 1000);
        } catch (err) {
            console.error('Error downloading export file:', err);
            console.error('Error details:', {
                message: err.message,
                code: err.code,
                response: err.response ? {
                    status: err.response.status,
                    statusText: err.response.statusText,
                    data: err.response.data,
                    headers: err.response.headers
                } : 'No response',
                stack: err.stack
            });
            
            // Более детальная обработка ошибок
            let errorMessage = 'Ошибка при скачивании файла экспорта';
            
            if (err.code === 'ECONNABORTED') {
                errorMessage = 'Превышено время ожидания загрузки. Попробуйте еще раз.';
                console.log('Timeout error detected');
            } else if (err.message === 'Network Error') {
                errorMessage = 'Ошибка сети. Проверьте подключение к интернету.';
                console.log('Network error detected');
                            } else if (err.response?.status === 400) {
                errorMessage = 'Ошибка запроса (400). Автоматически переключаемся на безопасный способ загрузки...';
                console.log('400 error detected, trying direct form download');
                console.log('Response data:', err.response?.data);
                console.log('Request config:', err.config);
                
                // Показываем пользователю, что происходит переключение
                setExportInternalError('Обычное скачивание недоступно. Переключаемся на альтернативный способ...');
                
                // Пробуем рабочий способ через форму через небольшую задержку
                setTimeout(() => {
                    setExportInternalError(null); // Убираем сообщение об ошибке
                    downloadExportFileDirect(downloadTaskId);
                }, 2000);
                return;
            } else if (err.response?.status === 404) {
                errorMessage = 'Файл экспорта не найден или был удален.';
                console.log('404 error detected');
            } else if (err.response?.status === 502) {
                errorMessage = 'Ошибка сервера (502). Пробуем альтернативный способ загрузки...';
                console.log(`502 error detected, trying stream download`);
                // Пробуем альтернативный endpoint для потоковой загрузки
                setTimeout(() => downloadExportFileStream(downloadTaskId), 1000);
                return;
            } else if (err.response?.status >= 500) {
                errorMessage = 'Ошибка сервера. Попробуйте еще раз позже.';
                console.log(`Server error detected: ${err.response.status}`);
            } else if (err.message) {
                errorMessage += ': ' + err.message;
                console.log(`Other error detected: ${err.message}`);
            }
            
            console.log(`Setting error message: ${errorMessage}`);
            setExportInternalError(errorMessage);
            setIsDownloading(false);
        }
    };

    const downloadExportFileStream = async (taskId) => {
        try {
            const token = Cookies.get('token');
            const downloadTaskId = taskId || exportTaskId;
            
            if (!downloadTaskId) {
                setExportInternalError('ID задачи экспорта не найден');
                return;
            }
            
            console.log(`[STREAM] Начинается потоковое скачивание файла экспорта для TaskId: ${downloadTaskId}`);
            
            setIsDownloading(true);
            setDownloadProgress(0);
            
            console.log(`[STREAM] Отправляем запрос на потоковое скачивание: ${API_URL}/admin/download-exported-file-stream/${downloadTaskId}`);
            
            const response = await axios.get(
                `${API_URL}/admin/download-exported-file-stream/${downloadTaskId}`,
                {
                    headers: { Authorization: `Bearer ${token}` },
                    responseType: 'blob',
                    timeout: 600000, // 10 минут timeout для больших файлов
                    onDownloadProgress: (progressEvent) => {
                        if (progressEvent.total) {
                            const progress = Math.round((progressEvent.loaded / progressEvent.total) * 100);
                            setDownloadProgress(progress);
                            console.log(`[STREAM] Прогресс скачивания: ${progress}% (${progressEvent.loaded}/${progressEvent.total} байт)`);
                        } else {
                            console.log(`[STREAM] Загружено: ${progressEvent.loaded} байт (размер неизвестен)`);
                        }
                    }
                }
            );
            
            console.log('[STREAM] Ответ получен от сервера:', {
                status: response.status,
                statusText: response.statusText,
                contentType: response.headers['content-type'],
                contentLength: response.headers['content-length'],
                dataSize: response.data?.size
            });

            if (!response.data || response.data.size === 0) {
                console.error('[STREAM] Получен пустой файл от сервера');
                throw new Error('Получен пустой файл');
            }

            console.log(`[STREAM] Создаем blob для скачивания, размер: ${response.data.size} байт`);
            const blob = new Blob([response.data]);
            console.log(`[STREAM] Blob создан, размер: ${blob.size} байт`);
            
            const url = window.URL.createObjectURL(blob);
            console.log(`[STREAM] URL создан: ${url}`);
            
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', `export_${downloadTaskId}.zip`);
            console.log(`[STREAM] Добавляем ссылку в DOM и инициируем скачивание`);
            
            document.body.appendChild(link);
            link.click();
            link.remove();
            window.URL.revokeObjectURL(url);
            
            console.log('[STREAM] Потоковое скачивание файла инициировано успешно');
            
            setTimeout(() => {
                setIsDownloading(false);
                setDownloadProgress(0);
                console.log('[STREAM] Состояние загрузки сброшено');
            }, 1000);
        } catch (err) {
            console.error('[STREAM] Error downloading export file:', err);
            console.error('[STREAM] Error details:', {
                message: err.message,
                code: err.code,
                response: err.response ? {
                    status: err.response.status,
                    statusText: err.response.statusText,
                    data: err.response.data,
                    headers: err.response.headers
                } : 'No response',
                stack: err.stack
            });
            
            let errorMessage = 'Ошибка при потоковом скачивании файла экспорта';
            
            if (err.code === 'ECONNABORTED') {
                errorMessage = 'Превышено время ожидания потоковой загрузки. Файл слишком большой.';
            } else if (err.message === 'Network Error') {
                errorMessage = 'Ошибка сети при потоковой загрузке.';
            } else if (err.response?.status >= 500) {
                errorMessage = 'Ошибка сервера при потоковой загрузке. Возможно, файл поврежден.';
            } else if (err.message) {
                errorMessage += ': ' + err.message;
            }
            
            console.log(`[STREAM] Setting error message: ${errorMessage}`);
            setExportInternalError(errorMessage);
            setIsDownloading(false);
        }
    };

    const downloadExportFileDirect = (taskId) => {
        try {
            const token = Cookies.get('token');
            const downloadTaskId = taskId || exportTaskId;
            
            if (!downloadTaskId) {
                setExportInternalError('ID задачи экспорта не найден');
                return;
            }
            
            console.log(`[DIRECT] Начинается прямое скачивание файла экспорта для TaskId: ${downloadTaskId}`);
            
            // Создаем временную форму для авторизованного скачивания
            const form = document.createElement('form');
            form.method = 'GET';
            form.action = `${API_URL}/admin/download-exported-file/${downloadTaskId}`;
            form.style.display = 'none';
            
            // Добавляем скрытое поле с токеном авторизации
            const tokenInput = document.createElement('input');
            tokenInput.type = 'hidden';
            tokenInput.name = 'token';
            tokenInput.value = token;
            form.appendChild(tokenInput);
            
            document.body.appendChild(form);
            
            console.log(`[DIRECT] Отправляем форму для скачивания: ${form.action}`);
            form.submit();
            
            // Удаляем форму через небольшую задержку
            setTimeout(() => {
                document.body.removeChild(form);
                console.log('[DIRECT] Форма удалена');
            }, 1000);
            
            console.log('[DIRECT] Прямое скачивание инициировано через форму');
        } catch (err) {
            console.error('[DIRECT] Error in direct download:', err);
            setExportInternalError('Ошибка при прямом скачивании: ' + err.message);
        }
    };

    const downloadExportFileWindow = (taskId) => {
        try {
            const token = Cookies.get('token');
            const downloadTaskId = taskId || exportTaskId;
            
            if (!downloadTaskId) {
                setExportInternalError('ID задачи экспорта не найден');
                return;
            }
            
            console.log(`[WINDOW] Начинается скачивание через новое окно для TaskId: ${downloadTaskId}`);
            
            // Формируем URL с токеном в параметрах (не рекомендуется для продакшена, но может помочь для тестирования)
            const downloadUrl = `${API_URL}/admin/download-exported-file/${downloadTaskId}?token=${encodeURIComponent(token)}`;
            
            console.log(`[WINDOW] Открываем новое окно: ${downloadUrl}`);
            
            // Открываем в новом окне
            const newWindow = window.open(downloadUrl, '_blank');
            
            if (!newWindow) {
                throw new Error('Браузер заблокировал открытие нового окна. Разрешите всплывающие окна.');
            }
            
            console.log('[WINDOW] Новое окно открыто для скачивания');
            
            // Закрываем окно через 5 секунд
            setTimeout(() => {
                if (newWindow && !newWindow.closed) {
                    newWindow.close();
                    console.log('[WINDOW] Окно закрыто');
                }
            }, 5000);
            
        } catch (err) {
            console.error('[WINDOW] Error in window download:', err);
            setExportInternalError('Ошибка при скачивании через окно: ' + err.message);
        }
    };

    const cancelExport = async () => {
        if (exportTaskId) {
            try {
                const token = Cookies.get('token');
                await axios.post(
                    `${API_URL}/admin/cancel-export/${exportTaskId}`,
                    null,
                    { headers: { Authorization: `Bearer ${token}` } }
                );
                
                if (intervalId) {
                    clearInterval(intervalId);
                }
                
                setIsExporting(false);
                setProgress(null);
                setExportTaskId(null);
            } catch (err) {
                console.error('Error cancelling export:', err);
                setExportInternalError('Ошибка при отмене экспорта');
            }
        }
    };

    return (
        <Box>
            <Typography variant="h6" gutterBottom>
                Экспорт данных
            </Typography>

            {(exportError || exportInternalError) && (
                <Alert severity="error" sx={{ mb: 2 }}>
                    {exportError || exportInternalError}
                </Alert>
            )}

            <Paper sx={{ p: 2, mb: 2 }}>
                <Box sx={{ mb: 2 }}>
                    <Button
                        variant="contained"
                        onClick={startExport}
                        disabled={isExporting || isLoading || isDownloading}
                        sx={{ mr: 1 }}
                    >
                        {isLoading ? 'Загрузка...' : 'Начать экспорт'}
                    </Button>
                    <Button
                        variant="outlined"
                        onClick={cancelExport}
                        disabled={!isExporting || isDownloading}
                        color="error"
                        sx={{ mr: 1 }}
                    >
                        Отменить
                    </Button>
                    {exportTaskId && !isExporting && (
                        <>
                            <Button
                                variant="outlined"
                                onClick={() => downloadExportFile(exportTaskId)}
                                disabled={isDownloading}
                                color="primary"
                                sx={{ mr: 1 }}
                                size="small"
                            >
                                Скачать (axios)
                            </Button>
                            <Button
                                variant="outlined"
                                onClick={() => downloadExportFileStream(exportTaskId)}
                                disabled={isDownloading}
                                color="secondary"
                                sx={{ mr: 1 }}
                                size="small"
                            >
                                Скачать (поток)
                            </Button>
                            <Button
                                variant="outlined"
                                onClick={() => downloadExportFileDirect(exportTaskId)}
                                disabled={isDownloading}
                                color="success"
                                sx={{ mr: 1 }}
                                size="small"
                            >
                                Скачать (форма)
                            </Button>
                            <Button
                                variant="outlined"
                                onClick={() => downloadExportFileWindow(exportTaskId)}
                                disabled={isDownloading}
                                color="info"
                                size="small"
                            >
                                Скачать (окно)
                            </Button>
                        </>
                    )}
                </Box>

                {isExporting && (
                    <Box sx={{ mt: 2 }}>
                        <Typography variant="subtitle2" gutterBottom>
                            Прогресс экспорта: {progress !== null ? `${Math.round(progress)}%` : 'Инициализация...'}
                        </Typography>
                        {progress !== null && (
                            <LinearProgress 
                                variant="determinate" 
                                value={progress} 
                                sx={{ mb: 2 }}
                            />
                        )}
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                            <CircularProgress size={20} />
                            <Typography variant="body2">
                                Экспорт в процессе...
                            </Typography>
                        </Box>
                    </Box>
                )}
                
                {/* Визуализация загрузки файла */}
                {isDownloading && (
                    <Box sx={{ mt: 2 }}>
                        <Typography variant="subtitle2" gutterBottom>
                            Загрузка файла: {Math.round(downloadProgress)}%
                        </Typography>
                        <LinearProgress 
                            variant="determinate" 
                            value={downloadProgress} 
                            sx={{ 
                                mb: 2,
                                height: 10,
                                borderRadius: 5,
                                backgroundColor: '#e0e0e0',
                                '& .MuiLinearProgress-bar': {
                                    backgroundColor: '#2e7d32', // зелёный цвет для загрузки
                                    borderRadius: 5
                                }
                            }}
                        />
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                            <CircularProgress size={20} color="success" />
                            <Typography variant="body2">
                                Скачивание файла экспорта...
                            </Typography>
                        </Box>
                    </Box>
                )}
            </Paper>
        </Box>
    );
};

export default Export; 