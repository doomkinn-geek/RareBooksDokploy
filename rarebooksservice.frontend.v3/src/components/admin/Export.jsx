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
                    downloadExportFile(taskId);
                }
            } catch (err) {
                console.error('Error polling export progress:', err);
                setExportInternalError('Ошибка при получении прогресса экспорта: ' + (err.response?.data || err.message));
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
            
            // Устанавливаем состояние загрузки
            setIsDownloading(true);
            setDownloadProgress(0);
            
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
                        }
                    }
                }
            );

            // Проверяем, что ответ содержит данные
            if (!response.data || response.data.size === 0) {
                throw new Error('Получен пустой файл');
            }

            const url = window.URL.createObjectURL(new Blob([response.data]));
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', `export_${downloadTaskId}.zip`);
            document.body.appendChild(link);
            link.click();
            link.remove();
            window.URL.revokeObjectURL(url);
            
            // Сбрасываем состояние загрузки после небольшой задержки,
            // чтобы пользователь успел увидеть 100%
            setTimeout(() => {
                setIsDownloading(false);
                setDownloadProgress(0);
            }, 1000);
        } catch (err) {
            console.error('Error downloading export file:', err);
            
            // Более детальная обработка ошибок
            let errorMessage = 'Ошибка при скачивании файла экспорта';
            
            if (err.code === 'ECONNABORTED') {
                errorMessage = 'Превышено время ожидания загрузки. Попробуйте еще раз.';
            } else if (err.message === 'Network Error') {
                errorMessage = 'Ошибка сети. Проверьте подключение к интернету.';
            } else if (err.response?.status === 404) {
                errorMessage = 'Файл экспорта не найден или был удален.';
            } else if (err.response?.status >= 500) {
                errorMessage = 'Ошибка сервера. Попробуйте еще раз позже.';
            } else if (err.message) {
                errorMessage += ': ' + err.message;
            }
            
            setExportInternalError(errorMessage);
            setIsDownloading(false);
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
                    >
                        Отменить
                    </Button>
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