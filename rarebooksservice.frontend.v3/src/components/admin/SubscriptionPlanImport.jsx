import React, { useState, useRef } from 'react';
import {
    Box, Typography, Paper, Button, Alert,
    LinearProgress, CircularProgress, Chip
} from '@mui/material';
import { CloudUpload } from '@mui/icons-material';
import axios from 'axios';
import { API_URL } from '../../api';
import Cookies from 'js-cookie';

const SubscriptionPlanImport = () => {
    const [file, setFile] = useState(null);
    const [importId, setImportId] = useState(null);
    const [uploadProgress, setUploadProgress] = useState(0);
    const [importProgress, setImportProgress] = useState(0);
    const [isUploading, setIsUploading] = useState(false);
    const [isImporting, setIsImporting] = useState(false);
    const [message, setMessage] = useState('');
    const [error, setError] = useState('');
    const [intervalId, setIntervalId] = useState(null);
    const fileInputRef = useRef(null);

    const CHUNK_SIZE = 1024 * 1024; // 1MB chunks для планов подписок

    const handleFileSelect = (event) => {
        const selectedFile = event.target.files[0];
        if (selectedFile) {
            if (!selectedFile.name.endsWith('.zip')) {
                setError('Выберите ZIP файл с экспортом планов подписок');
                return;
            }
            
            setFile(selectedFile);
            setError('');
            setMessage('');
            console.log('Выбран файл планов подписок:', selectedFile.name, selectedFile.size, 'байт');
        }
    };

    const startImport = async () => {
        if (!file) {
            setError('Выберите файл для импорта планов подписок');
            return;
        }

        setError('');
        setMessage('Начинаем импорт планов подписок...');
        setIsUploading(true);
        setUploadProgress(0);

        try {
            const token = Cookies.get('token');
            console.log('Запускаем импорт планов подписок, размер файла:', file.size);

            // 1. Запускаем импорт
            const startResponse = await axios.post(
                `${API_URL}/admin/start-subscription-plan-import?expectedFileSize=${file.size}`,
                null,
                {
                    headers: { Authorization: `Bearer ${token}` },
                    timeout: 30000
                }
            );

            const newImportId = startResponse.data.importId;
            setImportId(newImportId);
            console.log('Импорт планов подписок запущен, ImportId:', newImportId);

            // 2. Загружаем файл частями
            await uploadFileInChunks(newImportId, file, token);

            // 3. Завершаем загрузку
            await finishUpload(newImportId, token);

        } catch (err) {
            console.error('Error starting subscription plan import:', err);
            let errorMessage = 'Ошибка при запуске импорта планов подписок';
            
            if (err.response?.status === 400) {
                errorMessage = err.response.data || 'Неверный формат файла или превышен лимит размера';
            } else if (err.response?.data) {
                errorMessage += ': ' + err.response.data;
            } else if (err.message) {
                errorMessage += ': ' + err.message;
            }
            
            setError(errorMessage);
            setIsUploading(false);
            setIsImporting(false);
        }
    };

    const uploadFileInChunks = async (importId, file, token) => {
        const totalChunks = Math.ceil(file.size / CHUNK_SIZE);
        console.log(`Загружаем файл планов по частям: ${totalChunks} чанков по ${CHUNK_SIZE} байт`);

        for (let i = 0; i < totalChunks; i++) {
            const start = i * CHUNK_SIZE;
            const end = Math.min(start + CHUNK_SIZE, file.size);
            const chunk = file.slice(start, end);

            const formData = new FormData();
            formData.append('chunk', chunk);

            console.log(`Загружаем чанк ${i + 1}/${totalChunks}, размер: ${chunk.size} байт`);

            try {
                await axios.post(
                    `${API_URL}/admin/subscription-plan-import/${importId}/chunk`,
                    formData,
                    {
                        headers: {
                            Authorization: `Bearer ${token}`,
                            'Content-Type': 'multipart/form-data'
                        },
                        timeout: 60000 // 60 секунд для каждого чанка
                    }
                );

                const progress = Math.round(((i + 1) / totalChunks) * 100);
                setUploadProgress(progress);
                console.log(`Чанк ${i + 1}/${totalChunks} загружен, прогресс: ${progress}%`);

            } catch (err) {
                console.error(`Ошибка загрузки чанка ${i + 1}:`, err);
                throw new Error(`Ошибка загрузки части ${i + 1}: ${err.response?.data || err.message}`);
            }
        }

        console.log('Все чанки файла планов загружены');
    };

    const finishUpload = async (importId, token) => {
        console.log('Завершаем загрузку файла планов подписок');
        setMessage('Загрузка завершена, начинаем импорт планов подписок...');

        try {
            await axios.post(
                `${API_URL}/admin/subscription-plan-import/${importId}/finish`,
                null,
                {
                    headers: { Authorization: `Bearer ${token}` },
                    timeout: 30000
                }
            );

            setIsUploading(false);
            setIsImporting(true);
            console.log('Загрузка завершена, начинаем мониторинг импорта');
            startProgressPolling(importId, token);

        } catch (err) {
            console.error('Error finishing subscription plan upload:', err);
            throw new Error('Ошибка при завершении загрузки: ' + (err.response?.data || err.message));
        }
    };

    const startProgressPolling = (importId, token) => {
        console.log('Начинаем мониторинг прогресса импорта планов');
        
        const newIntervalId = setInterval(async () => {
            try {
                const response = await axios.get(
                    `${API_URL}/admin/subscription-plan-import-progress/${importId}`,
                    {
                        headers: { Authorization: `Bearer ${token}` },
                        timeout: 10000
                    }
                );

                const { 
                    uploadProgress: upProgress, 
                    importProgress: impProgress, 
                    isFinished, 
                    isCancelledOrError, 
                    message: progressMessage 
                } = response.data;

                console.log(`Прогресс импорта планов: ${impProgress}%, сообщение: ${progressMessage}`);
                
                setUploadProgress(upProgress);
                setImportProgress(impProgress);
                setMessage(progressMessage || 'Импорт планов подписок в процессе...');

                if (isFinished || isCancelledOrError) {
                    clearInterval(newIntervalId);
                    setIsImporting(false);
                    
                    if (isCancelledOrError) {
                        setError(progressMessage || 'Импорт планов подписок завершился с ошибкой');
                    } else {
                        setMessage(progressMessage || 'Импорт планов подписок успешно завершен!');
                        console.log('Импорт планов подписок завершен успешно');
                    }
                }

            } catch (err) {
                console.error('Error polling subscription plan import progress:', err);
                clearInterval(newIntervalId);
                setIsImporting(false);
                setError('Ошибка при получении прогресса импорта: ' + (err.response?.data || err.message));
            }
        }, 2000); // Проверяем каждые 2 секунды

        setIntervalId(newIntervalId);
    };

    const cancelImport = async () => {
        if (importId) {
            try {
                const token = Cookies.get('token');
                console.log('Отменяем импорт планов подписок, ImportId:', importId);
                
                await axios.post(
                    `${API_URL}/admin/cancel-subscription-plan-import/${importId}`,
                    null,
                    {
                        headers: { Authorization: `Bearer ${token}` },
                        timeout: 10000
                    }
                );

                if (intervalId) {
                    clearInterval(intervalId);
                }

                setIsUploading(false);
                setIsImporting(false);
                setMessage('Импорт планов подписок отменён');
                console.log('Импорт планов подписок отменён');

            } catch (err) {
                console.error('Error cancelling subscription plan import:', err);
                setError('Ошибка при отмене импорта: ' + (err.response?.data || err.message));
            }
        }
    };

    const resetForm = () => {
        setFile(null);
        setImportId(null);
        setUploadProgress(0);
        setImportProgress(0);
        setIsUploading(false);
        setIsImporting(false);
        setMessage('');
        setError('');
        if (intervalId) {
            clearInterval(intervalId);
            setIntervalId(null);
        }
        if (fileInputRef.current) {
            fileInputRef.current.value = '';
        }
        console.log('Форма импорта планов сброшена');
    };

    return (
        <Box>
            <Typography variant="h6" gutterBottom>
                Импорт планов подписок
            </Typography>

            {error && (
                <Alert severity="error" sx={{ mb: 2 }}>
                    {error}
                </Alert>
            )}

            {message && !error && (
                <Alert severity="info" sx={{ mb: 2 }}>
                    {message}
                </Alert>
            )}

            <Paper sx={{ p: 2, mb: 2 }}>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                    Импорт планов подписок из ZIP архива. 
                    ⚠️ ВАЖНО: Планы подписок должны быть импортированы ПЕРВЫМИ перед импортом пользователей!
                </Typography>

                {/* Выбор файла */}
                <Box sx={{ mb: 2 }}>
                    <input
                        type="file"
                        accept=".zip"
                        onChange={handleFileSelect}
                        style={{ display: 'none' }}
                        ref={fileInputRef}
                        disabled={isUploading || isImporting}
                    />
                    <Button
                        variant="outlined"
                        startIcon={<CloudUpload />}
                        onClick={() => fileInputRef.current?.click()}
                        disabled={isUploading || isImporting}
                        sx={{ mr: 1 }}
                    >
                        Выбрать ZIP файл планов
                    </Button>

                    {file && (
                        <Chip
                            label={`${file.name} (${(file.size / 1024 / 1024).toFixed(2)} MB)`}
                            color="primary"
                            sx={{ ml: 1 }}
                        />
                    )}
                </Box>

                {/* Кнопки управления */}
                <Box sx={{ mb: 2 }}>
                    <Button
                        variant="contained"
                        onClick={startImport}
                        disabled={!file || isUploading || isImporting}
                        sx={{ mr: 1 }}
                    >
                        Начать импорт планов
                    </Button>
                    <Button
                        variant="outlined"
                        onClick={cancelImport}
                        disabled={!isUploading && !isImporting}
                        color="error"
                        sx={{ mr: 1 }}
                    >
                        Отменить
                    </Button>
                    <Button
                        variant="outlined"
                        onClick={resetForm}
                        disabled={isUploading || isImporting}
                        color="secondary"
                    >
                        Сбросить
                    </Button>
                </Box>

                {/* Прогресс загрузки */}
                {isUploading && (
                    <Box sx={{ mt: 2 }}>
                        <Typography variant="subtitle2" gutterBottom>
                            Загрузка файла планов: {uploadProgress}%
                        </Typography>
                        <LinearProgress
                            variant="determinate"
                            value={uploadProgress}
                            sx={{ mb: 2 }}
                        />
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                            <CircularProgress size={20} />
                            <Typography variant="body2">
                                Загружаем файл планов подписок на сервер...
                            </Typography>
                        </Box>
                    </Box>
                )}

                {/* Прогресс импорта */}
                {isImporting && (
                    <Box sx={{ mt: 2 }}>
                        <Typography variant="subtitle2" gutterBottom>
                            Импорт планов подписок: {Math.round(importProgress)}%
                        </Typography>
                        <LinearProgress
                            variant="determinate"
                            value={importProgress}
                            sx={{ 
                                mb: 2,
                                height: 10,
                                borderRadius: 5,
                                backgroundColor: '#e0e0e0',
                                '& .MuiLinearProgress-bar': {
                                    backgroundColor: '#1976d2', // синий цвет для импорта
                                    borderRadius: 5
                                }
                            }}
                        />
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                            <CircularProgress size={20} color="primary" />
                            <Typography variant="body2">
                                Импортируем планы подписок в базу данных...
                            </Typography>
                        </Box>
                    </Box>
                )}

                {/* Инструкции */}
                {!isUploading && !isImporting && !file && (
                    <Box sx={{ mt: 2, p: 2, bgcolor: '#f5f5f5', borderRadius: 1 }}>
                        <Typography variant="subtitle2" gutterBottom>
                            📁 Как импортировать планы подписок:
                        </Typography>
                        <Typography variant="body2" component="div">
                            1. Выберите ZIP файл с экспортом планов подписок<br/>
                            2. Нажмите "Начать импорт планов"<br/>
                            3. Дождитесь завершения импорта<br/>
                            4. После этого можно импортировать пользователей
                        </Typography>
                    </Box>
                )}
            </Paper>
        </Box>
    );
};

export default SubscriptionPlanImport; 