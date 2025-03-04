import React, { useState, useEffect } from 'react';
import {
    Box, Typography, Paper, Button,
    LinearProgress, Alert, CircularProgress
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
    const [importPollIntervalId, setImportPollIntervalId] = useState(null);
    const [error, setError] = useState('');

    useEffect(() => {
        return () => {
            if (importPollIntervalId) {
                clearInterval(importPollIntervalId);
            }
        };
    }, [importPollIntervalId]);

    const handleFileSelect = (event) => {
        const file = event.target.files[0];
        if (file) {
            setImportFile(file);
            setImportMessage('');
            setError('');
        }
    };

    const startImport = async () => {
        if (!importFile) {
            setError('Пожалуйста, выберите файл для импорта');
            return;
        }

        if (importFile.size === 0) {
            setError('Файл пуст');
            return;
        }

        setError('');
        setIsImporting(true);
        try {
            const taskId = await initImport(importFile.size);
            setImportTaskId(taskId);

            const chunkSize = 1024 * 1024; // 1MB chunks
            let offset = 0;

            while (offset < importFile.size) {
                const chunk = importFile.slice(offset, offset + chunkSize);
                await uploadImportChunk(taskId, chunk);
                offset += chunkSize;
                setImportUploadProgress((offset / importFile.size) * 100);
            }

            await finishImport(taskId);
            startPollingProgress(taskId);
        } catch (err) {
            console.error('Error starting import:', err);
            setError('Ошибка при импорте: ' + (err.response?.data || err.message));
            setIsImporting(false);
        }
    };

    const startPollingProgress = (taskId) => {
        const intervalId = setInterval(async () => {
            try {
                const progress = await getImportProgress(taskId);
                setImportProgress(progress.importProgress);
                setImportMessage(progress.message);

                if (progress.isFinished || progress.isCancelledOrError) {
                    clearInterval(intervalId);
                    setIsImporting(false);
                    setImportTaskId(null);
                    setImportFile(null);
                    
                    if (progress.isCancelledOrError) {
                        setError(progress.message || 'Импорт был отменен или произошла ошибка');
                    }
                }
            } catch (err) {
                console.error('Error polling import progress:', err);
                clearInterval(intervalId);
                setIsImporting(false);
                setError('Ошибка при получении прогресса импорта: ' + (err.response?.data || err.message));
            }
        }, 1000);
        setImportPollIntervalId(intervalId);
    };

    const handleCancel = async () => {
        if (importTaskId) {
            try {
                await cancelImport(importTaskId);
                if (importPollIntervalId) {
                    clearInterval(importPollIntervalId);
                }
                setIsImporting(false);
                setImportTaskId(null);
                setImportFile(null);
                setImportMessage('Импорт отменен');
            } catch (err) {
                console.error('Error cancelling import:', err);
                setError('Ошибка при отмене импорта');
            }
        }
    };

    return (
        <Box>
            <Typography variant="h6" gutterBottom>
                Импорт данных
            </Typography>

            {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

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
                        onClick={startImport}
                        disabled={!importFile || isImporting}
                        sx={{ mr: 1 }}
                    >
                        Начать импорт
                    </Button>
                    <Button
                        variant="outlined"
                        onClick={handleCancel}
                        disabled={!isImporting}
                        color="error"
                    >
                        Отменить
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
            </Paper>
        </Box>
    );
};

export default Import; 