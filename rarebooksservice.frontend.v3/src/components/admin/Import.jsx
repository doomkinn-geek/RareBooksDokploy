import React, { useState, useEffect } from 'react';
import {
    Box, Typography, Paper, Button, Collapse,
    LinearProgress, Alert, CircularProgress, TextField, IconButton,
    Accordion, AccordionSummary, AccordionDetails, Divider
} from '@mui/material';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import {
    initImport, uploadImportChunk, finishImport,
    getImportProgress, cancelImport, getAuthHeaders
} from '../../api';
import axios from 'axios';
import { API_URL } from '../../api';

// Создаем глобальный массив для сохранения диагностических логов
const diagnosticLogs = [];

// Функция для записи диагностических данных
const logDiagnostic = (action, data) => {
    const timestamp = new Date().toISOString();
    const logEntry = {
        timestamp,
        action,
        data
    };
    
    console.log(`[DIAGNOSTIC] ${timestamp} - ${action}:`, data);
    diagnosticLogs.push(logEntry);
    
    // Ограничиваем количество логов, чтобы избежать утечки памяти
    if (diagnosticLogs.length > 100) diagnosticLogs.shift();
    
    return logEntry;
};

const Import = () => {
    const [importTaskId, setImportTaskId] = useState(null);
    const [importFile, setImportFile] = useState(null);
    const [importUploadProgress, setImportUploadProgress] = useState(0);
    const [importProgress, setImportProgress] = useState(0);
    const [importMessage, setImportMessage] = useState('');
    const [isImporting, setIsImporting] = useState(false);
    const [importPollIntervalId, setImportPollIntervalId] = useState(null);
    const [error, setError] = useState('');
    
    // Новые состояния для диагностики
    const [diagnosticData, setDiagnosticData] = useState([]);
    const [showDiagnostics, setShowDiagnostics] = useState(false);
    const [lastRequestDetails, setLastRequestDetails] = useState(null);
    const [serverResponded, setServerResponded] = useState(true);
    const [serverCrashInfo, setServerCrashInfo] = useState(null);
    
    // Новые состояния для разделения логики инициализации и загрузки
    const [isInitialized, setIsInitialized] = useState(false);
    const [isUploading, setIsUploading] = useState(false);

    useEffect(() => {
        return () => {
            if (importPollIntervalId) {
                clearInterval(importPollIntervalId);
            }
        };
    }, [importPollIntervalId]);

    useEffect(() => {
        // Периодически обновляем диагностические данные
        const updateDiagnostics = () => {
            setDiagnosticData([...diagnosticLogs]);
        };
        
        const diagnosticsInterval = setInterval(updateDiagnostics, 1000);
        
        return () => clearInterval(diagnosticsInterval);
    }, []);

    const handleFileSelect = (event) => {
        try {
        const file = event.target.files[0];
        if (file) {
                // Базовая валидация файла
                if (file.size > 500 * 1024 * 1024) { // 500MB
                    setError('Файл слишком большой. Максимальный размер - 500MB');
                    return;
                }
                
                if (!file.name.endsWith('.zip')) {
                    setError('Пожалуйста, выберите файл в формате .zip');
                    return;
                }
                
            setImportFile(file);
            setImportMessage('');
            setError('');
            setIsInitialized(false); // Сбрасываем флаг инициализации при выборе нового файла
                
                // Используем простую диагностику без сетевых запросов
                logDiagnostic('FILE_SELECTED', {
                    name: file.name,
                    size: file.size,
                    type: file.type,
                    lastModified: new Date(file.lastModified).toISOString()
                });
            }
        } catch (error) {
            console.error('Ошибка при выборе файла:', error);
            setError('Ошибка при выборе файла: ' + error.message);
            logDiagnostic('FILE_SELECT_ERROR', {
                message: error.message,
                stack: error.stack
            });
        }
    };

    // Функция для анализа момента падения сервера
    const analyzeServerCrash = (error, requestData) => {
        const crashInfo = {
            timeOfCrash: new Date().toISOString(),
            lastSuccessfulOperation: lastRequestDetails?.action || 'Неизвестно',
            lastRequestTime: lastRequestDetails?.timestamp || 'Неизвестно',
            errorDetails: {
                message: error.message,
                code: error.code,
                name: error.name
            },
            requestDetails: requestData
        };
        
        setServerCrashInfo(crashInfo);
        logDiagnostic('SERVER_CRASH_ANALYSIS', crashInfo);
        setServerResponded(false);
        
        return crashInfo;
    };

    // Новая функция только для инициализации импорта
    const initializeImport = async () => {
        if (!importFile) {
            setError('Пожалуйста, выберите файл для импорта');
            return;
        }

        if (importFile.size === 0) {
            setError('Файл пуст');
            return;
        }
        
        // Дополнительная валидация файла перед отправкой
        if (importFile.size > 500 * 1024 * 1024) { // 500MB
            setError('Файл слишком большой. Максимальный размер - 500MB');
            return;
        }
        
        if (!importFile.name.endsWith('.zip')) {
            setError('Формат файла должен быть .zip');
            return;
        }

        setError('');
        setServerResponded(true);
        setServerCrashInfo(null);
        
        try {
            // Инициализация импорта
            logDiagnostic('IMPORT_INIT_START', { fileSize: importFile.size });
            
            const response = await initImport(importFile.size);
            const taskId = response.importTaskId;
            
            logDiagnostic('IMPORT_INIT_SUCCESS', { taskId });
            setImportTaskId(taskId);
            setIsInitialized(true); // Отмечаем, что инициализация успешна
            setImportMessage('Импорт инициализирован. Нажмите "Начать загрузку" для продолжения.');
            
        } catch (err) {
            console.error('Error during import initialization:', err);
            setError('Ошибка при инициализации импорта: ' + (err.response?.data || err.message));
            logDiagnostic('IMPORT_INIT_ERROR', { 
                error: err.message,
                response: err.response ? {
                    status: err.response.status,
                    statusText: err.response.statusText,
                    data: err.response.data
                } : 'No response'
            });
        }
    };

    // Загрузка файла после инициализации
    const startFileUpload = async () => {
        if (!importTaskId || !isInitialized) {
            setError('Импорт не был инициализирован');
            return;
        }
        
        setError('');
        setIsImporting(true);
        setIsUploading(true);
        
        try {
            // Загрузка файла по частям
            const chunkSize = 1024 * 256; // 256KB chunks как в старой версии
            let offset = 0;

            while (offset < importFile.size) {
                const endOffset = Math.min(offset + chunkSize, importFile.size);
                const chunk = importFile.slice(offset, endOffset);
                
                logDiagnostic('CHUNK_UPLOAD_START', { offset, size: endOffset - offset });
                
                // Отправка чанка
                await uploadImportChunk(
                    importTaskId, 
                    chunk, 
                    (progressEvent) => {
                        if (progressEvent.total) {
                            const progress = Math.round((progressEvent.loaded / progressEvent.total) * 100);
                            if (progress % 25 === 0) {
                                logDiagnostic('CHUNK_UPLOAD_PROGRESS', { progress });
                            }
                        }
                    }
                );
                
                // Инкрементируем смещение и обновляем прогресс
                offset = endOffset;
                setImportUploadProgress((offset / importFile.size) * 100);
            }

            // Завершение загрузки и начало импорта
            logDiagnostic('IMPORT_FINISH_START', { taskId: importTaskId });

            await finishImport(importTaskId);
            
            logDiagnostic('IMPORT_FINISH_SUCCESS', { taskId: importTaskId });
            setIsUploading(false);
            
            startPollingProgress(importTaskId);
            
        } catch (err) {
            console.error('Error during file upload:', err);
            
            // Если возникла ошибка, попробуем отменить импорт
            try {
                await cancelImport(importTaskId);
                logDiagnostic('IMPORT_CANCELLED', { taskId: importTaskId, reason: err.message });
            } catch (cancelErr) {
                logDiagnostic('IMPORT_CANCEL_ERROR', { 
                    taskId: importTaskId, 
                    error: cancelErr.message 
                });
            }
            
            setError('Ошибка при загрузке файла: ' + (err.response?.data || err.message));
            setIsImporting(false);
            setIsUploading(false);
            setImportTaskId(null);
            setIsInitialized(false);
        }
    };

    // Полная последовательность импорта (для обратной совместимости)
    const startImport = async () => {
        if (!importFile) {
            setError('Пожалуйста, выберите файл для импорта');
            return;
        }

        await initializeImport();
        if (isInitialized) {
            await startFileUpload();
        }
    };

    const startPollingProgress = (taskId) => {
        const intervalId = setInterval(async () => {
            try {
                logDiagnostic('POLLING_PROGRESS_START', { taskId });
                
                // Проверяем доступность сервера перед запросом прогресса
                if (!serverResponded) {
                    logDiagnostic('POLLING_SKIPPED_SERVER_DOWN', { taskId });
                    clearInterval(intervalId);
                    setIsImporting(false);
                    setError('Сервер перестал отвечать. Импорт мог быть успешным, но не удалось получить статус.');
                    return;
                }
                
                try {
                    const progressResponse = await getImportProgress(taskId);
                    logDiagnostic('POLLING_PROGRESS_RESPONSE', progressResponse);
                    
                    // Устанавливаем флаг, что сервер ответил
                    setServerResponded(true);
                    
                    setImportProgress(progressResponse.importProgress);
                    setImportMessage(progressResponse.message);

                    if (progressResponse.isFinished || progressResponse.isCancelledOrError) {
                    clearInterval(intervalId);
                    setIsImporting(false);
                    setImportTaskId(null);
                    setImportFile(null);
                    
                        if (progressResponse.isFinished) {
                            logDiagnostic('IMPORT_FINISHED', { taskId, message: progressResponse.message });
                        }
                        
                        if (progressResponse.isCancelledOrError) {
                            logDiagnostic('IMPORT_ERROR', { 
                                taskId, 
                                error: progressResponse.message || 'Импорт был отменен или произошла ошибка'
                            });
                            setError(progressResponse.message || 'Импорт был отменен или произошла ошибка');
                        }
                    }
                } catch (pollError) {
                    // Если при опросе прогресса произошла ошибка
                    logDiagnostic('POLLING_PROGRESS_ERROR', {
                        message: pollError.message,
                        code: pollError.code,
                        name: pollError.name,
                        response: pollError.response ? {
                            status: pollError.response.status,
                            statusText: pollError.response.statusText
                        } : null
                    });
                    
                    // Если сервер перестал отвечать, отмечаем это
                    if (!pollError.response || pollError.code === 'ECONNABORTED' || pollError.code === 'ECONNREFUSED') {
                        setServerResponded(false);
                        // Не прерываем интервал сразу, дадим серверу возможность восстановиться
                        // Но поместим эту логику в основной блок try/catch
                        throw pollError;
                    }
                }
            } catch (err) {
                console.error('Error polling import progress:', err);
                
                // Анализируем ошибку чтобы понять - это обычная ошибка или сервер упал
                const errorDetails = {
                    message: err.message,
                    code: err.code,
                    name: err.name,
                    response: err.response ? {
                        status: err.response.status,
                        statusText: err.response.statusText,
                        data: err.response.data
                    } : 'No response'
                };
                
                // Подсчитываем количество последовательных ошибок
                // Если больше 3, считаем что сервер упал и прекращаем опрос
                if (!serverResponded) {
                    logDiagnostic('SERVER_UNRESPONSIVE', errorDetails);
                clearInterval(intervalId);
                setIsImporting(false);
                    setError('Сервер не отвечает. Импорт мог быть запущен, но не удалось получить статус.');
                }
            }
        }, 2000); // Увеличиваем интервал с 1000 до 2000 мс для снижения нагрузки
        setImportPollIntervalId(intervalId);
    };

    const handleCancel = async () => {
        if (importTaskId) {
            try {
                logDiagnostic('CANCEL_IMPORT_START', { taskId: importTaskId });
                
                // Проверяем, доступен ли сервер
                if (!serverResponded) {
                    logDiagnostic('CANCEL_SKIPPED_SERVER_DOWN', { taskId: importTaskId });
                    
                    // Если сервер недоступен, просто очищаем состояние на клиенте
                    if (importPollIntervalId) {
                        clearInterval(importPollIntervalId);
                        setImportPollIntervalId(null);
                    }
                    
                    setIsImporting(false);
                    setImportTaskId(null);
                    setImportFile(null);
                    setImportMessage('Импорт отменен (сервер был недоступен)');
                    
                    return;
                }
                
                const response = await cancelImport(importTaskId);
                logDiagnostic('CANCEL_IMPORT_SUCCESS', { 
                    taskId: importTaskId,
                    response: response ? {
                        status: response.status,
                        statusText: response.statusText
                    } : null
                });
                
                if (importPollIntervalId) {
                    clearInterval(importPollIntervalId);
                    setImportPollIntervalId(null);
                }
                
                setIsImporting(false);
                setImportTaskId(null);
                setImportFile(null);
                setImportMessage('Импорт отменен');
            } catch (err) {
                logDiagnostic('CANCEL_IMPORT_ERROR', { 
                    taskId: importTaskId,
                    error: {
                        message: err.message,
                        code: err.code,
                        name: err.name
                    }
                });
                
                console.error('Error cancelling import:', err);
                setError('Ошибка при отмене импорта: ' + (err.response?.data || err.message));
                
                // Если ошибка связана с недоступностью сервера, отмечаем это
                if (!err.response || err.code === 'ECONNABORTED' || err.code === 'ECONNREFUSED') {
                    setServerResponded(false);
                }
            }
        }
    };

    // Функция для отображения диагностических данных в удобном формате
    const renderDiagnosticData = () => {
        return (
            <Box sx={{ mt: 3, mb: 2 }}>
                <Accordion sx={{ bgcolor: '#f8f8f8' }}>
                    <AccordionSummary expandIcon={<ExpandMoreIcon />}>
                        <Typography variant="subtitle1" fontWeight="bold">
                            Диагностические данные {diagnosticData.length > 0 ? `(${diagnosticData.length})` : ''}
                        </Typography>
                    </AccordionSummary>
                    <AccordionDetails>
                        <Box sx={{ maxHeight: '400px', overflow: 'auto', bgcolor: '#f3f3f3', p: 1, borderRadius: 1 }}>
                            {diagnosticData.length === 0 ? (
                                <Typography color="text.secondary">Нет данных</Typography>
                            ) : (
                                diagnosticData.map((log, index) => (
                                    <Box 
                                        key={index}
                                        sx={{ 
                                            mb: 1, 
                                            p: 1, 
                                            bgcolor: 'white', 
                                            border: '1px solid #e0e0e0',
                                            borderRadius: 1,
                                            fontSize: '0.85rem'
                                        }}
                                    >
                                        <Typography 
                                            variant="caption" 
                                            component="div" 
                                            sx={{ 
                                                color: log.action.includes('ERROR') || log.action.includes('CRASH') 
                                                    ? 'error.main' 
                                                    : log.action.includes('SUCCESS')
                                                        ? 'success.main'
                                                        : 'primary.main',
                                                fontWeight: 'bold'
                                            }}
                                        >
                                            {log.timestamp} - {log.action}
                                        </Typography>
                                        <Typography 
                                            variant="body2" 
                                            component="pre" 
                                            sx={{ 
                                                mt: 0.5, 
                                                whiteSpace: 'pre-wrap', 
                                                wordBreak: 'break-word', 
                                                fontSize: '0.75rem',
                                                bgcolor: '#f7f7f7',
                                                p: 0.5,
                                                borderRadius: 0.5,
                                                maxHeight: '100px',
                                                overflow: 'auto'
                                            }}
                                        >
                                            {JSON.stringify(log.data, null, 2)}
                                        </Typography>
                                    </Box>
                                ))
                            )}
                        </Box>
                    </AccordionDetails>
                </Accordion>
                
                {/* Отображение информации о сбое сервера */}
                {serverCrashInfo && (
                    <Alert 
                        severity="error" 
                        sx={{ mt: 2, mb: 2 }}
                    >
                        <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                            Обнаружен сбой сервера
                        </Typography>
                        
                        <Box sx={{ mb: 1 }}>
                            <Typography variant="body2">
                                <strong>Время сбоя:</strong> {serverCrashInfo.timeOfCrash}
                            </Typography>
                            <Typography variant="body2">
                                <strong>Последняя успешная операция:</strong> {serverCrashInfo.lastSuccessfulOperation}
                            </Typography>
                            <Typography variant="body2">
                                <strong>Ошибка:</strong> {serverCrashInfo.errorDetails.message}
                            </Typography>
                        </Box>
                        
                        <Box sx={{ mt: 1 }}>
                            <Typography variant="body2" fontWeight="bold">
                                Возможные причины сбоя:
                            </Typography>
                            <ul>
                                <li>Недостаточно памяти на сервере для обработки файла</li>
                                <li>Ошибка при разборе импортируемого файла</li>
                                <li>Конфликт данных в импортируемом файле</li>
                                <li>Внутренняя ошибка сервера при обработке данных</li>
                            </ul>
                        </Box>
                        
                        <Box sx={{ mt: 1 }}>
                            <Typography variant="body2" fontWeight="bold">
                                Рекомендации:
                            </Typography>
                            <ul>
                                <li>Проверьте формат и содержимое импортируемого файла</li>
                                <li>Попробуйте загрузить файл меньшего размера</li>
                                <li>Обратитесь к системному администратору с деталями ошибки</li>
                            </ul>
                        </Box>
                    </Alert>
                )}
            </Box>
        );
    };

    return (
        <Box>
            <Typography variant="h6" gutterBottom>
                Импорт данных
            </Typography>

            {error && (
                <Alert 
                    severity="error" 
                    sx={{ mb: 2 }}
                >
                    <div>
                        <Typography variant="body1" component="div" sx={{ mb: 1 }}>
                            {error}
                        </Typography>
                        
                        {(error.includes('сервер') || error.includes('подключ')) && (
                            <Box sx={{ mt: 1, fontSize: '0.9rem' }}>
                                <Typography variant="subtitle2" gutterBottom>
                                    Возможные решения:
                                </Typography>
                                <ul style={{ marginTop: '4px', paddingLeft: '20px' }}>
                                    <li>Убедитесь, что сервер запущен и работает</li>
                                    <li>Проверьте сетевое подключение</li>
                                    <li>Обратитесь к администратору системы</li>
                                </ul>
                            </Box>
                        )}
                    </div>
                </Alert>
            )}

            <Paper sx={{ p: 2, mb: 2 }}>
                <Box sx={{ mb: 2 }}>
                    <input
                        type="file"
                        accept=".zip"
                        onChange={handleFileSelect}
                        disabled={isImporting}
                        style={{ display: 'none' }}
                        id="import-file-input"
                    />
                    <label htmlFor="import-file-input">
                        <Button
                            variant="contained"
                            component="span"
                            disabled={isImporting}
                        >
                            Выбрать файл
                        </Button>
                    </label>
                    {importFile && (
                        <Typography variant="body2" sx={{ mt: 1 }}>
                            Выбран файл: {importFile.name}
                        </Typography>
                    )}
                </Box>

                <Box sx={{ mb: 2 }}>
                    <Button
                        variant="contained"
                        onClick={initializeImport}
                        disabled={!importFile || isImporting || isInitialized}
                        sx={{ mr: 1 }}
                    >
                        Инициализировать импорт
                    </Button>
                    <Button
                        variant="contained"
                        onClick={startFileUpload}
                        disabled={!isInitialized || isImporting || isUploading}
                        sx={{ mr: 1 }}
                        color="primary"
                    >
                        Начать загрузку
                    </Button>
                    <Button
                        variant="contained"
                        onClick={startImport}
                        disabled={!importFile || isImporting}
                        sx={{ mr: 1 }}
                    >
                        Начать полный импорт
                    </Button>
                    <Button
                        variant="outlined"
                        onClick={handleCancel}
                        disabled={!isImporting && !isInitialized}
                        color="error"
                        sx={{ mr: 1 }}
                    >
                        Отменить
                    </Button>
                    <Button
                        variant="outlined"
                        onClick={() => setShowDiagnostics(!showDiagnostics)}
                        color="info"
                    >
                        {showDiagnostics ? 'Скрыть диагностику' : 'Показать диагностику'}
                    </Button>
                </Box>

                {isImporting && (
                    <Box sx={{ mt: 2 }}>
                        <Typography variant="subtitle2" gutterBottom>
                            Загрузка файла: {Math.round(importUploadProgress)}%
                        </Typography>
                        <LinearProgress 
                            variant="determinate" 
                            value={importUploadProgress} 
                            sx={{ mb: 2 }}
                        />

                        <Typography variant="subtitle2" gutterBottom>
                            Прогресс импорта: {Math.round(importProgress)}%
                        </Typography>
                        <LinearProgress 
                            variant="determinate" 
                            value={importProgress} 
                            sx={{ mb: 2 }}
                        />

                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                            <CircularProgress size={20} />
                            <Typography variant="body2">
                                {importMessage || 'Импорт в процессе...'}
                            </Typography>
                        </Box>
                    </Box>
                )}
                
                {/* Отображение диагностических данных */}
                {showDiagnostics && renderDiagnosticData()}
            </Paper>
        </Box>
    );
};

export default Import; 