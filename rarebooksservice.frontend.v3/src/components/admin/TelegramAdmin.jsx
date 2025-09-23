import React, { useState, useEffect } from 'react';
import {
    Box, Card, CardContent, Typography, Button, TextField, 
    Alert, CircularProgress, Chip, Divider, Grid, Paper,
    Dialog, DialogTitle, DialogContent, DialogActions,
    Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
    Accordion, AccordionSummary, AccordionDetails, IconButton,
    Tooltip, Switch, FormControlLabel, Snackbar
} from '@mui/material';
import {
    CheckCircle, Error, Warning, Refresh, Send, Settings,
    ExpandMore, Launch, Computer, CloudUpload, BugReport,
    Telegram, Message, Assessment, VpnKey, CloudDone,
    Schedule, People, NotificationsActive
} from '@mui/icons-material';
import { API_URL } from '../../api';
import axios from 'axios';

const TelegramAdmin = () => {
    // Состояния для диагностики
    const [diagnostics, setDiagnostics] = useState(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    
    // Состояния для webhook
    const [webhookUrl, setWebhookUrl] = useState('https://rare-books.ru');
    const [webhookLoading, setWebhookLoading] = useState(false);
    
    // Состояния для тестового сообщения
    const [testChatId, setTestChatId] = useState('');
    const [testMessage, setTestMessage] = useState('🔧 Тестовое сообщение от админ панели');
    const [testLoading, setTestLoading] = useState(false);
    
    // Состояния для тестирования уведомлений
    const [notificationTestLimit, setNotificationTestLimit] = useState(50);
    const [notificationShowBookIds, setNotificationShowBookIds] = useState(false);
    const [notificationTestLoading, setNotificationTestLoading] = useState(false);
    const [notificationTestResult, setNotificationTestResult] = useState(null);
    
    // Состояния для диалогов
    const [diagnosticsDialog, setDiagnosticsDialog] = useState(false);
    const [statisticsDialog, setStatisticsDialog] = useState(false);
    
    // Статистика
    const [statistics, setStatistics] = useState(null);
    
    // Снэкбар
    const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'info' });

    // Загрузка диагностики при монтировании
    useEffect(() => {
        runDiagnostics();
    }, []);

    const showSnackbar = (message, severity = 'info') => {
        setSnackbar({ open: true, message, severity });
    };

    const runDiagnostics = async () => {
        setLoading(true);
        setError('');
        try {
            console.log('Запрос диагностики к:', `${API_URL}/telegramdiagnostics/full-check`);
            const response = await axios.get(`${API_URL}/telegramdiagnostics/full-check`);
            console.log('Ответ диагностики:', response);
            setDiagnostics(response.data);
            showSnackbar('✅ Диагностика завершена', 'success');
        } catch (err) {
            console.error('Ошибка диагностики:', err);
            console.error('Response data:', err.response?.data);
            console.error('Response status:', err.response?.status);
            console.error('Response headers:', err.response?.headers);
            
            let errorMsg;
            if (err.response?.status === 404) {
                errorMsg = 'Endpoint диагностики не найден (404). Проверьте, что сервер запущен';
            } else if (err.response?.status >= 500) {
                errorMsg = `Внутренняя ошибка сервера (${err.response.status})`;
            } else if (err.response?.data?.error) {
                errorMsg = err.response.data.error;
            } else if (err.message.includes('JSON')) {
                errorMsg = 'Сервер вернул некорректный JSON. Возможно, endpoint возвращает HTML вместо JSON';
            } else {
                errorMsg = err.message || 'Неизвестная ошибка диагностики';
            }
            
            setError(errorMsg);
            showSnackbar(`❌ ${errorMsg}`, 'error');
        } finally {
            setLoading(false);
        }
    };

    const setupWebhook = async () => {
        setWebhookLoading(true);
        setError('');
        try {
            console.log('Настройка webhook:', `${API_URL}/telegramdiagnostics/setup-webhook`, { baseUrl: webhookUrl });
            const response = await axios.post(`${API_URL}/telegramdiagnostics/setup-webhook`, {
                baseUrl: webhookUrl
            });
            console.log('Ответ настройки webhook:', response);
            
            if (response.data.success) {
                showSnackbar('✅ Webhook успешно настроен', 'success');
                setTimeout(runDiagnostics, 1000); // Обновляем диагностику
            } else {
                const errorMsg = response.data.error || 'Не удалось настроить webhook';
                showSnackbar(`❌ ${errorMsg}`, 'error');
                setError(errorMsg);
            }
        } catch (err) {
            console.error('Ошибка настройки webhook:', err);
            console.error('Response data:', err.response?.data);
            console.error('Response status:', err.response?.status);
            
            let errorMsg;
            if (err.response?.status === 404) {
                errorMsg = 'Endpoint настройки webhook не найден (404)';
            } else if (err.response?.status >= 500) {
                errorMsg = `Внутренняя ошибка сервера (${err.response.status})`;
            } else if (err.response?.data?.error) {
                errorMsg = err.response.data.error;
            } else if (err.message.includes('JSON')) {
                errorMsg = 'Сервер вернул некорректный JSON при настройке webhook';
            } else {
                errorMsg = err.message || 'Ошибка настройки webhook';
            }
            
            setError(errorMsg);
            showSnackbar(`❌ ${errorMsg}`, 'error');
        } finally {
            setWebhookLoading(false);
        }
    };

    const deleteWebhook = async () => {
        setWebhookLoading(true);
        setError('');
        try {
            const response = await axios.post(`${API_URL}/telegramdiagnostics/delete-webhook`);
            
            if (response.data.success) {
                showSnackbar('✅ Webhook удален', 'success');
                setTimeout(runDiagnostics, 1000);
            } else {
                showSnackbar('❌ Не удалось удалить webhook', 'error');
            }
        } catch (err) {
            const errorMsg = err.response?.data?.error || err.message || 'Ошибка удаления webhook';
            setError(errorMsg);
            showSnackbar(`❌ ${errorMsg}`, 'error');
        } finally {
            setWebhookLoading(false);
        }
    };

    const sendTestMessage = async () => {
        if (!testChatId || !testMessage) {
            showSnackbar('❌ Введите Chat ID и сообщение', 'warning');
            return;
        }

        setTestLoading(true);
        setError('');
        try {
            console.log('Отправка тестового сообщения:', { chatId: testChatId, message: testMessage });
            const response = await axios.post(`${API_URL}/telegramdiagnostics/test-send`, {
                chatId: testChatId,
                message: testMessage
            });
            console.log('Ответ отправки сообщения:', response);
            
            if (response.data.success) {
                showSnackbar('✅ Тестовое сообщение отправлено', 'success');
            } else {
                const errorMsg = response.data.error || 'Не удалось отправить сообщение';
                showSnackbar(`❌ ${errorMsg}`, 'error');
                setError(errorMsg);
            }
        } catch (err) {
            console.error('Ошибка отправки сообщения:', err);
            let errorMsg;
            if (err.response?.status === 404) {
                errorMsg = 'Endpoint отправки сообщения не найден (404)';
            } else if (err.response?.data?.error) {
                errorMsg = err.response.data.error;
            } else if (err.message.includes('JSON')) {
                errorMsg = 'Сервер вернул некорректный JSON при отправке сообщения';
            } else {
                errorMsg = err.message || 'Ошибка отправки сообщения';
            }
            setError(errorMsg);
            showSnackbar(`❌ ${errorMsg}`, 'error');
        } finally {
            setTestLoading(false);
        }
    };

    const loadStatistics = async () => {
        try {
            console.log('Загрузка статистики:', `${API_URL}/admin/telegram/statistics`);
            
            // Добавляем токен авторизации, если он есть
            const token = localStorage.getItem('token') || sessionStorage.getItem('token');
            const config = token ? {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            } : {};
            
            const response = await axios.get(`${API_URL}/admin/telegram/statistics`, config);
            console.log('Ответ статистики:', response);
            setStatistics(response.data);
            setStatisticsDialog(true);
        } catch (err) {
            console.error('Ошибка загрузки статистики:', err);
            let errorMsg;
            if (err.response?.status === 401) {
                errorMsg = 'Нет доступа для просмотра статистики. Войдите как администратор';
            } else if (err.response?.status === 404) {
                errorMsg = 'Endpoint статистики не найден (404)';
            } else if (err.response?.data?.error) {
                errorMsg = err.response.data.error;
            } else if (err.message.includes('JSON')) {
                errorMsg = 'Сервер вернул некорректный JSON при загрузке статистики';
            } else {
                errorMsg = err.message || 'Ошибка загрузки статистики';
            }
            showSnackbar(`❌ ${errorMsg}`, 'error');
        }
    };

    const testNotifications = async () => {
        if (notificationTestLimit < 1 || notificationTestLimit > 1000) {
            showSnackbar('❌ Количество лотов должно быть от 1 до 1000', 'warning');
            return;
        }

        setNotificationTestLoading(true);
        setNotificationTestResult(null);
        setError('');
        
        try {
            console.log('Тестирование уведомлений:', { 
                limitBooks: notificationTestLimit, 
                showBookIds: notificationShowBookIds 
            });
            
            const response = await axios.post(`${API_URL}/telegramdiagnostics/test-notifications`, {
                limitBooks: notificationTestLimit,
                showBookIds: notificationShowBookIds
            });
            
            console.log('Ответ тестирования уведомлений:', response);
            
            if (response.data.success) {
                setNotificationTestResult(response.data);
                showSnackbar('✅ Тестирование уведомлений завершено', 'success');
            } else {
                const errorMsg = response.data.error || 'Ошибка тестирования уведомлений';
                setError(errorMsg);
                showSnackbar(`❌ ${errorMsg}`, 'error');
            }
        } catch (err) {
            console.error('Ошибка тестирования уведомлений:', err);
            let errorMsg;
            if (err.response?.status === 404) {
                errorMsg = 'Endpoint тестирования уведомлений не найден (404)';
            } else if (err.response?.status >= 500) {
                errorMsg = `Внутренняя ошибка сервера (${err.response.status})`;
            } else if (err.response?.data?.error) {
                errorMsg = err.response.data.error;
            } else if (err.message.includes('JSON')) {
                errorMsg = 'Сервер вернул некорректный JSON при тестировании уведомлений';
            } else {
                errorMsg = err.message || 'Ошибка тестирования уведомлений';
            }
            
            setError(errorMsg);
            showSnackbar(`❌ ${errorMsg}`, 'error');
        } finally {
            setNotificationTestLoading(false);
        }
    };

    const getStatusIcon = (status) => {
        switch (status) {
            case 'success': return <CheckCircle color="success" />;
            case 'error': return <Error color="error" />;
            case 'warning': return <Warning color="warning" />;
            default: return <Warning color="action" />;
        }
    };

    const getStatusColor = (status) => {
        switch (status) {
            case 'success': return 'success';
            case 'error': return 'error';
            case 'warning': return 'warning';
            default: return 'default';
        }
    };

    return (
        <Box sx={{ p: 3 }}>
            <Typography variant="h4" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 4 }}>
                <Telegram color="primary" />
                Управление Telegram ботом
            </Typography>

            {error && (
                <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError('')}>
                    {error}
                </Alert>
            )}

            {/* Информационное сообщение для отладки */}
            <Alert severity="info" sx={{ mb: 3 }}>
                <Typography variant="body2">
                    🔧 <strong>Диагностическая информация:</strong><br/>
                    API URL: {API_URL}<br/>
                    Полный URL диагностики: {`${API_URL}/telegramdiagnostics/full-check`}<br/>
                    Откройте консоль браузера (F12) для просмотра подробных логов запросов.
                </Typography>
            </Alert>

            {/* Основная панель управления */}
            <Grid container spacing={3}>
                {/* Статус бота */}
                <Grid item xs={12} md={6}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                <Computer />
                                Состояние бота
                            </Typography>
                            
                            {diagnostics ? (
                                <Box>
                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                                        {getStatusIcon(diagnostics.checks.telegram_api?.status)}
                                        <Typography variant="body1">
                                            Telegram API: {diagnostics.checks.telegram_api?.status || 'неизвестно'}
                                        </Typography>
                                    </Box>
                                    
                                    {diagnostics.checks.telegram_api?.botInfo && (
                                        <Box sx={{ ml: 4, mb: 2 }}>
                                            <Typography variant="body2" color="text.secondary">
                                                Имя: {diagnostics.checks.telegram_api.botInfo.first_name}
                                            </Typography>
                                            <Typography variant="body2" color="text.secondary">
                                                Username: @{diagnostics.checks.telegram_api.botInfo.username}
                                            </Typography>
                                            <Typography variant="body2" color="text.secondary">
                                                ID: {diagnostics.checks.telegram_api.botInfo.id}
                                            </Typography>
                                        </Box>
                                    )}

                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                                        {getStatusIcon(diagnostics.checks.webhook?.status)}
                                        <Typography variant="body1">
                                            Webhook: {diagnostics.checks.webhook?.status || 'неизвестно'}
                                        </Typography>
                                    </Box>

                                    {diagnostics.checks.webhook?.webhookInfo && (
                                        <Box sx={{ ml: 4, mb: 2 }}>
                                            <Typography variant="body2" color="text.secondary">
                                                URL: {diagnostics.checks.webhook.webhookInfo.url || 'не установлен'}
                                            </Typography>
                                            <Typography variant="body2" color="text.secondary">
                                                Ожидающих обновлений: {diagnostics.checks.webhook.webhookInfo.pending_update_count || 0}
                                            </Typography>
                                        </Box>
                                    )}

                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                        <Chip 
                                            label={diagnostics.checks.config?.hasToken ? 'Токен настроен' : 'Токен не настроен'} 
                                            color={diagnostics.checks.config?.hasToken ? 'success' : 'error'}
                                            size="small"
                                        />
                                        {diagnostics.checks.config?.tokenMasked && (
                                            <Typography variant="caption" color="text.secondary">
                                                {diagnostics.checks.config.tokenMasked}
                                            </Typography>
                                        )}
                                    </Box>
                                </Box>
                            ) : (
                                <Typography color="text.secondary">Нет данных диагностики</Typography>
                            )}

                            <Box sx={{ mt: 2, display: 'flex', gap: 2 }}>
                                <Button
                                    variant="outlined"
                                    startIcon={loading ? <CircularProgress size={20} /> : <Refresh />}
                                    onClick={runDiagnostics}
                                    disabled={loading}
                                    size="small"
                                >
                                    Обновить
                                </Button>
                                <Button
                                    variant="outlined"
                                    startIcon={<BugReport />}
                                    onClick={() => setDiagnosticsDialog(true)}
                                    size="small"
                                >
                                    Детали
                                </Button>
                            </Box>
                        </CardContent>
                    </Card>
                </Grid>

                {/* Быстрые действия */}
                <Grid item xs={12} md={6}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                <Settings />
                                Быстрые действия
                            </Typography>
                            
                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                                <Button
                                    variant="contained"
                                    startIcon={<CloudUpload />}
                                    onClick={setupWebhook}
                                    disabled={webhookLoading}
                                    fullWidth
                                >
                                    {webhookLoading ? 'Настройка...' : 'Настроить Webhook'}
                                </Button>
                                
                                <Button
                                    variant="outlined"
                                    startIcon={<CloudDone />}
                                    onClick={deleteWebhook}
                                    disabled={webhookLoading}
                                    color="error"
                                    fullWidth
                                >
                                    Удалить Webhook
                                </Button>
                                
                                <Button
                                    variant="outlined"
                                    startIcon={<Assessment />}
                                    onClick={loadStatistics}
                                    fullWidth
                                >
                                    Статистика
                                </Button>
                                
                                <Button
                                    variant="outlined"
                                    startIcon={<NotificationsActive />}
                                    onClick={testNotifications}
                                    disabled={notificationTestLoading}
                                    fullWidth
                                >
                                    {notificationTestLoading ? 'Тестирование...' : 'Тест уведомлений'}
                                </Button>
                                
                                <Button
                                    variant="outlined"
                                    startIcon={<Launch />}
                                    href={`https://t.me/${diagnostics?.checks?.telegram_api?.botInfo?.username || 'RareBooksReminderBot'}`}
                                    target="_blank"
                                    fullWidth
                                >
                                    Открыть бота
                                </Button>
                            </Box>
                        </CardContent>
                    </Card>
                </Grid>

                {/* Настройка Webhook */}
                <Grid item xs={12}>
                    <Accordion>
                        <AccordionSummary expandIcon={<ExpandMore />}>
                            <Typography variant="h6" sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                <VpnKey />
                                Настройка Webhook
                            </Typography>
                        </AccordionSummary>
                        <AccordionDetails>
                            <Box sx={{ display: 'flex', gap: 2, alignItems: 'center' }}>
                                <TextField
                                    label="Base URL"
                                    value={webhookUrl}
                                    onChange={(e) => setWebhookUrl(e.target.value)}
                                    placeholder="https://rare-books.ru"
                                    fullWidth
                                    helperText="URL сервера без завершающего слеша"
                                />
                                <Button
                                    variant="contained"
                                    onClick={setupWebhook}
                                    disabled={webhookLoading}
                                    sx={{ minWidth: 120 }}
                                >
                                    {webhookLoading ? <CircularProgress size={20} /> : 'Установить'}
                                </Button>
                            </Box>
                        </AccordionDetails>
                    </Accordion>
                </Grid>

                {/* Тестирование */}
                <Grid item xs={12}>
                    <Accordion>
                        <AccordionSummary expandIcon={<ExpandMore />}>
                            <Typography variant="h6" sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                <Message />
                                Тестирование сообщений
                            </Typography>
                        </AccordionSummary>
                        <AccordionDetails>
                            <Grid container spacing={2}>
                                <Grid item xs={12} md={4}>
                                    <TextField
                                        label="Chat ID"
                                        value={testChatId}
                                        onChange={(e) => setTestChatId(e.target.value)}
                                        placeholder="123456789"
                                        fullWidth
                                        helperText="ID чата для тестирования"
                                    />
                                </Grid>
                                <Grid item xs={12} md={6}>
                                    <TextField
                                        label="Тестовое сообщение"
                                        value={testMessage}
                                        onChange={(e) => setTestMessage(e.target.value)}
                                        fullWidth
                                        multiline
                                        rows={2}
                                    />
                                </Grid>
                                <Grid item xs={12} md={2}>
                                    <Button
                                        variant="contained"
                                        onClick={sendTestMessage}
                                        disabled={testLoading}
                                        fullWidth
                                        sx={{ height: '100%' }}
                                        startIcon={testLoading ? <CircularProgress size={20} /> : <Send />}
                                    >
                                        Отправить
                                    </Button>
                                </Grid>
                            </Grid>
                            <Alert severity="info" sx={{ mt: 2 }}>
                                <Typography variant="body2">
                                    💡 Чтобы получить Chat ID: отправьте боту любое сообщение, затем откройте 
                                    <Button 
                                        size="small" 
                                        href={`https://api.telegram.org/bot${diagnostics?.checks?.config?.tokenMasked?.replace('***', '')}/getUpdates`}
                                        target="_blank"
                                        sx={{ mx: 1 }}
                                    >
                                        этот URL
                                    </Button>
                                    в браузере.
                                </Typography>
                            </Alert>
                        </AccordionDetails>
                    </Accordion>
                </Grid>

                {/* Тестирование уведомлений */}
                <Grid item xs={12}>
                    <Accordion>
                        <AccordionSummary expandIcon={<ExpandMore />}>
                            <Typography variant="h6" sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                <NotificationsActive />
                                Тестирование уведомлений о лотах
                            </Typography>
                        </AccordionSummary>
                        <AccordionDetails>
                            <Grid container spacing={2}>
                                <Grid item xs={12} md={4}>
                                    <TextField
                                        label="Количество лотов"
                                        type="number"
                                        value={notificationTestLimit}
                                        onChange={(e) => setNotificationTestLimit(parseInt(e.target.value) || 50)}
                                        inputProps={{ min: 1, max: 1000 }}
                                        fullWidth
                                        helperText="От 1 до 1000 активных лотов"
                                    />
                                </Grid>
                                <Grid item xs={12} md={4}>
                                    <FormControlLabel
                                        control={
                                            <Switch
                                                checked={notificationShowBookIds}
                                                onChange={(e) => setNotificationShowBookIds(e.target.checked)}
                                            />
                                        }
                                        label="Показать ID книг"
                                        sx={{ mt: 1 }}
                                    />
                                </Grid>
                                <Grid item xs={12} md={4}>
                                    <Button
                                        variant="contained"
                                        onClick={testNotifications}
                                        disabled={notificationTestLoading}
                                        fullWidth
                                        sx={{ height: '56px' }}
                                        startIcon={notificationTestLoading ? <CircularProgress size={20} /> : <NotificationsActive />}
                                    >
                                        {notificationTestLoading ? 'Выполняется тест...' : 'Запустить тест'}
                                    </Button>
                                </Grid>
                            </Grid>

                            {/* Результаты тестирования */}
                            {notificationTestResult && (
                                <Box sx={{ mt: 3 }}>
                                    <Alert severity="success" sx={{ mb: 2 }}>
                                        <Typography variant="body2">
                                            <strong>✅ Тестирование завершено!</strong><br/>
                                            {notificationTestResult.message}
                                        </Typography>
                                    </Alert>
                                    
                                    <Grid container spacing={2}>
                                        <Grid item xs={6} md={4}>
                                            <Paper sx={{ p: 2, textAlign: 'center', bgcolor: 'info.light', color: 'info.contrastText' }}>
                                                <Typography variant="h5">
                                                    {notificationTestResult.activeBooks}
                                                </Typography>
                                                <Typography variant="body2">
                                                    Активных лотов
                                                </Typography>
                                            </Paper>
                                        </Grid>
                                        <Grid item xs={6} md={4}>
                                            <Paper sx={{ p: 2, textAlign: 'center', bgcolor: 'warning.light', color: 'warning.contrastText' }}>
                                                <Typography variant="h5">
                                                    {notificationTestResult.activePreferences || 0}
                                                </Typography>
                                                <Typography variant="body2">
                                                    Настроек уведомлений
                                                </Typography>
                                            </Paper>
                                        </Grid>
                                        <Grid item xs={6} md={4}>
                                            <Paper sx={{ p: 2, textAlign: 'center', bgcolor: 'success.light', color: 'success.contrastText' }}>
                                                <Typography variant="h5">
                                                    {notificationTestResult.notificationsCreated}
                                                </Typography>
                                                <Typography variant="body2">
                                                    Уведомлений создано
                                                </Typography>
                                            </Paper>
                                        </Grid>
                                        {notificationTestResult.testBookIds && (
                                            <Grid item xs={12}>
                                                <Paper sx={{ p: 2, bgcolor: 'grey.100' }}>
                                                    <Typography variant="body2" color="text.secondary" gutterBottom>
                                                        <strong>Примеры ID книг:</strong>
                                                    </Typography>
                                                    <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                                                        {notificationTestResult.testBookIds.join(', ')}
                                                    </Typography>
                                                </Paper>
                                            </Grid>
                                        )}
                                    </Grid>
                                </Box>
                            )}

                            <Alert severity="warning" sx={{ mt: 2 }}>
                                <Typography variant="body2">
                                    ⚠️ <strong>ВНИМАНИЕ: Это реальный тест!</strong><br/>
                                    1. Находит указанное количество активных лотов (где EndDate > сейчас)<br/>
                                    2. Создает уведомления для всех пользователей с подходящими критериями<br/>
                                    3. <strong>НЕМЕДЛЕННО отправляет РЕАЛЬНЫЕ уведомления в Telegram</strong><br/>
                                    4. Пользователи получат настоящие сообщения о лотах<br/>
                                    5. Используйте осторожно на продакшене!
                                </Typography>
                            </Alert>
                        </AccordionDetails>
                    </Accordion>
                </Grid>
            </Grid>

            {/* Диалог с детальной диагностикой */}
            <Dialog 
                open={diagnosticsDialog} 
                onClose={() => setDiagnosticsDialog(false)}
                maxWidth="md"
                fullWidth
            >
                <DialogTitle>Детальная диагностика</DialogTitle>
                <DialogContent>
                    {diagnostics && (
                        <Box>
                            <Typography variant="body2" color="text.secondary" gutterBottom>
                                Последняя проверка: {new Date(diagnostics.timestamp).toLocaleString('ru-RU')}
                            </Typography>
                            
                            <pre style={{ 
                                background: '#f5f5f5', 
                                padding: '16px', 
                                borderRadius: '4px', 
                                overflow: 'auto',
                                fontSize: '12px'
                            }}>
                                {JSON.stringify(diagnostics, null, 2)}
                            </pre>
                        </Box>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setDiagnosticsDialog(false)}>Закрыть</Button>
                </DialogActions>
            </Dialog>

            {/* Диалог статистики */}
            <Dialog 
                open={statisticsDialog} 
                onClose={() => setStatisticsDialog(false)}
                maxWidth="sm"
                fullWidth
            >
                <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Assessment />
                    Статистика уведомлений
                </DialogTitle>
                <DialogContent>
                    {statistics ? (
                        <Grid container spacing={2}>
                            <Grid item xs={6}>
                                <Paper sx={{ p: 2, textAlign: 'center' }}>
                                    <Typography variant="h4" color="primary">
                                        {statistics.totalNotifications}
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        Всего уведомлений
                                    </Typography>
                                </Paper>
                            </Grid>
                            <Grid item xs={6}>
                                <Paper sx={{ p: 2, textAlign: 'center' }}>
                                    <Typography variant="h4" color="success.main">
                                        {statistics.successfulDeliveries}
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        Доставлено
                                    </Typography>
                                </Paper>
                            </Grid>
                            <Grid item xs={6}>
                                <Paper sx={{ p: 2, textAlign: 'center' }}>
                                    <Typography variant="h4" color="error.main">
                                        {statistics.failedDeliveries}
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        Ошибок
                                    </Typography>
                                </Paper>
                            </Grid>
                            <Grid item xs={6}>
                                <Paper sx={{ p: 2, textAlign: 'center' }}>
                                    <Typography variant="h4" color="info.main">
                                        {statistics.activeUsers}
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        Активных пользователей
                                    </Typography>
                                </Paper>
                            </Grid>
                        </Grid>
                    ) : (
                        <Typography>Загрузка статистики...</Typography>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setStatisticsDialog(false)}>Закрыть</Button>
                </DialogActions>
            </Dialog>

            {/* Снэкбар для уведомлений */}
            <Snackbar
                open={snackbar.open}
                autoHideDuration={6000}
                onClose={() => setSnackbar({ ...snackbar, open: false })}
                message={snackbar.message}
            />
        </Box>
    );
};

export default TelegramAdmin;
