// src/components/AdminPanel.jsx
import React, { useEffect, useState } from 'react';
import {
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
    useMediaQuery, useTheme, Drawer, List, ListItem, ListItemText,
    IconButton, AppBar, Toolbar
} from '@mui/material';
import { CategoryCleanup, SubPlans, BookUpdate, Import, Export, UsersPanel, SettingsPanel } from './admin';
import MenuIcon from '@mui/icons-material/Menu';

const AdminPanel = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const isTablet = useMediaQuery(theme.breakpoints.down('md'));
    
    // Состояние для drawer (бокового меню)
    const [drawerOpen, setDrawerOpen] = useState(false);
    
    // Вкладки: 'users' | 'export' | 'settings' | 'import' | 'bookupdate' | 'subplans' | 'categories'
    const [currentTab, setCurrentTab] = useState('users');

    // ----- Состояния пользователей
    const [error, setError] = useState('');

    // Состояния для экспорта
    const [exportTaskId, setExportTaskId] = useState(null);
    const [progress, setProgress] = useState(null);        // число (0..100 или -1)
    const [exportError, setExportError] = useState(null);  // текст ошибки с сервера, если есть
    const [exportInternalError, setExportInternalError] = useState(null);  
    const [isExporting, setIsExporting] = useState(false);
    const [intervalId, setIntervalId] = useState(null);

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

    const navigate = useNavigate();

    useEffect(() => {
        loadSubscriptionPlans(); // Загрузим планы при первом рендере
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
            // Используем AbortController для контроля timeout'а
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 300000); // 5 минут

            const response = await fetch(
                `${API_URL}/admin/download-exported-file/${exportTaskId}`, // исправляем регистр
                { 
                    headers: { Authorization: `Bearer ${token}` },
                    signal: controller.signal
                }
            );
            
            clearTimeout(timeoutId);
            
            if (!response.ok) throw new Error('Не удалось скачать файл');

            const blob = await response.blob();
            
            // Проверяем, что получили данные
            if (!blob || blob.size === 0) {
                throw new Error('Получен пустой файл');
            }
            
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `export_${exportTaskId}.zip`;
            document.body.appendChild(a);
            a.click();
            a.remove();
            URL.revokeObjectURL(url);
        } catch (err) {
            console.error('Error downloading file:', err);
            
            if (err.name === 'AbortError') {
                setError('Превышено время ожидания загрузки. Попробуйте еще раз.');
            } else if (err.message === 'Network Error' || err.message.includes('fetch')) {
                setError('Ошибка сети. Проверьте подключение к интернету.');
            } else {
                setError('Ошибка при скачивании файла: ' + err.message);
            }
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
        // Закрываем drawer, если открыто на мобильном
        if (isMobile && drawerOpen) {
            setDrawerOpen(false);
        }
    };

    // Объект с названиями вкладок для отображения в drawer
    const tabLabels = {
        users: 'Пользователи',
        export: 'Экспорт данных',
        settings: 'Настройки',
        import: 'Импорт данных',
        bookupdate: 'Обновление книг',
        subplans: 'Планы подписки',
        categories: 'Управление категориями'
    };

    // ====================== Рендер контента по вкладкам ======================
    return (
        <Container maxWidth={false} sx={{ mt: 4, mb: 4, px: { xs: 1, sm: 2, md: 3 } }}>
            <Paper elevation={3} sx={{ p: { xs: 1, sm: 2, md: 3 }, borderRadius: '12px', mb: 4, overflow: 'hidden' }}>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                    {isMobile && (
                        <IconButton
                            edge="start"
                            color="inherit"
                            aria-label="menu"
                            onClick={() => setDrawerOpen(true)}
                            sx={{ mr: 2 }}
                        >
                            <MenuIcon />
                        </IconButton>
                    )}
                <Typography variant="h4" component="h1" gutterBottom sx={{ 
                    fontWeight: 'bold', 
                    color: '#2c3e50',
                        fontSize: { xs: '1.5rem', sm: '1.75rem', md: '2rem' },
                        my: 0
                }}>
                    Панель администратора
                </Typography>
                </Box>
                
                {error && (
                    <Alert severity="error" sx={{ mb: 3 }}>
                        {error}
                    </Alert>
                )}

                {/* Drawer для мобильных устройств */}
                <Drawer
                    anchor="left"
                    open={isMobile && drawerOpen}
                    onClose={() => setDrawerOpen(false)}
                >
                    <Box
                        sx={{ width: 280 }}
                        role="presentation"
                    >
                        <List>
                            <ListItem sx={{ borderBottom: 1, borderColor: 'divider', py: 2 }}>
                                <Typography variant="h6">Панель администратора</Typography>
                            </ListItem>
                            {Object.entries(tabLabels).map(([key, label]) => (
                                <ListItem 
                                    button 
                                    key={key}
                                    onClick={() => {
                                        setCurrentTab(key);
                                        setDrawerOpen(false);
                                    }}
                                    selected={currentTab === key}
                                    sx={{
                                        bgcolor: currentTab === key ? 'rgba(0, 0, 0, 0.08)' : 'transparent',
                                        '&:hover': {
                                            bgcolor: 'rgba(0, 0, 0, 0.04)'
                                        }
                                    }}
                                >
                                    <ListItemText primary={label} />
                                </ListItem>
                            ))}
                        </List>
                    </Box>
                </Drawer>

                {/* Вкладки для десктопа */}
                {!isMobile && (
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
                )}

                {/* Отображение заголовка активной вкладки для мобильных устройств */}
                {isMobile && (
                    <Typography 
                        variant="h5" 
                        component="h2" 
                        gutterBottom 
                        sx={{ 
                            fontWeight: 'bold', 
                            color: '#2c3e50',
                            mb: 3,
                            borderBottom: '1px solid rgba(0, 0, 0, 0.1)',
                            pb: 1
                        }}
                    >
                        {tabLabels[currentTab]}
                    </Typography>
                )}

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
                    <UsersPanel />
                )}

                {/* ============ Вкладка "import" ============ */}
                {currentTab === 'import' && (
                    <Box>
                        {!isMobile && (
                        <Typography variant="h5" component="h2" gutterBottom sx={{ fontWeight: 'bold', color: '#2c3e50', mb: 3 }}>
                            Импорт данных
                        </Typography>
                        )}
                        <Import />
                    </Box>
                )}

                {/* ============ Вкладка "export" ============ */}
                {currentTab === 'export' && (
                    <Box>
                        {!isMobile && (
                        <Typography variant="h5" component="h2" gutterBottom sx={{ fontWeight: 'bold', color: '#2c3e50', mb: 3 }}>
                            Экспорт данных
                        </Typography>
                        )}
                        <Export />
                    </Box>
                )}

                {/* ============ Вкладка "settings" ============ */}
                {currentTab === 'settings' && (
                    <SettingsPanel />
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
                        {!isMobile && (
                        <Typography variant="h5" component="h2" gutterBottom sx={{ fontWeight: 'bold', color: '#2c3e50', mb: 3 }}>
                            Управление категориями
                        </Typography>
                        )}
                        <CategoryCleanup />
                    </Box>
                )}
            </Box>
            </Paper>
        </Container>
    );
};

export default AdminPanel;
