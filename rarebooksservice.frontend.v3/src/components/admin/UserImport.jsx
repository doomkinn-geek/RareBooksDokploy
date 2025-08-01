import React, { useState, useEffect } from 'react';
import {
    Box, Typography, Button, LinearProgress, Alert, Paper
} from '@mui/material';
import axios from 'axios';
import { API_URL } from '../../api';
import Cookies from 'js-cookie';

const UserImport = () => {
    const [importTaskId, setImportTaskId] = useState(null);
    const [importFile, setImportFile] = useState(null);
    const [importUploadProgress, setImportUploadProgress] = useState(0);
    const [importProgress, setImportProgress] = useState(0);
    const [importMessage, setImportMessage] = useState('');
    const [isImporting, setIsImporting] = useState(false);
    const [pollIntervalId, setPollIntervalId] = useState(null);

    // Очистка интервала при размонтировании
    useEffect(() => {
        return () => {
            if (pollIntervalId) {
                clearInterval(pollIntervalId);
            }
        };
    }, [pollIntervalId]);

    // Шаг 1: Инициализация импорта пользователей
    const initImportTask = async (fileSize) => {
        try {
            const fileSizeNumber = Number(fileSize);
            console.log(`Инициализация задачи импорта пользователей, размер файла: ${fileSizeNumber} байт`);
            
            if (isNaN(fileSizeNumber) || fileSizeNumber <= 0) {
                throw new Error(`Некорректный размер файла: ${fileSize}`);
            }
            
            const token = Cookies.get('token');
            const response = await axios.post(
                `${API_URL}/useradmin/init-user-import?fileSize=${fileSizeNumber}`,
                null,
                { headers: { Authorization: `Bearer ${token}` } }
            );
            
            const taskId = response.data.importTaskId;
            console.log(`Инициализация импорта пользователей успешна, получен ID задачи: ${taskId}`);
            setImportTaskId(taskId);
            return taskId;
        } catch (error) {
            console.error("Ошибка инициализации импорта пользователей:", error);
            throw error;
        }
    };

    // Шаг 2: Загрузка файла по кускам
    const uploadFileChunks = async (file, taskId) => {
        const chunkSize = 1024 * 256; // 256 KB
        let offset = 0;
        const token = Cookies.get('token');
        
        while (offset < file.size) {
            const slice = file.slice(offset, offset + chunkSize);

            try {
                await axios.post(
                    `${API_URL}/useradmin/upload-user-chunk/${taskId}`,
                    slice,
                    {
                        headers: { 
                            Authorization: `Bearer ${token}`,
                            'Content-Type': 'application/octet-stream'
                        }
                    }
                );
            } catch (error) {
                console.error('Ошибка загрузки chunk:', error);
                throw error;
            }

            offset += chunkSize;
            const overallPct = Math.round((offset * 100) / file.size);
            setImportUploadProgress(overallPct);
        }
    };

    // Шаг 3: Завершение загрузки
    const finishUpload = async (taskId) => {
        const token = Cookies.get('token');
        await axios.post(
            `${API_URL}/useradmin/finish-user-upload/${taskId}`,
            null,
            { headers: { Authorization: `Bearer ${token}` } }
        );
    };

    // Опрос прогресса на сервере
    const pollImportProgress = async (taskId) => {
        if (!taskId) return;
        try {
            const token = Cookies.get('token');
            const response = await axios.get(
                `${API_URL}/useradmin/user-import-progress/${taskId}`,
                { headers: { Authorization: `Bearer ${token}` } }
            );
            
            const data = response.data;
            
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
            console.error('Ошибка опроса импорта пользователей:', err);
        }
    };

    // Запуск импорта пользователей
    const handleImportData = async () => {
        if (!importFile) {
            setImportMessage('Не выбран файл для импорта');
            return;
        }
        
        // Проверяем расширение файла
        if (!importFile.name.toLowerCase().endsWith('.zip')) {
            setImportMessage('Выберите ZIP файл с экспортированными данными пользователей');
            return;
        }
        
        setIsImporting(true);
        setImportUploadProgress(0);
        setImportProgress(0);
        setImportMessage('');

        try {
            console.log(`Запуск импорта пользователей для файла: ${importFile.name}, размер: ${importFile.size} байт`);
            
            // Шаг 1: init
            const newTaskId = await initImportTask(importFile.size);
            console.log(`Получен importTaskId: ${newTaskId}`);

            // Шаг 2: upload
            await uploadFileChunks(importFile, newTaskId);
            console.log(`Загрузка файла завершена`);

            // Шаг 3: finish
            await finishUpload(newTaskId);
            console.log(`Процесс импорта пользователей запущен на сервере`);

            // Шаг 4: запустим периодический опрос статуса
            const pid = setInterval(() => {
                pollImportProgress(newTaskId);
            }, 1000);
            setPollIntervalId(pid);
        } catch (err) {
            console.error('Ошибка импорта пользователей:', err);
            setIsImporting(false);
            
            // Более детальная обработка ошибок
            if (!err.response) {
                setImportMessage('Ошибка соединения с сервером. Проверьте подключение и SSL-сертификаты.');
            } else if (err.response.status === 403) {
                setImportMessage('Ошибка доступа. Импорт пользователей доступен только администраторам.');
            } else if (err.response.status === 400) {
                const errorDetails = err.response.data ? 
                    (typeof err.response.data === 'string' ? err.response.data : JSON.stringify(err.response.data)) : 
                    'Неизвестная ошибка';
                setImportMessage(`Ошибка в запросе (400): ${errorDetails}`);
            } else {
                setImportMessage(`Ошибка импорта пользователей: ${err.message || 'Неизвестная ошибка'}`);
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
            const token = Cookies.get('token');
            await axios.post(
                `${API_URL}/useradmin/cancel-user-import/${importTaskId}`,
                null,
                { headers: { Authorization: `Bearer ${token}` } }
            );
            
            setImportMessage('Импорт пользователей отменён');
            setIsImporting(false);
            if (pollIntervalId) {
                clearInterval(pollIntervalId);
                setPollIntervalId(null);
            }
        } catch (err) {
            console.error('Ошибка при отмене импорта пользователей:', err);
            setImportMessage('Ошибка при отмене импорта пользователей');
        }
    };

    return (
        <Box>
            <Typography variant="h6" gutterBottom>
                Импорт пользователей
            </Typography>

            <Paper sx={{ p: 2, mb: 2 }}>
                <Typography variant="body2" sx={{ mb: 2, color: 'text.secondary' }}>
                    Импорт восстанавливает данные пользователей, историю поиска, подписки и избранные книги из ZIP архива.
                    <br />
                    <strong>Внимание:</strong> Пользователи с существующими email будут пропущены.
                </Typography>
                
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, maxWidth: 500 }}>
                    {/* Кнопка выбора файла */}
                    <Button 
                        variant="outlined" 
                        component="label"
                        disabled={isImporting}
                    >
                        Выбрать ZIP файл для импорта пользователей
                        <input 
                            type="file" 
                            hidden 
                            accept=".zip"
                            onChange={handleSelectImportFile} 
                        />
                    </Button>

                    {importFile && (
                        <Typography variant="body2" sx={{ color: 'success.main' }}>
                            Выбран файл: {importFile.name} ({(importFile.size / 1024 / 1024).toFixed(2)} MB)
                        </Typography>
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
                            disabled={!importFile}
                        >
                            Начать импорт пользователей
                        </Button>
                    )}

                    {/* Отображаем прогресс загрузки и обработки, если > 0 */}
                    {(importUploadProgress > 0 || importProgress > 0) && (
                        <Box>
                            <Typography variant="body2" sx={{ mb: 1 }}>
                                Загрузка файла: {importUploadProgress}%
                            </Typography>
                            <LinearProgress 
                                variant="determinate" 
                                value={importUploadProgress} 
                                sx={{ mb: 2 }}
                            />
                            
                            <Typography variant="body2" sx={{ mb: 1 }}>
                                Обработка данных: {importProgress}%
                            </Typography>
                            <LinearProgress 
                                variant="determinate" 
                                value={importProgress}
                                color="secondary"
                            />
                        </Box>
                    )}

                    {/* Сообщения от сервера */}
                    {importMessage && (
                        <Alert 
                            severity={
                                importMessage.includes('Ошибка') || importMessage.includes('ошибка') ? 'error' :
                                importMessage.includes('завершён') || importMessage.includes('Импортировано') ? 'success' :
                                'info'
                            } 
                            sx={{ mt: 2 }}
                        >
                            {importMessage}
                        </Alert>
                    )}
                </Box>
            </Paper>
        </Box>
    );
};

export default UserImport;