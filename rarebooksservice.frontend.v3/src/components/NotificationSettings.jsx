import React, { useState, useEffect, useContext } from 'react';
import {
    Box,
    Paper,
    Typography,
    Button,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    Switch,
    FormControlLabel,
    Select,
    MenuItem,
    FormControl,
    InputLabel,
    Chip,
    Grid,
    Alert,
    Snackbar,
    CircularProgress,
    IconButton,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Tabs,
    Tab,
    Card,
    CardContent,
    CardActions,
    Divider,
    List,
    ListItem,
    ListItemIcon,
    ListItemText
} from '@mui/material';
import {
    Add as AddIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    Telegram as TelegramIcon,
    Notifications as NotificationsIcon,
    History as HistoryIcon,
    Send as SendIcon,
    Close as CloseIcon
} from '@mui/icons-material';
import { LanguageContext } from '../context/LanguageContext';
import translations from '../translations';
import {
    getNotificationPreferences,
    createNotificationPreference,
    updateNotificationPreference,
    deleteNotificationPreference,
    getNotificationHistory,
    getTelegramStatus,
    connectTelegram,
    disconnectTelegram,
    sendTestNotification
} from '../api';

const NotificationSettings = () => {
    const { language } = useContext(LanguageContext);
    const t = translations[language];

    const [preferences, setPreferences] = useState([]);
    const [history, setHistory] = useState([]);
    const [telegramStatus, setTelegramStatus] = useState(null);
    const [loading, setLoading] = useState(true);
    const [currentTab, setCurrentTab] = useState(0);
    const [openDialog, setOpenDialog] = useState(false);
    const [openTelegramDialog, setOpenTelegramDialog] = useState(false);
    const [editingPreference, setEditingPreference] = useState(null);
    const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

    // Форма настройки уведомлений
    const [formData, setFormData] = useState({
        isEnabled: true,
        keywords: '',
        categoryIds: '',
        minPrice: 0,
        maxPrice: 0,
        minYear: 0,
        maxYear: 0,
        cities: '',
        notificationFrequencyMinutes: 60,
        deliveryMethod: 1 // 1 = Email, 4 = Telegram
    });

    // Форма подключения Telegram
    const [telegramForm, setTelegramForm] = useState({
        telegramId: '',
        telegramUsername: '',
        token: '',
        expiresAt: null,
        instructions: [],
        step: 'initial' // 'initial', 'token-generated', 'completed'
    });

    useEffect(() => {
        loadData();
    }, []);

    const loadData = async () => {
        setLoading(true);
        try {
            const [preferencesRes, historyRes, telegramRes] = await Promise.allSettled([
                getNotificationPreferences(),
                getNotificationHistory(1, 20),
                getTelegramStatus()
            ]);

            if (preferencesRes.status === 'fulfilled') {
                setPreferences(preferencesRes.value.data);
            }

            if (historyRes.status === 'fulfilled') {
                setHistory(historyRes.value.data.items || []);
            }

            if (telegramRes.status === 'fulfilled') {
                setTelegramStatus(telegramRes.value.data);
            }
        } catch (error) {
            console.error('Error loading data:', error);
            showSnackbar(t.error, 'error');
        } finally {
            setLoading(false);
        }
    };

    const showSnackbar = (message, severity = 'success') => {
        setSnackbar({ open: true, message, severity });
    };

    const handleCloseSnackbar = () => {
        setSnackbar({ ...snackbar, open: false });
    };

    const handleTabChange = (event, newValue) => {
        setCurrentTab(newValue);
    };

    const handleOpenDialog = (preference = null) => {
        if (preference) {
            setEditingPreference(preference);
            setFormData({
                isEnabled: preference.isEnabled,
                keywords: preference.keywords || '',
                categoryIds: preference.categoryIds || '',
                minPrice: preference.minPrice || 0,
                maxPrice: preference.maxPrice || 0,
                minYear: preference.minYear || 0,
                maxYear: preference.maxYear || 0,
                cities: preference.cities || '',
                notificationFrequencyMinutes: preference.notificationFrequencyMinutes || 60,
                deliveryMethod: preference.deliveryMethod
            });
        } else {
            setEditingPreference(null);
            setFormData({
                isEnabled: true,
                keywords: '',
                categoryIds: '',
                minPrice: 0,
                maxPrice: 0,
                minYear: 0,
                maxYear: 0,
                cities: '',
                notificationFrequencyMinutes: 60,
                deliveryMethod: telegramStatus?.isConnected ? 4 : 1
            });
        }
        setOpenDialog(true);
    };

    const handleCloseDialog = () => {
        setOpenDialog(false);
        setEditingPreference(null);
    };

    const handleSubmit = async () => {
        try {
            if (editingPreference) {
                await updateNotificationPreference(editingPreference.id, formData);
                showSnackbar(t.notificationUpdated);
            } else {
                await createNotificationPreference(formData);
                showSnackbar(t.notificationCreated);
            }
            handleCloseDialog();
            loadData();
        } catch (error) {
            console.error('Error saving preference:', error);
            showSnackbar(error.response?.data?.message || t.error, 'error');
        }
    };

    const handleDelete = async (id) => {
        if (!window.confirm(t.confirm)) return;

        try {
            await deleteNotificationPreference(id);
            showSnackbar(t.notificationDeleted);
            loadData();
        } catch (error) {
            console.error('Error deleting preference:', error);
            showSnackbar(t.error, 'error');
        }
    };

    const handleConnectTelegram = async () => {
        try {
            const response = await fetch('/api/notification/telegram/generate-link-token', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${localStorage.getItem('jwt')}`,
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.message || 'Ошибка при генерации токена');
            }

            const data = await response.json();
            setTelegramForm({
                ...telegramForm,
                token: data.token,
                expiresAt: data.expiresAt,
                instructions: data.instructions,
                step: 'token-generated'
            });
        } catch (error) {
            console.error('Error generating link token:', error);
            showSnackbar(error.message || t.error, 'error');
        }
    };

    const handleDisconnectTelegram = async () => {
        if (!window.confirm(t.confirm)) return;

        try {
            await disconnectTelegram();
            showSnackbar(t.telegramDisconnectedSuccess);
            loadData();
        } catch (error) {
            console.error('Error disconnecting Telegram:', error);
            showSnackbar(t.error, 'error');
        }
    };

    const handleSendTest = async (deliveryMethod) => {
        try {
            await sendTestNotification(deliveryMethod);
            showSnackbar(t.testNotificationSent);
        } catch (error) {
            console.error('Error sending test notification:', error);
            showSnackbar(error.response?.data?.message || t.error, 'error');
        }
    };

    const getStatusChip = (status) => {
        const statusMap = {
            0: { label: t.pending, color: 'default' },
            1: { label: t.sending, color: 'info' },
            2: { label: t.sent, color: 'success' },
            3: { label: t.delivered, color: 'success' },
            4: { label: t.read, color: 'success' },
            5: { label: t.failed, color: 'error' },
            6: { label: t.cancelled, color: 'default' }
        };

        const statusInfo = statusMap[status] || { label: status, color: 'default' };
        return <Chip label={statusInfo.label} color={statusInfo.color} size="small" />;
    };

    const getDeliveryMethodText = (method) => {
        return method === 4 ? t.telegram : t.email;
    };

    if (loading) {
        return (
            <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
                <CircularProgress />
            </Box>
        );
    }

    return (
        <Box sx={{ maxWidth: 1200, mx: 'auto', p: 3 }}>
            <Typography variant="h4" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                <NotificationsIcon />
                {t.notifications}
            </Typography>

            <Paper sx={{ width: '100%' }}>
                <Tabs value={currentTab} onChange={handleTabChange} aria-label="notification tabs">
                    <Tab label={t.notificationSettings} />
                    <Tab label={t.telegramBot} />
                    <Tab label={t.notificationHistory} />
                </Tabs>

                {/* Настройки уведомлений */}
                {currentTab === 0 && (
                    <Box sx={{ p: 3 }}>
                        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                            <Typography variant="h6">{t.notificationSettings}</Typography>
                            <Button
                                variant="contained"
                                startIcon={<AddIcon />}
                                onClick={() => handleOpenDialog()}
                            >
                                {t.createNotification}
                            </Button>
                        </Box>

                        {preferences.length === 0 ? (
                            <Alert severity="info">
                                {t.noNotifications}
                                <br />
                                {t.createFirstNotification}
                            </Alert>
                        ) : (
                            <Grid container spacing={2}>
                                {preferences.map((preference) => (
                                    <Grid item xs={12} md={6} key={preference.id}>
                                        <Card>
                                            <CardContent>
                                                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2 }}>
                                                    <Typography variant="h6">
                                                        {preference.keywords ? preference.keywords.slice(0, 50) : t.notifications}
                                                        {preference.keywords && preference.keywords.length > 50 && '...'}
                                                    </Typography>
                                                    <Chip
                                                        label={preference.isEnabled ? t.enabled : t.disabled}
                                                        color={preference.isEnabled ? 'success' : 'default'}
                                                        size="small"
                                                    />
                                                </Box>

                                                <Typography variant="body2" color="text.secondary" gutterBottom>
                                                    {t.deliveryMethod}: {getDeliveryMethodText(preference.deliveryMethod)}
                                                </Typography>

                                                <Typography variant="body2" color="text.secondary" gutterBottom>
                                                    {t.frequency}: {preference.notificationFrequencyMinutes} {t.frequencyMinutes}
                                                </Typography>

                                                {preference.minPrice > 0 || preference.maxPrice > 0 ? (
                                                    <Typography variant="body2" color="text.secondary" gutterBottom>
                                                        {t.priceRange}: {preference.minPrice}₽ - {preference.maxPrice}₽
                                                    </Typography>
                                                ) : null}

                                                {preference.lastNotificationSent && (
                                                    <Typography variant="body2" color="text.secondary">
                                                        {t.lastNotificationSent}: {new Date(preference.lastNotificationSent).toLocaleString()}
                                                    </Typography>
                                                )}
                                            </CardContent>
                                            <CardActions>
                                                <IconButton
                                                    size="small"
                                                    onClick={() => handleOpenDialog(preference)}
                                                    title={t.editNotification}
                                                >
                                                    <EditIcon />
                                                </IconButton>
                                                <IconButton
                                                    size="small"
                                                    onClick={() => handleDelete(preference.id)}
                                                    title={t.deleteNotification}
                                                    color="error"
                                                >
                                                    <DeleteIcon />
                                                </IconButton>
                                            </CardActions>
                                        </Card>
                                    </Grid>
                                ))}
                            </Grid>
                        )}
                    </Box>
                )}

                {/* Telegram бот */}
                {currentTab === 1 && (
                    <Box sx={{ p: 3 }}>
                        <Typography variant="h6" gutterBottom>
                            <TelegramIcon sx={{ verticalAlign: 'middle', mr: 1 }} />
                            {t.telegramBot}
                        </Typography>

                        {telegramStatus && (
                            <Card sx={{ mb: 3 }}>
                                <CardContent>
                                    <Grid container spacing={2}>
                                        <Grid item xs={12} sm={6}>
                                            <Typography variant="body1" gutterBottom>
                                                {t.status}: {' '}
                                                <Chip
                                                    label={telegramStatus.isConnected ? t.telegramConnected : t.telegramNotConnected}
                                                    color={telegramStatus.isConnected ? 'success' : 'default'}
                                                    size="small"
                                                />
                                            </Typography>

                                            {telegramStatus.isConnected && (
                                                <>
                                                    <Typography variant="body2" color="text.secondary">
                                                        {t.telegramId}: {telegramStatus.telegramId}
                                                    </Typography>
                                                    {telegramStatus.telegramUsername && (
                                                        <Typography variant="body2" color="text.secondary">
                                                            {t.telegramUsername}: @{telegramStatus.telegramUsername}
                                                        </Typography>
                                                    )}
                                                </>
                                            )}

                                            <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                                                {t.botUsername}: @{telegramStatus.botUsername}
                                            </Typography>
                                        </Grid>
                                        <Grid item xs={12} sm={6} sx={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end' }}>
                                            {telegramStatus.isConnected ? (
                                                <Box sx={{ display: 'flex', gap: 1 }}>
                                                    <Button
                                                        variant="outlined"
                                                        size="small"
                                                        startIcon={<SendIcon />}
                                                        onClick={() => handleSendTest(4)}
                                                    >
                                                        {t.sendTest}
                                                    </Button>
                                                    <Button
                                                        variant="outlined"
                                                        color="error"
                                                        size="small"
                                                        onClick={handleDisconnectTelegram}
                                                    >
                                                        {t.disconnectTelegram}
                                                    </Button>
                                                </Box>
                                            ) : (
                                                <Button
                                                    variant="contained"
                                                    startIcon={<TelegramIcon />}
                                                    onClick={() => setOpenTelegramDialog(true)}
                                                >
                                                    {t.connectTelegram}
                                                </Button>
                                            )}
                                        </Grid>
                                    </Grid>
                                </CardContent>
                            </Card>
                        )}

                        <Card>
                            <CardContent>
                                <Typography variant="h6" gutterBottom>
                                    {t.telegramConnectionInstructions}
                                </Typography>
                                <Box sx={{ mt: 2 }}>
                                    <Typography variant="body1" sx={{ mb: 1 }}>
                                        <strong>{t.step1}:</strong> {t.findBot}
                                    </Typography>
                                    <Typography variant="body1" sx={{ mb: 1 }}>
                                        <strong>{t.step2}:</strong> {t.startBot}
                                    </Typography>
                                    <Typography variant="body1" sx={{ mb: 1 }}>
                                        <strong>{t.step3}:</strong> {t.getIdFromBot}
                                    </Typography>
                                    <Typography variant="body1">
                                        {t.enterIdHere}
                                    </Typography>
                                </Box>
                            </CardContent>
                        </Card>
                    </Box>
                )}

                {/* История уведомлений */}
                {currentTab === 2 && (
                    <Box sx={{ p: 3 }}>
                        <Typography variant="h6" gutterBottom>
                            <HistoryIcon sx={{ verticalAlign: 'middle', mr: 1 }} />
                            {t.notificationHistory}
                        </Typography>

                        {history.length === 0 ? (
                            <Alert severity="info">{t.noNotificationHistory}</Alert>
                        ) : (
                            <TableContainer>
                                <Table>
                                    <TableHead>
                                        <TableRow>
                                            <TableCell>{t.createdAt}</TableCell>
                                            <TableCell>{t.bookTitle}</TableCell>
                                            <TableCell>{t.bookPrice}</TableCell>
                                            <TableCell>{t.deliveryMethod}</TableCell>
                                            <TableCell>{t.status}</TableCell>
                                            <TableCell>{t.matchedKeywords}</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {history.map((item) => (
                                            <TableRow key={item.id}>
                                                <TableCell>
                                                    {new Date(item.createdAt).toLocaleDateString()}
                                                </TableCell>
                                                <TableCell>
                                                    {item.bookTitle?.slice(0, 50)}
                                                    {item.bookTitle && item.bookTitle.length > 50 && '...'}
                                                </TableCell>
                                                <TableCell>{item.bookPrice}₽</TableCell>
                                                <TableCell>{getDeliveryMethodText(item.deliveryMethod)}</TableCell>
                                                <TableCell>{getStatusChip(item.status)}</TableCell>
                                                <TableCell>
                                                    {item.matchedKeywords ? (
                                                        <Chip label={item.matchedKeywords} size="small" />
                                                    ) : '-'}
                                                </TableCell>
                                            </TableRow>
                                        ))}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        )}
                    </Box>
                )}
            </Paper>

            {/* Диалог создания/редактирования настроек */}
            <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="md" fullWidth>
                <DialogTitle>
                    {editingPreference ? t.editNotification : t.createNotification}
                </DialogTitle>
                <DialogContent>
                    <Grid container spacing={2} sx={{ mt: 1 }}>
                        <Grid item xs={12}>
                            <FormControlLabel
                                control={
                                    <Switch
                                        checked={formData.isEnabled}
                                        onChange={(e) => setFormData({ ...formData, isEnabled: e.target.checked })}
                                    />
                                }
                                label={t.enabled}
                            />
                        </Grid>

                        <Grid item xs={12}>
                            <TextField
                                fullWidth
                                label={t.keywords}
                                value={formData.keywords}
                                onChange={(e) => setFormData({ ...formData, keywords: e.target.value })}
                                helperText={t.keywordsHint}
                                multiline
                                rows={2}
                            />
                        </Grid>

                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                label={t.categories}
                                value={formData.categoryIds}
                                onChange={(e) => setFormData({ ...formData, categoryIds: e.target.value })}
                                helperText={t.categoriesHint}
                            />
                        </Grid>

                        <Grid item xs={12} sm={6}>
                            <TextField
                                fullWidth
                                label={t.cities}
                                value={formData.cities}
                                onChange={(e) => setFormData({ ...formData, cities: e.target.value })}
                                helperText={t.citiesHint}
                            />
                        </Grid>

                        <Grid item xs={6}>
                            <TextField
                                fullWidth
                                label={t.minPrice}
                                type="number"
                                value={formData.minPrice}
                                onChange={(e) => setFormData({ ...formData, minPrice: Number(e.target.value) })}
                            />
                        </Grid>

                        <Grid item xs={6}>
                            <TextField
                                fullWidth
                                label={t.maxPrice}
                                type="number"
                                value={formData.maxPrice}
                                onChange={(e) => setFormData({ ...formData, maxPrice: Number(e.target.value) })}
                            />
                        </Grid>

                        <Grid item xs={6}>
                            <TextField
                                fullWidth
                                label={t.minYear}
                                type="number"
                                value={formData.minYear}
                                onChange={(e) => setFormData({ ...formData, minYear: Number(e.target.value) })}
                            />
                        </Grid>

                        <Grid item xs={6}>
                            <TextField
                                fullWidth
                                label={t.maxYear}
                                type="number"
                                value={formData.maxYear}
                                onChange={(e) => setFormData({ ...formData, maxYear: Number(e.target.value) })}
                            />
                        </Grid>

                        <Grid item xs={6}>
                            <TextField
                                fullWidth
                                label={t.frequency}
                                type="number"
                                value={formData.notificationFrequencyMinutes}
                                onChange={(e) => setFormData({ ...formData, notificationFrequencyMinutes: Number(e.target.value) })}
                                InputProps={{
                                    endAdornment: <Typography variant="body2">{t.frequencyMinutes}</Typography>
                                }}
                            />
                        </Grid>

                        <Grid item xs={6}>
                            <FormControl fullWidth>
                                <InputLabel>{t.deliveryMethod}</InputLabel>
                                <Select
                                    value={formData.deliveryMethod}
                                    label={t.deliveryMethod}
                                    onChange={(e) => setFormData({ ...formData, deliveryMethod: e.target.value })}
                                >
                                    <MenuItem value={1}>{t.email}</MenuItem>
                                    <MenuItem value={4} disabled={!telegramStatus?.isConnected}>
                                        {t.telegram} {!telegramStatus?.isConnected && `(${t.telegramNotConnected})`}
                                    </MenuItem>
                                </Select>
                            </FormControl>
                        </Grid>
                    </Grid>
                </DialogContent>
                <DialogActions>
                    <Button onClick={handleCloseDialog}>{t.cancel}</Button>
                    <Button onClick={handleSubmit} variant="contained">{t.save}</Button>
                </DialogActions>
            </Dialog>

            {/* Диалог подключения Telegram */}
            <Dialog open={openTelegramDialog} onClose={() => setOpenTelegramDialog(false)} maxWidth="md" fullWidth>
                <DialogTitle>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <TelegramIcon />
                        {t.connectTelegram}
                    </Box>
                </DialogTitle>
                <DialogContent>
                    {telegramForm.step === 'initial' && (
                        <>
                            <Alert severity="info" sx={{ mb: 2 }}>
                                Мы создадим одноразовый токен для безопасной привязки вашего Telegram аккаунта
                            </Alert>
                            <Typography variant="body2" sx={{ mb: 2 }}>
                                Нажмите кнопку ниже для генерации токена привязки
                            </Typography>
                        </>
                    )}

                    {telegramForm.step === 'token-generated' && (
                        <>
                            <Alert severity="success" sx={{ mb: 2 }}>
                                Токен создан! Следуйте инструкциям ниже:
                            </Alert>
                            
                            <Card sx={{ mb: 2, p: 2, bgcolor: 'grey.50' }}>
                                <Typography variant="h6" gutterBottom>
                                    Ваш токен:
                                </Typography>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                                    <TextField
                                        fullWidth
                                        value={telegramForm.token}
                                        InputProps={{
                                            readOnly: true,
                                            style: { fontFamily: 'monospace', fontSize: '1.2em', fontWeight: 'bold' }
                                        }}
                                    />
                                    <Button
                                        variant="outlined"
                                        onClick={() => {
                                            navigator.clipboard.writeText(telegramForm.token);
                                            showSnackbar('Токен скопирован!');
                                        }}
                                    >
                                        Копировать
                                    </Button>
                                </Box>
                                <Typography variant="body2" color="text.secondary">
                                    Действителен до: {new Date(telegramForm.expiresAt).toLocaleString()}
                                </Typography>
                            </Card>

                            <Typography variant="h6" gutterBottom>
                                Инструкции:
                            </Typography>
                            <List>
                                {telegramForm.instructions.map((instruction, index) => (
                                    <ListItem key={index}>
                                        <ListItemIcon>
                                            <Chip label={index + 1} size="small" color="primary" />
                                        </ListItemIcon>
                                        <ListItemText primary={instruction} />
                                    </ListItem>
                                ))}
                            </List>

                            <Alert severity="warning" sx={{ mt: 2 }}>
                                После успешной привязки в боте обновите эту страницу для отображения нового статуса
                            </Alert>
                        </>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => {
                        setOpenTelegramDialog(false);
                        setTelegramForm({
                            telegramId: '',
                            telegramUsername: '',
                            token: '',
                            expiresAt: null,
                            instructions: [],
                            step: 'initial'
                        });
                    }}>
                        {telegramForm.step === 'token-generated' ? 'Закрыть' : t.cancel}
                    </Button>
                    {telegramForm.step === 'initial' && (
                        <Button onClick={handleConnectTelegram} variant="contained">
                            Создать токен
                        </Button>
                    )}
                    {telegramForm.step === 'token-generated' && (
                        <Button 
                            onClick={() => window.location.reload()} 
                            variant="contained"
                            color="primary"
                        >
                            Обновить страницу
                        </Button>
                    )}
                </DialogActions>
            </Dialog>

            {/* Snackbar для уведомлений */}
            <Snackbar
                open={snackbar.open}
                autoHideDuration={6000}
                onClose={handleCloseSnackbar}
                action={
                    <IconButton size="small" aria-label="close" color="inherit" onClick={handleCloseSnackbar}>
                        <CloseIcon fontSize="small" />
                    </IconButton>
                }
            >
                <Alert onClose={handleCloseSnackbar} severity={snackbar.severity}>
                    {snackbar.message}
                </Alert>
            </Snackbar>
        </Box>
    );
};

export default NotificationSettings;
