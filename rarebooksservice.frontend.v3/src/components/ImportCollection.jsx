import React, { useState } from 'react';
import {
    Box, Typography, Button, Paper, Alert, CircularProgress,
    LinearProgress, List, ListItem, ListItemText, Divider
} from '@mui/material';
import {
    CloudUpload as UploadIcon,
    CheckCircle as SuccessIcon,
    Error as ErrorIcon
} from '@mui/icons-material';
import axios from 'axios';
import { API_URL } from '../api';
import Cookies from 'js-cookie';

const ImportCollection = ({ onImportComplete }) => {
    const [file, setFile] = useState(null);
    const [importing, setImporting] = useState(false);
    const [result, setResult] = useState(null);
    const [error, setError] = useState('');

    const handleFileSelect = (event) => {
        const selectedFile = event.target.files[0];
        if (selectedFile) {
            if (selectedFile.type === 'application/json' || selectedFile.name.endsWith('.json')) {
                setFile(selectedFile);
                setError('');
                setResult(null);
            } else {
                setError('Пожалуйста, выберите JSON файл');
                setFile(null);
            }
        }
    };

    const handleImport = async () => {
        if (!file) {
            setError('Выберите файл для импорта');
            return;
        }

        setImporting(true);
        setError('');
        setResult(null);

        try {
            // Читаем файл
            const fileContent = await file.text();
            const importData = JSON.parse(fileContent);

            // Отправляем на сервер
            const token = Cookies.get('token');
            const response = await axios.post(`${API_URL}/usercollection/import`, importData, {
                headers: { 
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });

            setResult(response.data);
            
            if (response.data.success && onImportComplete) {
                // Уведомляем родительский компонент об успешном импорте
                setTimeout(() => onImportComplete(), 2000);
            }
        } catch (err) {
            console.error('Error importing collection:', err);
            if (err.response?.data?.message) {
                setError(err.response.data.message);
            } else if (err.message.includes('JSON')) {
                setError('Ошибка чтения файла. Убедитесь, что это валидный JSON файл');
            } else {
                setError('Не удалось импортировать коллекцию');
            }
        } finally {
            setImporting(false);
        }
    };

    return (
        <Paper elevation={3} sx={{ p: 3 }}>
            <Typography variant="h6" gutterBottom>
                Импорт коллекции
            </Typography>

            <Typography variant="body2" color="text.secondary" paragraph>
                Загрузите JSON файл, созданный с помощью утилиты RareBooksImporter
            </Typography>

            {error && (
                <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>
                    {error}
                </Alert>
            )}

            {result && (
                <Alert 
                    severity={result.success ? "success" : "warning"} 
                    sx={{ mb: 2 }}
                    icon={result.success ? <SuccessIcon /> : <ErrorIcon />}
                >
                    <Typography variant="body2" fontWeight="bold">
                        {result.message}
                    </Typography>
                    
                    {result.errors && result.errors.length > 0 && (
                        <Box sx={{ mt: 1 }}>
                            <Typography variant="caption" display="block" gutterBottom>
                                Ошибки:
                            </Typography>
                            <List dense>
                                {result.errors.slice(0, 5).map((err, idx) => (
                                    <ListItem key={idx} sx={{ py: 0, px: 1 }}>
                                        <ListItemText 
                                            primary={err} 
                                            primaryTypographyProps={{ variant: 'caption' }}
                                        />
                                    </ListItem>
                                ))}
                                {result.errors.length > 5 && (
                                    <ListItem sx={{ py: 0, px: 1 }}>
                                        <ListItemText 
                                            primary={`... и ещё ${result.errors.length - 5} ошибок`}
                                            primaryTypographyProps={{ variant: 'caption', fontStyle: 'italic' }}
                                        />
                                    </ListItem>
                                )}
                            </List>
                        </Box>
                    )}
                </Alert>
            )}

            <Box sx={{ mb: 2 }}>
                <input
                    accept="application/json,.json"
                    style={{ display: 'none' }}
                    id="import-file-input"
                    type="file"
                    onChange={handleFileSelect}
                />
                <label htmlFor="import-file-input">
                    <Button
                        variant="outlined"
                        component="span"
                        startIcon={<UploadIcon />}
                        disabled={importing}
                        fullWidth
                    >
                        Выбрать JSON файл
                    </Button>
                </label>
            </Box>

            {file && (
                <Box sx={{ mb: 2, p: 2, bgcolor: 'grey.100', borderRadius: 1 }}>
                    <Typography variant="body2">
                        <strong>Выбран файл:</strong> {file.name}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                        Размер: {(file.size / 1024).toFixed(2)} KB
                    </Typography>
                </Box>
            )}

            {importing && (
                <Box sx={{ mb: 2 }}>
                    <LinearProgress />
                    <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                        Импортирование данных...
                    </Typography>
                </Box>
            )}

            <Button
                variant="contained"
                onClick={handleImport}
                disabled={!file || importing}
                fullWidth
                startIcon={importing ? <CircularProgress size={20} /> : <UploadIcon />}
            >
                {importing ? 'Импортирование...' : 'Импортировать коллекцию'}
            </Button>

            <Divider sx={{ my: 3 }} />

            <Typography variant="caption" color="text.secondary" paragraph>
                <strong>Инструкция:</strong>
            </Typography>
            <Typography variant="caption" color="text.secondary" component="div">
                1. Используйте утилиту RareBooksImporter для конвертации XLSX в JSON
                <br />
                2. Команда: <code>dotnet run books.xlsx collection.json</code>
                <br />
                3. Загрузите созданный JSON файл через эту форму
                <br />
                4. После импорта книги появятся в вашей коллекции
            </Typography>
        </Paper>
    );
};

export default ImportCollection;

