import React, { useState, useEffect } from 'react';
import {
    Box, Typography, Paper, Button,
    LinearProgress, Alert, CircularProgress
} from '@mui/material';
import axios from 'axios';
import { API_URL } from '../../api';
import Cookies from 'js-cookie';

const SubscriptionPlanExport = () => {
    const [exportTaskId, setExportTaskId] = useState(null);
    const [progress, setProgress] = useState(null);
    const [exportError, setExportError] = useState(null);
    const [exportInternalError, setExportInternalError] = useState(null);
    const [isExporting, setIsExporting] = useState(false);
    const [intervalId, setIntervalId] = useState(null);
    const [isLoading, setIsLoading] = useState(true);
    // Состояния для отслеживания прогресса загрузки файла
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

    // Проверка, есть ли активный экспорт планов подписок
    const checkExportStatus = async () => {
        setIsLoading(true);
        try {
            // Получаем список активных экспортов
            const token = Cookies.get('token');
            // Для планов подписок у нас нет отдельного status endpoint,
            // поэтому просто считаем что экспорт не активен
            console.log('Проверка статуса экспорта планов подписок');
        } catch (err) {
            console.error('Error checking subscription plan export status:', err);
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
            console.log('Запуск экспорта планов подписок...');
            
            const response = await axios.post(
                `${API_URL}/admin/export-subscription-plans`,
                null,
                { 
                    headers: { Authorization: `Bearer ${token}` },
                    timeout: 30000 // 30 секунд на запуск
                }
            );
            
            const taskId = response.data.taskId;
            console.log(`Экспорт планов подписок запущен с TaskId: ${taskId}`);
            setExportTaskId(taskId);
            startPollingProgress(taskId);
        } catch (err) {
            console.error('Error starting subscription plan export:', err);
            let errorMessage = 'Ошибка при запуске экспорта планов подписок';
            
            if (err.response?.status === 400) {
                errorMessage = 'Уже выполняется экспорт планов подписок. Дождитесь завершения или отмените предыдущий экспорт.';
            } else if (err.response?.data) {
                errorMessage += ': ' + err.response.data;
            } else if (err.message) {
                errorMessage += ': ' + err.message;
            }
            
            setExportInternalError(errorMessage);
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
                    console.error('No subscription plan export task ID available');
                    clearInterval(newIntervalId);
                    setIsExporting(false);
                    return;
                }

                const token = Cookies.get('token');
                console.log(`Проверяем прогресс экспорта планов, TaskId: ${taskId}`);
                
                const response = await axios.get(
                    `${API_URL}/admin/subscription-plan-export-progress/${taskId}`,
                    { 
                        headers: { Authorization: `Bearer ${token}` },
                        timeout: 10000 // 10 секунд timeout для polling
                    }
                );

                const { progress: currentProgress, isError, errorDetails } = response.data;
                
                console.log(`Прогресс экспорта планов: ${currentProgress}%`);
                setProgress(currentProgress);
                
                if (isError) {
                    console.error('Ошибка экспорта планов:', errorDetails);
                    setExportError(errorDetails || 'Произошла ошибка при экспорте планов подписок');
                    clearInterval(newIntervalId);
                    setIsExporting(false);
                    return;
                }

                // Если прогресс 100%, завершаем
                if (currentProgress === 100) {
                    console.log('Экспорт планов подписок завершен, начинаем скачивание');
                    clearInterval(newIntervalId);
                    setIsExporting(false);
                    // Автоматически скачиваем файл
                    setTimeout(() => {
                        downloadExportFile(taskId);
                    }, 1000);
                }
            } catch (err) {
                console.error('Error polling subscription plan export progress:', err);
                
                let errorMessage = 'Ошибка при получении прогресса экспорта планов подписок';
                
                if (err.response?.status === 500) {
                    errorMessage = 'Внутренняя ошибка сервера при экспорте планов. Попробуйте позже.';
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
        }, 2000); // Проверяем каждые 2 секунды
        
        setIntervalId(newIntervalId);
    };

    const downloadExportFile = async (taskId) => {
        try {
            const token = Cookies.get('token');
            const downloadTaskId = taskId || exportTaskId;
            
            if (!downloadTaskId) {
                setExportInternalError('ID задачи экспорта планов подписок не найден');
                return;
            }
            
            console.log(`Начинаем скачивание файла экспорта планов, TaskId: ${downloadTaskId}`);
            
            // Устанавливаем состояние загрузки
            setIsDownloading(true);
            setDownloadProgress(0);
            
            const response = await axios.get(
                `${API_URL}/admin/download-exported-subscription-plans/${downloadTaskId}`,
                {
                    headers: { Authorization: `Bearer ${token}` },
                    responseType: 'blob',
                    timeout: 120000, // 2 минуты timeout для скачивания планов (файл небольшой)
                    onDownloadProgress: (progressEvent) => {
                        if (progressEvent.total) {
                            const progress = Math.round((progressEvent.loaded / progressEvent.total) * 100);
                            setDownloadProgress(progress);
                            console.log(`Прогресс скачивания планов: ${progress}%`);
                        } else {
                            console.log(`Загружено: ${progressEvent.loaded} байт`);
                        }
                    }
                }
            );

            console.log('Ответ от сервера получен:', {
                status: response.status,
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
            const url = window.URL.createObjectURL(new Blob([response.data]));
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', `subscription_plans_export_${downloadTaskId}.zip`);
            console.log('Инициируем скачивание файла планов подписок');
            
            document.body.appendChild(link);
            link.click();
            link.remove();
            window.URL.revokeObjectURL(url);
            
            console.log('Скачивание файла планов подписок инициировано успешно');
            
            // Сбрасываем состояние загрузки после небольшой задержки
            setTimeout(() => {
                setIsDownloading(false);
                setDownloadProgress(0);
                console.log('Состояние загрузки планов сброшено');
            }, 1000);
        } catch (err) {
            console.error('Error downloading subscription plan export file:', err);
            console.error('Error details:', {
                status: err.response?.status,
                statusText: err.response?.statusText,
                data: err.response?.data,
                headers: err.response?.headers,
                config: err.config,
                message: err.message,
                code: err.code
            });
            
            // Более детальная обработка ошибок
            let errorMessage = 'Ошибка при скачивании файла экспорта планов подписок';
            
            // Обработка ошибок с учетом асинхронности
            const handleError = async () => {
                if (err.code === 'ECONNABORTED') {
                    errorMessage = 'Превышено время ожидания загрузки. Попробуйте еще раз.';
                } else if (err.message === 'Network Error') {
                    errorMessage = 'Ошибка сети. Проверьте подключение к интернету.';
                } else if (err.response?.status === 400) {
                    console.log('400 Error response data:', err.response.data);
                    // Если ответ пришел как Blob, читаем его как текст
                    if (err.response.data instanceof Blob) {
                        try {
                            const errorText = await err.response.data.text();
                            console.log('400 Error blob content:', errorText);
                            
                            // Пытаемся распарсить JSON
                            try {
                                const errorJson = JSON.parse(errorText);
                                errorMessage = `Ошибка сервера: ${errorJson.title || errorJson.detail || errorJson.message || errorText}`;
                            } catch {
                                // Если не JSON, используем как текст
                                errorMessage = `Ошибка сервера: ${errorText}`;
                            }
                        } catch (blobError) {
                            console.error('Error reading blob:', blobError);
                            errorMessage = 'Ошибка чтения ответа сервера.';
                        }
                    } else if (typeof err.response.data === 'string') {
                        errorMessage = `Ошибка сервера: ${err.response.data}`;
                    } else {
                        errorMessage = 'Экспорт планов еще не завершен или завершился с ошибкой.';
                    }
                } else if (err.response?.status === 404) {
                    errorMessage = 'Файл экспорта планов не найден или был удален.';
                } else if (err.response?.status >= 500) {
                    errorMessage = 'Ошибка сервера. Попробуйте еще раз позже.';
                } else if (err.response?.data) {
                    errorMessage += ': ' + err.response.data;
                } else if (err.message) {
                    errorMessage += ': ' + err.message;
                }
                
                console.log(`Setting error message: ${errorMessage}`);
                setExportInternalError(errorMessage);
                setIsDownloading(false);
            };
            
            // Выполняем асинхронную обработку
            handleError();
        }
    };

    const cancelExport = async () => {
        if (exportTaskId) {
            try {
                const token = Cookies.get('token');
                console.log(`Отменяем экспорт планов, TaskId: ${exportTaskId}`);
                
                await axios.post(
                    `${API_URL}/admin/cancel-subscription-plan-export/${exportTaskId}`,
                    null,
                    { 
                        headers: { Authorization: `Bearer ${token}` },
                        timeout: 10000
                    }
                );
                
                if (intervalId) {
                    clearInterval(intervalId);
                }
                
                setIsExporting(false);
                setProgress(null);
                setExportTaskId(null);
                console.log('Экспорт планов подписок отменен');
            } catch (err) {
                console.error('Error cancelling subscription plan export:', err);
                setExportInternalError('Ошибка при отмене экспорта планов подписок: ' + (err.response?.data || err.message));
            }
        }
    };

    return (
        <Box>
            <Typography variant="h6" gutterBottom>
                Экспорт планов подписок
            </Typography>

            {(exportError || exportInternalError) && (
                <Alert severity="error" sx={{ mb: 2 }}>
                    {exportError || exportInternalError}
                </Alert>
            )}

            <Paper sx={{ p: 2, mb: 2 }}>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                    Экспорт всех планов подписок системы в ZIP архив. 
                    Этот файл должен быть импортирован ПЕРВЫМ при миграции на новый сервер.
                </Typography>

                <Box sx={{ mb: 2 }}>
                    <Button
                        variant="contained"
                        onClick={startExport}
                        disabled={isExporting || isLoading || isDownloading}
                        sx={{ mr: 1 }}
                    >
                        {isLoading ? 'Загрузка...' : 'Начать экспорт планов подписок'}
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
                        <Button
                            variant="outlined"
                            onClick={() => downloadExportFile(exportTaskId)}
                            disabled={isDownloading}
                            color="primary"
                            size="small"
                        >
                            Скачать файл планов
                        </Button>
                    )}
                </Box>

                {isExporting && (
                    <Box sx={{ mt: 2 }}>
                        <Typography variant="subtitle2" gutterBottom>
                            Прогресс экспорта планов: {progress !== null ? `${Math.round(progress)}%` : 'Инициализация...'}
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
                                Экспорт планов подписок в процессе...
                            </Typography>
                        </Box>
                    </Box>
                )}
                
                {/* Визуализация загрузки файла */}
                {isDownloading && (
                    <Box sx={{ mt: 2 }}>
                        <Typography variant="subtitle2" gutterBottom>
                            Загрузка файла планов: {Math.round(downloadProgress)}%
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
                                Скачивание файла экспорта планов подписок...
                            </Typography>
                        </Box>
                    </Box>
                )}
            </Paper>
        </Box>
    );
};

export default SubscriptionPlanExport; 