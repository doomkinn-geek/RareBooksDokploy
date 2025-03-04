// src/components/AdminPanel.jsx
import React, { useEffect, useState } from 'react';
import {
    getUsers, updateUserSubscription, updateUserRole, getUserById,
    getAdminSettings, updateAdminSettings,
    initImport, uploadImportChunk, finishImport, getImportProgress, cancelImport
} from '../api';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { API_URL } from '../api';
import Cookies from 'js-cookie';
import {
    Box, Container, Typography, Tabs, Tab, Paper, Button, 
    TextField, CircularProgress, Table, TableBody, TableCell, 
    TableContainer, TableHead, TableRow, Alert, Grid, Switch,
    Card, CardContent, LinearProgress, MenuItem, Select, 
    FormControl, FormControlLabel, InputLabel, Checkbox, Dialog,
    DialogTitle, DialogContent, DialogActions, Divider,
    useMediaQuery, useTheme
} from '@mui/material';
import { CategoryCleanup, SubPlans, BookUpdate, Import, Export } from './admin';

const AdminPanel = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const isTablet = useMediaQuery(theme.breakpoints.down('md'));
    
    // Вкладки: 'users' | 'export' | 'settings' | 'import' | 'bookupdate' | 'subplans' | 'categories'
    const [currentTab, setCurrentTab] = useState('users');

    // ----- Состояния пользователей
    const [users, setUsers] = useState([]);
    const [error, setError] = useState('');

    // Состояния для экспорта
    const [exportTaskId, setExportTaskId] = useState(null);
    const [progress, setProgress] = useState(null);        // число (0..100 или -1)
    const [exportError, setExportError] = useState(null);  // текст ошибки с сервера, если есть
    const [exportInternalError, setExportInternalError] = useState(null);  
    const [isExporting, setIsExporting] = useState(false);
    const [intervalId, setIntervalId] = useState(null);

    // ----- Настройки
    const [yandexKassa, setYandexKassa] = useState({
        shopId: '',
        secretKey: '',
        returnUrl: '',
        webhookUrl: ''
    });
    const [yandexDisk, setYandexDisk] = useState({ token: '' });
    const [typeOfAccessImages, setTypeOfAccessImages] = useState({
        useLocalFiles: 'false',
        localPathOfImages: ''
    });
    const [yandexCloud, setYandexCloud] = useState({
        accessKey: '',
        secretKey: '',
        serviceUrl: '',
        bucketName: ''
    });
    const [smtp, setSmtp] = useState({
        host: '',
        port: '',
        user: '',
        pass: ''
    });

    const [cacheSettings, setCacheSettings] = useState({
        localCachePath: '',
        daysToKeep: 30,
        maxCacheSizeMB: 200
    });

    // ----- Сервис обновления книг
    const [bookUpdateStatus, setBookUpdateStatus] = useState({
        isPaused: false,
        isRunningNow: false,
        lastRunTimeUtc: null,
        nextRunTimeUtc: null,
        currentOperationName: null,
        processedCount: 0,
        lastProcessedLotId: 0,
        lastProcessedLotTitle: '',
        logs: []  // <-- можно добавить сюда дефолтное пустое поле
    });


    // ----- Импорт
    const [importTaskId, setImportTaskId] = useState(null);
    const [importFile, setImportFile] = useState(null);
    const [importUploadProgress, setImportUploadProgress] = useState(0);
    const [importProgress, setImportProgress] = useState(0);
    const [importMessage, setImportMessage] = useState('');
    const [isImporting, setIsImporting] = useState(false);
    const [importPollIntervalId, setImportPollIntervalId] = useState(null);

    // ===== Новая вкладка: планы подписки =====
    const [subPlans, setSubPlans] = useState([]);
    const [loadingPlans, setLoadingPlans] = useState(false);

    // Форма для нового или редактируемого плана
    const [editMode, setEditMode] = useState(false); // false => создаём, true => редактируем
    const [planForm, setPlanForm] = useState({
        id: 0,
        name: '',
        price: 0,
        monthlyRequestLimit: 0,
        isActive: true
    });

    // --- Модалка для назначения плана ---
    const [showSubModal, setShowSubModal] = useState(false);
    const [selectedUserForSub, setSelectedUserForSub] = useState(null);
    const [selectedPlanForSub, setSelectedPlanForSub] = useState(0);
    const [autoRenewForSub, setAutoRenewForSub] = useState(false);


    const navigate = useNavigate();

    useEffect(() => {
        loadSubscriptionPlans(); // Загрузим планы при первом рендере
    }, []);
    // ====================== Загрузка пользователей ======================
    // Вынесем эту функцию наружу
    const loadUsers = async () => {
        try {
            const response = await getUsers();
            setUsers(response.data);
        } catch (err) {
            console.error('Error fetching users:', err);
            setError('Ошибка при загрузке пользователей');
        }
    };
    useEffect(() => {
        loadUsers();
    }, []);

    // ====================== Загрузка настроек ======================
    useEffect(() => {
        const fetchSettings = async () => {
            try {
                const data = await getAdminSettings();
                setYandexKassa({
                    shopId: data.yandexKassa?.ShopId ?? '',
                    secretKey: data.yandexKassa?.SecretKey ?? '',
                    returnUrl: data.yandexKassa?.ReturnUrl ?? '',
                    webhookUrl: data.yandexKassa?.WebhookUrl ?? ''
                });
                setYandexDisk({
                    token: data.yandexDisk?.Token ?? ''
                });
                setTypeOfAccessImages({
                    useLocalFiles: data.typeOfAccessImages?.UseLocalFiles ?? 'false',
                    localPathOfImages: data.typeOfAccessImages?.LocalPathOfImages ?? ''
                });
                setYandexCloud({
                    accessKey: data.yandexCloud?.AccessKey ?? '',
                    secretKey: data.yandexCloud?.SecretKey ?? '',
                    serviceUrl: data.yandexCloud?.ServiceUrl ?? '',
                    bucketName: data.yandexCloud?.BucketName ?? ''
                });
                setSmtp({
                    host: data.smtp?.Host ?? '',
                    port: data.smtp?.Port ?? '587',
                    user: data.smtp?.User ?? '',
                    pass: data.smtp?.Pass ?? ''
                });
                setCacheSettings({
                    localCachePath: data.cacheSettings?.LocalCachePath || 'image_cache',
                    daysToKeep: data.cacheSettings?.DaysToKeep || 30,
                    maxCacheSizeMB: data.cacheSettings?.MaxCacheSizeMB || 200
                });
            } catch (err) {
                console.error('Error fetching admin settings:', err);
                setError('Ошибка при загрузке настроек');
            }
        };
        fetchSettings();
    }, []);

    // ====================== Загрузка планов подписки (при переходе на вкладку subplans) ======================
    useEffect(() => {
        if (currentTab === 'subplans') {
            loadSubscriptionPlans();
        }
        // eslint-disable-next-line
    }, [currentTab]);

    const loadSubscriptionPlans = async () => {
        setLoadingPlans(true);
        setError('');
        try {
            const token = Cookies.get('token');
            // Допустим, у нас есть контроллер /api/subscriptionplans
            const response = await axios.get(`${API_URL}/SubscriptionPlans`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setSubPlans(response.data);
        } catch (err) {
            console.error('Error fetching subscription plans:', err);
            setError('Не удалось загрузить планы подписки.');
        } finally {
            setLoadingPlans(false);
        }
    };

    // Открываем модалку
    function openSubscriptionModal(user) {
        setSelectedUserForSub(user);
        const activePlanId = user.currentSubscription?.subscriptionPlanId || 0;
        setSelectedPlanForSub(activePlanId);
        setAutoRenewForSub(user.currentSubscription?.autoRenew || false);
        setShowSubModal(true);
    }

    async function handleAssignSubscriptionPlan() {
        try {
            const token = Cookies.get('token');
            const userId = selectedUserForSub.id;

            const requestBody = {
                planId: Number(selectedPlanForSub),
                autoRenew: autoRenewForSub
            };

            await axios.post(`${API_URL}/admin/user/${userId}/assign-subscription-plan`,
                requestBody,
                { headers: { Authorization: `Bearer ${token}` }
            });

            alert('Подписка обновлена');
            setShowSubModal(false);

            // Обновим список пользователей, чтобы увидеть новые данные
            loadUsers();
        } catch (err) {
            console.error('Ошибка при назначении плана подписки:', err);
            alert('Ошибка при назначении плана');
        }
    }

    // ====================== Методы работы с пользователями ======================
    const handleUpdateUserSubscription = async (userId, hasSubscription) => {
        if (isExporting || isImporting) return;
        try {
            await updateUserSubscription(userId, hasSubscription);
            setUsers((prev) =>
                prev.map((user) =>
                    user.id === userId ? { ...user, hasSubscription } : user
                )
            );
        } catch (err) {
            console.error('Error updating subscription:', err);
            setError('Ошибка при обновлении подписки');
        }
    };

    const handleUpdateUserRole = async (userId, role) => {
        if (isExporting || isImporting) return;
        try {
            await updateUserRole(userId, role);
            setUsers((prev) =>
                prev.map((user) => (user.id === userId ? { ...user, role } : user))
            );
        } catch (err) {
            console.error('Error updating role:', err);
            setError('Ошибка при обновлении роли');
        }
    };

    const handleViewDetails = async (userId) => {
        if (isExporting || isImporting) return;
        try {
            await getUserById(userId);
            navigate(`/user/${userId}`);
        } catch (err) {
            console.error('Error fetching user details:', err);
        }
    };

    // ====================== Экспорт ======================
    // ==========================================
    // ========== Логика старта экспорта ========
    // ==========================================
    const startExport = async () => {
        // Если уже что-то идёт — не делаем повторный экспорт
        if (isExporting || isImporting) return;

        try {
            // Сбрасываем возможные старые значения
            setError('');
            setExportError(null);
            setExportInternalError(null);
            setProgress(null);
            setIsExporting(true);

            const token = Cookies.get('token');
            const response = await axios.post(
                `${API_URL}/admin/export-data`,
                {},
                { headers: { Authorization: `Bearer ${token}` } }
            );
            const taskIdFromServer = response.data.taskId;
            setExportTaskId(taskIdFromServer);

            // Ставим прогресс 0 (чтобы пользователь видел, что началось)
            setProgress(0);

            // Запускаем интервал опроса
            const id = setInterval(async () => {
                try {
                    const progressRes = await axios.get(
                        `${API_URL}/admin/export-progress/${taskIdFromServer}`,
                        { headers: { Authorization: `Bearer ${token}` } }
                    );
                    // Сервер возвращает объект вида:
                    // { progress: number, isError: bool, errorDetails: string }
                    const { progress, isError, errorDetails } = progressRes.data;

                    // Обновляем локальное состояние прогресса
                    setProgress(progress);

                    if (isError && progress === -1) {
                        // Сервер сообщил об ошибке => выходим из режима экспорта
                        setExportError(errorDetails || 'Неизвестная ошибка при экспорте');
                        setExportInternalError(errorDetails);
                        setIsExporting(false);

                        // Останавливаем таймер опроса
                        clearInterval(id);
                        setIntervalId(null);
                    }
                    else if (progress >= 100) {
                        // Экспорт завершён
                        setIsExporting(false);
                        clearInterval(id);
                        setIntervalId(null);
                    }
                    // Иначе (прогресс < 100, isError=false) — продолжаем опрашивать
                } catch (e) {
                    // Сюда попадаем при сетевой ошибке, 5xx, 4xx и т.д.
                    console.error(e);
                    setError('Ошибка при получении прогресса экспорта (сетевая или серверная).');
                    setIsExporting(false);

                    // Не забываем остановить таймер
                    clearInterval(id);
                    setIntervalId(null);
                }
            }, 1000); // например, раз в секунду

            setIntervalId(id);
        } catch (err) {
            console.error(err);
            setError('Ошибка при запуске экспорта.');
            setIsExporting(false);
        }
    };


    // ================================================
    // ======== Прекращение экспорта (Cancel) =========
    // ================================================
    const cancelExport = async () => {
        if (!exportTaskId) return;
        const token = Cookies.get('token');
        try {
            await axios.post(
                `${API_URL}/admin/cancel-export/${exportTaskId}`,
                {},
                { headers: { Authorization: `Bearer ${token}` } }
            );
            // Отмена успешно отправлена, можно сбросить состояние
            setIsExporting(false);
            setProgress(-1);
            setExportError('Экспорт отменён пользователем.');
        } catch (err) {
            console.error(err);
            setError('Ошибка при отмене экспорта.');
        }
    };

    // ================================================
    // ============ Скачать экспортированный ZIP ======
    // ================================================
    const downloadExportedFile = async () => {
        if (!exportTaskId) return;
        const token = Cookies.get('token');
        try {
            const response = await fetch(
                `${API_URL}/Admin/download-exported-file/${exportTaskId}`,
                { headers: { Authorization: `Bearer ${token}` } }
            );
            if (!response.ok) throw new Error('Не удалось скачать файл');

            const blob = await response.blob();
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `export_${exportTaskId}.zip`; // меняем расширение на .zip
            document.body.appendChild(a);
            a.click();
            a.remove();
            URL.revokeObjectURL(url);
        } catch (err) {
            console.error('Error downloading file:', err);
            setError('Ошибка при скачивании файла.');
        }
    };

    // ====================== Сохранение настроек ======================
    const handleSaveSettings = async () => {
        try {
            const settings = {
                yandexKassa: {
                    ShopId: yandexKassa.shopId,
                    SecretKey: yandexKassa.secretKey,
                    ReturnUrl: yandexKassa.returnUrl,
                    WebhookUrl: yandexKassa.webhookUrl
                },
                yandexDisk: {
                    Token: yandexDisk.token
                },
                typeOfAccessImages: {
                    UseLocalFiles: typeOfAccessImages.useLocalFiles,
                    LocalPathOfImages: typeOfAccessImages.localPathOfImages
                },
                yandexCloud: {
                    AccessKey: yandexCloud.accessKey,
                    SecretKey: yandexCloud.secretKey,
                    ServiceUrl: yandexCloud.serviceUrl,
                    BucketName: yandexCloud.bucketName
                },
                smtp: {
                    Host: smtp.host,
                    Port: smtp.port,
                    User: smtp.user,
                    Pass: smtp.pass
                },
                cacheSettings: {
                    LocalCachePath: cacheSettings.localCachePath,
                    DaysToKeep: cacheSettings.daysToKeep,
                    MaxCacheSizeMB: cacheSettings.maxCacheSizeMB
                }
            };

            await updateAdminSettings(settings);
            setError('');
        } catch (err) {
            console.error('Error updating settings:', err);
            setError('Ошибка при сохранении настроек');
        }
    };

    // ====================== Импорт ======================
    const initImportTask = async (fileSize) => {
        const res = await initImport(fileSize);
        setImportTaskId(res.importTaskId);
        return res.importTaskId;
    };

    const uploadFileChunks = async (file, taskId) => {
        const chunkSize = 1024 * 256; // 256 KB
        let offset = 0;
        while (offset < file.size) {
            const slice = file.slice(offset, offset + chunkSize);
            await uploadImportChunk(taskId, slice, () => {
                // можно отслеживать прогресс chunk'а
            });
            offset += chunkSize;
            const overallPct = Math.round((offset * 100) / file.size);
            setImportUploadProgress(overallPct);
        }
    };

    const finishUpload = async (taskId) => {
        await finishImport(taskId);
    };

    const pollImportProgress = async (taskId) => {
        if (!taskId) return;
        try {
            const data = await getImportProgress(taskId);
            if (data.uploadProgress >= 0) setImportUploadProgress(data.uploadProgress);
            if (data.importProgress >= 0) setImportProgress(data.importProgress);
            if (data.message) setImportMessage(data.message);

            if (data.isFinished || data.isCancelledOrError) {
                clearInterval(importPollIntervalId);
                setImportPollIntervalId(null);
                setIsImporting(false);
            }
        } catch (err) {
            console.error('Poll error:', err);
        }
    };

    const handleImportData = async () => {
        if (!importFile) {
            alert('Не выбран файл');
            return;
        }
        setIsImporting(true);
        setImportUploadProgress(0);
        setImportProgress(0);
        setImportMessage('');

        try {
            // Шаг 1: init
            const newTaskId = await initImportTask(importFile.size);

            // Шаг 2: upload
            await uploadFileChunks(importFile, newTaskId);

            // Шаг 3: finish
            await finishUpload(newTaskId);

            // Шаг 4: poll
            const pid = setInterval(() => {
                pollImportProgress(newTaskId);
            }, 500);
            setImportPollIntervalId(pid);
        } catch (err) {
            console.error('Import error:', err);
            setIsImporting(false);
            alert('Ошибка импорта');
        }
    };

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

    const handleCancelImport = async () => {
        if (!importTaskId) return;
        try {
            await cancelImport(importTaskId);
            alert('Импорт отменён');
            setIsImporting(false);
            if (importPollIntervalId) {
                clearInterval(importPollIntervalId);
                setImportPollIntervalId(null);
            }
        } catch (err) {
            console.error('Ошибка при отмене импорта:', err);
        }
    };

    // ====================== Обновление книг (meshok.net) ======================
    const fetchBookUpdateStatus = async () => {
        try {
            const token = Cookies.get('token');
            const response = await axios.get(`${API_URL}/bookupdateservice/status`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setBookUpdateStatus(response.data);  // у response.data будет поле logs
        } catch (err) {
            console.error('Ошибка при получении статуса сервиса обновления книг:', err);
        }
    };

    const pauseBookUpdate = async () => {
        try {
            const token = Cookies.get('token');
            await axios.post(`${API_URL}/bookupdateservice/pause`, {}, {
                headers: { Authorization: `Bearer ${token}` }
            });
            await fetchBookUpdateStatus();
        } catch (err) {
            console.error('Ошибка при постановке на паузу:', err);
        }
    };

    const resumeBookUpdate = async () => {
        try {
            const token = Cookies.get('token');
            await axios.post(`${API_URL}/bookupdateservice/resume`, {}, {
                headers: { Authorization: `Bearer ${token}` }
            });
            await fetchBookUpdateStatus();
        } catch (err) {
            console.error('Ошибка при возобновлении:', err);
        }
    };

    const runBookUpdateNow = async () => {
        try {
            const token = Cookies.get('token');
            await axios.post(`${API_URL}/bookupdateservice/runNow`, {}, {
                headers: { Authorization: `Bearer ${token}` }
            });
            await fetchBookUpdateStatus();
        } catch (err) {
            console.error('Ошибка при запуске обновления:', err);
        }
    };

    // Авто-обновление статуса
    useEffect(() => {
        let pollingId;
        if (currentTab === 'bookupdate') {
            fetchBookUpdateStatus();
            pollingId = setInterval(() => {
                fetchBookUpdateStatus();
            }, 2000);
        }
        return () => {
            if (pollingId) {
                clearInterval(pollingId);
            }
        };
        // eslint-disable-next-line
    }, [currentTab]);

    // ====================== Методы CRUD для планов подписки ======================
    const handleCreateOrUpdatePlan = async () => {
        setError('');
        try {
            const token = Cookies.get('token');
            if (!editMode) {
                // Создание нового
                await axios.post(`${API_URL}/subscriptionplans`, planForm, {
                    headers: { Authorization: `Bearer ${token}` }
                });
            } else {
                // Редактирование
                await axios.put(`${API_URL}/subscriptionplans/${planForm.id}`, planForm, {
                    headers: { Authorization: `Bearer ${token}` }
                });
            }

            // После сохранения — перезагрузить список
            await loadSubscriptionPlans();
            // Сброс формы:
            setPlanForm({ id: 0, name: '', price: 0, monthlyRequestLimit: 0, isActive: true });
            setEditMode(false);
        } catch (err) {
            console.error('Error creating/updating plan:', err);
            setError('Не удалось сохранить план подписки.');
        }
    };

    const handleEditPlan = (plan) => {
        setPlanForm(plan);
        setEditMode(true);
    };

    const handleDeletePlan = async (planId) => {
        if (!window.confirm('Точно удалить этот план?')) return;
        setError('');
        try {
            const token = Cookies.get('token');
            await axios.delete(`${API_URL}/subscriptionplans/${planId}`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            loadSubscriptionPlans();
        } catch (err) {
            console.error('Error deleting plan:', err);
            setError('Не удалось удалить план подписки.');
        }
    };

    // Обработка смены вкладки
    const handleTabChange = (event, newValue) => {
        setCurrentTab(newValue);
    };

    // ====================== Рендер контента по вкладкам ======================
    return (
        <Container maxWidth={false} sx={{ mt: 4, mb: 4, px: { xs: 1, sm: 2, md: 3 } }}>
            <Paper elevation={3} sx={{ p: { xs: 1, sm: 2, md: 3 }, borderRadius: '12px', mb: 4, overflow: 'hidden' }}>
                <Typography variant="h4" component="h1" gutterBottom sx={{ 
                    fontWeight: 'bold', 
                    color: '#2c3e50',
                    fontSize: { xs: '1.5rem', sm: '1.75rem', md: '2rem' }
                }}>
                    Панель администратора
                </Typography>
                
                {error && (
                    <Alert severity="error" sx={{ mb: 3 }}>
                        {error}
                    </Alert>
                )}

                <Box sx={{ borderBottom: 1, borderColor: 'divider', mb: 3 }}>
                    <Tabs 
                        value={currentTab} 
                        onChange={handleTabChange} 
                        variant="scrollable"
                        scrollButtons="auto"
                        allowScrollButtonsMobile
                        sx={{
                            '& .MuiTab-root': {
                                fontWeight: 'bold',
                                fontSize: { xs: '0.8rem', sm: '0.9rem', md: '1rem' },
                                minWidth: { xs: 80, sm: 100, md: 120 },
                                py: { xs: 1, md: 1.5 },
                                px: { xs: 1, sm: 1.5, md: 2 }
                            },
                            '.MuiTabs-scrollButtons': {
                                '&.Mui-disabled': { opacity: 0.3 },
                            }
                        }}
                    >
                        <Tab label="Пользователи" value="users" />
                        <Tab label="Экспорт данных" value="export" />
                        <Tab label="Настройки" value="settings" />
                        <Tab label="Импорт данных" value="import" />
                        <Tab label="Обновление книг" value="bookupdate" />
                        <Tab label="Планы подписки" value="subplans" />
                        <Tab label="Категории" value="categories" />
                    </Tabs>
                </Box>

                <Box sx={{ 
                    overflowX: 'auto',
                    '& .MuiTableContainer-root': {
                        overflowX: 'auto'
                    },
                    '& .MuiTable-root': {
                        minWidth: { xs: 320, sm: 500, md: 650 }
                    }
                }}>
                    
                {/* ============ Вкладка "users" ============ */}
                {currentTab === 'users' && (
                    <Box>
                        <Typography variant="h5" component="h2" gutterBottom sx={{ 
                            fontWeight: 'bold', 
                            color: '#2c3e50', 
                            mb: 3,
                            fontSize: { xs: '1.2rem', sm: '1.4rem', md: '1.5rem' }
                        }}>
                            Управление пользователями
                        </Typography>
                        
                        {/* Desktop view - полная таблица для десктопа */}
                        {!isMobile && (
                            <TableContainer component={Paper} elevation={2} sx={{ mb: 4, borderRadius: '8px' }}>
                                <Table sx={{ minWidth: 650 }}>
                                    <TableHead sx={{ backgroundColor: '#f5f5f5' }}>
                                        <TableRow>
                                            <TableCell>Email</TableCell>
                                            <TableCell>Роль</TableCell>
                                            <TableCell>Активна?</TableCell>
                                            <TableCell>План</TableCell>
                                            <TableCell>Автопродление</TableCell>
                                            <TableCell>Лимит запросов</TableCell>
                                            <TableCell>Действия</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {users.map((user) => {
                                            const sub = user.currentSubscription;
                                            return (
                                                <TableRow key={user.id} hover>
                                                    <TableCell>{user.email}</TableCell>
                                                    <TableCell>{user.role || '-'}</TableCell>
                                                    <TableCell>{sub ? 'Да' : 'Нет'}</TableCell>
                                                    <TableCell>{sub?.subscriptionPlan?.name || '-'}</TableCell>
                                                    <TableCell>{sub?.autoRenew ? 'Да' : 'Нет'}</TableCell>
                                                    <TableCell>{sub?.subscriptionPlan?.monthlyRequestLimit ?? '-'}</TableCell>
                                                    <TableCell>
                                                        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                                                            <Button 
                                                                variant="contained" 
                                                                size="small"
                                                                onClick={() => openSubscriptionModal(user)}
                                                                sx={{ 
                                                                    backgroundColor: '#E72B3D',
                                                                    '&:hover': { backgroundColor: '#c4242f' }
                                                                }}
                                                            >
                                                                Изменить подписку
                                                            </Button>
                                                            
                                                            <Button 
                                                                variant="outlined" 
                                                                size="small"
                                                                onClick={() => handleViewDetails(user.id)}
                                                                sx={{ borderColor: '#E72B3D', color: '#E72B3D' }}
                                                            >
                                                                Детали
                                                            </Button>
                                                            
                                                            {(!user.role || user.role.toLowerCase() !== 'admin') && (
                                                                <Button 
                                                                    variant="outlined" 
                                                                    size="small"
                                                                    onClick={() => handleUpdateUserRole(user.id, 'admin')}
                                                                    sx={{ borderColor: '#2196f3', color: '#2196f3' }}
                                                                >
                                                                    Сделать админом
                                                                </Button>
                                                            )}
                                                            
                                                            {user.role && user.role.toLowerCase() === 'admin' && user.email !== 'test@test.com' && (
                                                                <Button 
                                                                    variant="outlined" 
                                                                    size="small"
                                                                    onClick={() => handleUpdateUserRole(user.id, 'user')}
                                                                    sx={{ borderColor: '#f44336', color: '#f44336' }}
                                                                >
                                                                    Снять админа
                                                                </Button>
                                                            )}
                                                        </Box>
                                                    </TableCell>
                                                </TableRow>
                                            );
                                        })}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        )}
                        
                        {/* Mobile view - карточки вместо таблицы для мобильных */}
                        {isMobile && (
                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, mb: 4 }}>
                                {users.map((user) => {
                                    const sub = user.currentSubscription;
                                    return (
                                        <Card key={user.id} sx={{ mb: 2, overflow: 'visible' }}>
                                            <CardContent sx={{ p: 2 }}>
                                                <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                                                    {user.email}
                                                </Typography>
                                                
                                                <Grid container spacing={1} sx={{ mb: 2 }}>
                                                    <Grid item xs={6}>
                                                        <Typography variant="body2" color="text.secondary">Роль:</Typography>
                                                        <Typography variant="body1">{user.role || '-'}</Typography>
                                                    </Grid>
                                                    <Grid item xs={6}>
                                                        <Typography variant="body2" color="text.secondary">Активна:</Typography>
                                                        <Typography variant="body1">{sub ? 'Да' : 'Нет'}</Typography>
                                                    </Grid>
                                                    <Grid item xs={6}>
                                                        <Typography variant="body2" color="text.secondary">План:</Typography>
                                                        <Typography variant="body1">{sub?.subscriptionPlan?.name || '-'}</Typography>
                                                    </Grid>
                                                    <Grid item xs={6}>
                                                        <Typography variant="body2" color="text.secondary">Автопродление:</Typography>
                                                        <Typography variant="body1">{sub?.autoRenew ? 'Да' : 'Нет'}</Typography>
                                                    </Grid>
                                                    <Grid item xs={12}>
                                                        <Typography variant="body2" color="text.secondary">Лимит запросов:</Typography>
                                                        <Typography variant="body1">{sub?.subscriptionPlan?.monthlyRequestLimit ?? '-'}</Typography>
                                                    </Grid>
                                                </Grid>
                                                
                                                <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                                                    <Button 
                                                        variant="contained" 
                                                        size="small"
                                                        onClick={() => openSubscriptionModal(user)}
                                                        sx={{ 
                                                            backgroundColor: '#E72B3D',
                                                            '&:hover': { backgroundColor: '#c4242f' },
                                                            flexGrow: 1
                                                        }}
                                                    >
                                                        Изменить подписку
                                                    </Button>
                                                    
                                                    <Button 
                                                        variant="outlined" 
                                                        size="small"
                                                        onClick={() => handleViewDetails(user.id)}
                                                        sx={{ borderColor: '#E72B3D', color: '#E72B3D', flexGrow: 1 }}
                                                    >
                                                        Детали
                                                    </Button>
                                                    
                                                    {(!user.role || user.role.toLowerCase() !== 'admin') && (
                                                        <Button 
                                                            variant="outlined" 
                                                            size="small"
                                                            onClick={() => handleUpdateUserRole(user.id, 'admin')}
                                                            sx={{ borderColor: '#2196f3', color: '#2196f3', flexGrow: 1 }}
                                                        >
                                                            Сделать админом
                                                        </Button>
                                                    )}
                                                    
                                                    {user.role && user.role.toLowerCase() === 'admin' && user.email !== 'test@test.com' && (
                                                        <Button 
                                                            variant="outlined" 
                                                            size="small"
                                                            onClick={() => handleUpdateUserRole(user.id, 'user')}
                                                            sx={{ borderColor: '#f44336', color: '#f44336', flexGrow: 1 }}
                                                        >
                                                            Снять админа
                                                        </Button>
                                                    )}
                                                </Box>
                                            </CardContent>
                                        </Card>
                                    );
                                })}
                            </Box>
                        )}
                    </Box>
                )}

                {/* ============ Вкладка "import" ============ */}
                {currentTab === 'import' && (
                    <Box>
                        <Typography variant="h5" component="h2" gutterBottom sx={{ fontWeight: 'bold', color: '#2c3e50', mb: 3 }}>
                            Импорт данных
                        </Typography>
                        <Import />
                    </Box>
                )}

                {/* ============ Вкладка "export" ============ */}
                {currentTab === 'export' && (
                    <Box>
                        <Typography variant="h5" component="h2" gutterBottom sx={{ fontWeight: 'bold', color: '#2c3e50', mb: 3 }}>
                            Экспорт данных
                        </Typography>
                        <Export />
                    </Box>
                )}

                {/* ============ Вкладка "settings" ============ */}
                {currentTab === 'settings' && (
                    <Box>
                        <Typography variant="h5" component="h2" gutterBottom sx={{ fontWeight: 'bold', color: '#2c3e50', mb: 3 }}>
                            Редактирование настроек (appsettings.json)
                        </Typography>

                        {/* YandexKassa */}
                        <Card variant="outlined" sx={{ mb: 3, borderRadius: '8px' }}>
                            <CardContent>
                                <Typography variant="h6" gutterBottom fontWeight="bold">YandexKassa</Typography>
                                <Grid container spacing={2}>
                                    <Grid item xs={12} sm={6} md={3}>
                                        <TextField
                                            fullWidth
                                            label="ShopId"
                                            variant="outlined"
                                            size="small"
                                            value={yandexKassa.shopId}
                                            onChange={(e) =>
                                                setYandexKassa({
                                                    ...yandexKassa,
                                                    shopId: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                    <Grid item xs={12} sm={6} md={3}>
                                        <TextField
                                            fullWidth
                                            label="SecretKey"
                                            variant="outlined"
                                            size="small"
                                            value={yandexKassa.secretKey}
                                            onChange={(e) =>
                                                setYandexKassa({
                                                    ...yandexKassa,
                                                    secretKey: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                    <Grid item xs={12} sm={6} md={3}>
                                        <TextField
                                            fullWidth
                                            label="ReturnUrl"
                                            variant="outlined"
                                            size="small"
                                            value={yandexKassa.returnUrl}
                                            onChange={(e) =>
                                                setYandexKassa({
                                                    ...yandexKassa,
                                                    returnUrl: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                    <Grid item xs={12} sm={6} md={3}>
                                        <TextField
                                            fullWidth
                                            label="WebhookUrl"
                                            variant="outlined"
                                            size="small"
                                            value={yandexKassa.webhookUrl}
                                            onChange={(e) =>
                                                setYandexKassa({
                                                    ...yandexKassa,
                                                    webhookUrl: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                </Grid>
                            </CardContent>
                        </Card>

                        {/* YandexDisk */}
                        <Card variant="outlined" sx={{ mb: 3, borderRadius: '8px' }}>
                            <CardContent>
                                <Typography variant="h6" gutterBottom fontWeight="bold">YandexDisk</Typography>
                                <Grid container spacing={2}>
                                    <Grid item xs={12} sm={6}>
                                        <TextField
                                            fullWidth
                                            label="Token"
                                            variant="outlined"
                                            size="small"
                                            value={yandexDisk.token}
                                            onChange={(e) =>
                                                setYandexDisk({
                                                    ...yandexDisk,
                                                    token: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                </Grid>
                            </CardContent>
                        </Card>

                        {/* Настройки доступа к изображениям */}
                        <Card variant="outlined" sx={{ mb: 3, borderRadius: '8px' }}>
                            <CardContent>
                                <Typography variant="h6" gutterBottom fontWeight="bold">Настройки доступа к изображениям</Typography>
                                <Grid container spacing={2}>
                                    <Grid item xs={12}>
                                        <FormControlLabel
                                            control={
                                                <Switch
                                                    checked={typeOfAccessImages.useLocalFiles === 'true'}
                                                    onChange={(e) =>
                                                        setTypeOfAccessImages({
                                                            ...typeOfAccessImages,
                                                            useLocalFiles: e.target.checked ? 'true' : 'false'
                                                        })
                                                    }
                                                />
                                            }
                                            label="Использовать локальные файлы"
                                        />
                                    </Grid>
                                    <Grid item xs={12}>
                                        <TextField
                                            fullWidth
                                            label="Путь к локальным изображениям"
                                            variant="outlined"
                                            size="small"
                                            value={typeOfAccessImages.localPathOfImages}
                                            onChange={(e) =>
                                                setTypeOfAccessImages({
                                                    ...typeOfAccessImages,
                                                    localPathOfImages: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                </Grid>
                            </CardContent>
                        </Card>

                        {/* YandexCloud */}
                        <Card variant="outlined" sx={{ mb: 3, borderRadius: '8px' }}>
                            <CardContent>
                                <Typography variant="h6" gutterBottom fontWeight="bold">YandexCloud</Typography>
                                <Grid container spacing={2}>
                                    <Grid item xs={12} sm={6}>
                                        <TextField
                                            fullWidth
                                            label="AccessKey"
                                            variant="outlined"
                                            size="small"
                                            value={yandexCloud.accessKey}
                                            onChange={(e) =>
                                                setYandexCloud({
                                                    ...yandexCloud,
                                                    accessKey: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                    <Grid item xs={12} sm={6}>
                                        <TextField
                                            fullWidth
                                            label="SecretKey"
                                            variant="outlined"
                                            size="small"
                                            value={yandexCloud.secretKey}
                                            onChange={(e) =>
                                                setYandexCloud({
                                                    ...yandexCloud,
                                                    secretKey: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                    <Grid item xs={12} sm={6}>
                                        <TextField
                                            fullWidth
                                            label="ServiceUrl"
                                            variant="outlined"
                                            size="small"
                                            value={yandexCloud.serviceUrl}
                                            onChange={(e) =>
                                                setYandexCloud({
                                                    ...yandexCloud,
                                                    serviceUrl: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                    <Grid item xs={12} sm={6}>
                                        <TextField
                                            fullWidth
                                            label="BucketName"
                                            variant="outlined"
                                            size="small"
                                            value={yandexCloud.bucketName}
                                            onChange={(e) =>
                                                setYandexCloud({
                                                    ...yandexCloud,
                                                    bucketName: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                </Grid>
                            </CardContent>
                        </Card>

                        {/* SMTP */}
                        <Card variant="outlined" sx={{ mb: 3, borderRadius: '8px' }}>
                            <CardContent>
                                <Typography variant="h6" gutterBottom fontWeight="bold">SMTP</Typography>
                                <Grid container spacing={2}>
                                    <Grid item xs={12} sm={6}>
                                        <TextField
                                            fullWidth
                                            label="Host"
                                            variant="outlined"
                                            size="small"
                                            value={smtp.host}
                                            onChange={(e) =>
                                                setSmtp({
                                                    ...smtp,
                                                    host: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                    <Grid item xs={12} sm={6}>
                                        <TextField
                                            fullWidth
                                            label="Port"
                                            variant="outlined"
                                            size="small"
                                            value={smtp.port}
                                            onChange={(e) =>
                                                setSmtp({
                                                    ...smtp,
                                                    port: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                    <Grid item xs={12} sm={6}>
                                        <TextField
                                            fullWidth
                                            label="User"
                                            variant="outlined"
                                            size="small"
                                            value={smtp.user}
                                            onChange={(e) =>
                                                setSmtp({
                                                    ...smtp,
                                                    user: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                    <Grid item xs={12} sm={6}>
                                        <TextField
                                            fullWidth
                                            label="Password"
                                            type="password"
                                            variant="outlined"
                                            size="small"
                                            value={smtp.pass}
                                            onChange={(e) =>
                                                setSmtp({
                                                    ...smtp,
                                                    pass: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                </Grid>
                            </CardContent>
                        </Card>

                        {/* Cache Settings */}
                        <Card variant="outlined" sx={{ mb: 3, borderRadius: '8px' }}>
                            <CardContent>
                                <Typography variant="h6" gutterBottom fontWeight="bold">Настройки кэша</Typography>
                                <Grid container spacing={2}>
                                    <Grid item xs={12}>
                                        <TextField
                                            fullWidth
                                            label="Путь к локальному кэшу"
                                            variant="outlined"
                                            size="small"
                                            value={cacheSettings.localCachePath}
                                            onChange={(e) =>
                                                setCacheSettings({
                                                    ...cacheSettings,
                                                    localCachePath: e.target.value
                                                })
                                            }
                                        />
                                    </Grid>
                                    <Grid item xs={12} sm={6}>
                                        <TextField
                                            fullWidth
                                            label="Дней хранения"
                                            type="number"
                                            variant="outlined"
                                            size="small"
                                            value={cacheSettings.daysToKeep}
                                            onChange={(e) =>
                                                setCacheSettings({
                                                    ...cacheSettings,
                                                    daysToKeep: parseInt(e.target.value) || 0
                                                })
                                            }
                                        />
                                    </Grid>
                                    <Grid item xs={12} sm={6}>
                                        <TextField
                                            fullWidth
                                            label="Максимальный размер кэша (МБ)"
                                            type="number"
                                            variant="outlined"
                                            size="small"
                                            value={cacheSettings.maxCacheSizeMB}
                                            onChange={(e) =>
                                                setCacheSettings({
                                                    ...cacheSettings,
                                                    maxCacheSizeMB: parseInt(e.target.value) || 0
                                                })
                                            }
                                        />
                                    </Grid>
                                </Grid>
                            </CardContent>
                        </Card>

                        <Box sx={{ display: 'flex', justifyContent: 'flex-end', mt: 2 }}>
                            <Button
                                variant="contained"
                                onClick={handleSaveSettings}
                                sx={{ 
                                    backgroundColor: '#E72B3D',
                                    '&:hover': { backgroundColor: '#c4242f' }
                                }}
                            >
                                Сохранить настройки
                            </Button>
                        </Box>
                    </Box>
                )}

                {/* ============ Вкладка "bookupdate" ============ */}
                {currentTab === 'bookupdate' && (
                    <BookUpdate />
                )}

                {/* ============ Вкладка "subplans" ============ */}
                {currentTab === 'subplans' && (
                    <SubPlans />
                )}

                {/* ============ Вкладка "categories" ============ */}
                {currentTab === 'categories' && (
                    <Box>
                        <Typography variant="h5" component="h2" gutterBottom sx={{ fontWeight: 'bold', color: '#2c3e50', mb: 3 }}>
                            Управление категориями
                        </Typography>
                        <CategoryCleanup />
                    </Box>
                )}

                {/* Модалка назначения плана */}
                <Dialog 
                    open={showSubModal} 
                    onClose={() => setShowSubModal(false)}
                    maxWidth="sm"
                    fullWidth
                >
                    <DialogTitle sx={{ fontWeight: 'bold' }}>
                        Изменить подписку пользователя {selectedUserForSub?.email}
                    </DialogTitle>
                    <DialogContent>
                        <Box sx={{ pt: 1 }}>
                            <FormControl fullWidth sx={{ mb: 2 }}>
                                <InputLabel>План подписки</InputLabel>
                                <Select
                                    value={selectedPlanForSub}
                                    label="План подписки"
                                    onChange={(e) => setSelectedPlanForSub(e.target.value)}
                                >
                                    <MenuItem value={0}> -- Отключить подписку -- </MenuItem>
                                    {subPlans.map(plan => (
                                        <MenuItem key={plan.id} value={plan.id}>
                                            {plan.name} (лимит запросов: {plan.monthlyRequestLimit})
                                        </MenuItem>
                                    ))}
                                </Select>
                            </FormControl>

                            <FormControlLabel
                                control={
                                    <Checkbox
                                        checked={autoRenewForSub}
                                        onChange={(e) => setAutoRenewForSub(e.target.checked)}
                                    />
                                }
                                label="Автопродление"
                            />
                        </Box>
                    </DialogContent>
                    <DialogActions sx={{ px: 3, pb: 3 }}>
                        <Button 
                            onClick={() => setShowSubModal(false)} 
                            color="inherit"
                        >
                            Отмена
                        </Button>
                        <Button 
                            onClick={handleAssignSubscriptionPlan}
                            variant="contained"
                            sx={{ 
                                backgroundColor: '#E72B3D',
                                '&:hover': { backgroundColor: '#c4242f' }
                            }}
                        >
                            Сохранить
                        </Button>
                    </DialogActions>
                </Dialog>
            </Box>
            </Paper>
        </Container>
    );
};

export default AdminPanel;
