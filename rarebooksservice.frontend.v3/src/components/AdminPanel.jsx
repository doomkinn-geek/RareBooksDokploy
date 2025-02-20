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

const AdminPanel = () => {
    // Вкладки: 'users' | 'export' | 'settings' | 'import' | 'bookupdate' | 'subplans'
    const [currentTab, setCurrentTab] = useState('users');

    // ----- Состояния пользователей
    const [users, setUsers] = useState([]);
    const [error, setError] = useState('');

    // Состояния для экспорта
    const [exportTaskId, setExportTaskId] = useState(null);
    const [progress, setProgress] = useState(null);        // число (0..100 или -1)
    const [exportError, setExportError] = useState(null);  // текст ошибки с сервера, если есть
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
        lastProcessedLotTitle: ''
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
                { headers: { Authorization: `Bearer ${token}` } }
            );

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
                    // сервер возвращает объект вида:
                    // { Progress: number, IsError: bool, ErrorDetails: string }
                    const { progress, isError, errorDetails } = progressRes.data;

                    // Обновляем состояние
                    setProgress(progress);

                    if (isError && progress === -1) {
                        // Сервер сообщил об ошибке => выходим из режима экспорта
                        setExportError(errorDetails || 'Неизвестная ошибка при экспорте');
                        setIsExporting(false);
                        clearInterval(id);
                        setIntervalId(null);
                    }
                    else if (progress >= 100) {
                        // Экспорт завершён
                        setIsExporting(false);
                        clearInterval(id);
                        setIntervalId(null);
                    }
                    // Иначе просто продолжаем (прогресс < 100, IsError=false)
                } catch (e) {
                    // Ошибка самого запроса (сеть, 500 и т.п.)
                    console.error(e);
                    setError('Ошибка при получении прогресса экспорта (сетевая или серверная).');
                    setIsExporting(false);
                    clearInterval(id);
                    setIntervalId(null);
                }
            }, 1000);  // например, раз в секунду

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
                `${API_URL}/admin/download-exported-file/${exportTaskId}`,
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
            const settingsDto = {
                yandexKassa: {
                    shopId: yandexKassa.shopId,
                    secretKey: yandexKassa.secretKey,
                    returnUrl: yandexKassa.returnUrl,
                    webhookUrl: yandexKassa.webhookUrl
                },
                yandexDisk: {
                    token: yandexDisk.token
                },
                typeOfAccessImages: {
                    useLocalFiles: typeOfAccessImages.useLocalFiles,
                    localPathOfImages: typeOfAccessImages.localPathOfImages
                },
                yandexCloud: {
                    accessKey: yandexCloud.accessKey,
                    secretKey: yandexCloud.secretKey,
                    serviceUrl: yandexCloud.serviceUrl,
                    bucketName: yandexCloud.bucketName
                },
                smtp: {
                    host: smtp.host,
                    port: smtp.port,
                    user: smtp.user,
                    pass: smtp.pass
                },
                cacheSettings: {
                    localCachePath: cacheSettings.localCachePath,
                    daysToKeep: Number(cacheSettings.daysToKeep),
                    maxCacheSizeMB: Number(cacheSettings.maxCacheSizeMB)
                }
            };
            await updateAdminSettings(settingsDto);
            alert('Настройки сохранены успешно');
        } catch (err) {
            console.error('Error saving settings:', err);
            alert('Ошибка при сохранении настроек.');
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
            setBookUpdateStatus(response.data);
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

    // ====================== Рендер кнопок для вкладок (select) ======================
    const renderTabButtons = (
        <div className="admin-tabs">
            <select
                className="admin-tab-selector"
                value={currentTab}
                onChange={(e) => setCurrentTab(e.target.value)}
            >
                <option value="users">Пользователи</option>
                <option value="export">Экспорт данных</option>
                <option value="settings">Настройки</option>
                <option value="import">Импорт данных</option>
                <option value="bookupdate">Обновление книг</option>
                {/* Новая вкладка: Планы подписки */}
                <option value="subplans">Планы подписки</option>
            </select>
        </div>
    );

    // ====================== Рендер контента по вкладкам ======================
    return (
        <div className="admin-panel-container">
            <h2 className="admin-title">Панель администратора</h2>
            {error && <div className="admin-error">{error}</div>}

            {renderTabButtons}

            <div className="admin-tab-content">

                {/* ============ Вкладка "users" ============ */}
                {currentTab === 'users' && (
                    <div className="admin-section">
                        <h3 className="admin-section-title">Управление пользователями</h3>
                        <table className="admin-table responsive-table">
                            <thead>
                                <tr>
                                    <th>Email</th>
                                    <th>Роль</th>
                                    <th>Активна?</th>
                                    <th>План</th>
                                    <th>Автопродление</th>
                                    <th>Лимит запросов</th>
                                    <th>Действия</th>
                                </tr>
                            </thead>
                            <tbody>
                                {users.map((user) => {
                                    const sub = user.currentSubscription;
                                    return (
                                        <tr key={user.id}>
                                            <td data-label="Email">{user.email}</td>
                                            <td data-label="Роль">{user.role}</td>

                                            {/* Активна ли? */}
                                            <td data-label="Активна?">{sub ? 'Да' : 'Нет'}</td>
                                            <td data-label="План">{sub?.subscriptionPlan?.name || '-'}</td>
                                            <td data-label="Автопродление">{sub?.autoRenew ? 'Да' : 'Нет'}</td>
                                            <td data-label="Лимит запросов">{sub?.subscriptionPlan?.monthlyRequestLimit ?? '-'}</td>

                                            <td data-label="Действия">
                                                <div className="actions-container">
                                                    {/* Кнопка модалки */}
                                                    <button onClick={() => openSubscriptionModal(user)}>
                                                        Изменить подписку
                                                    </button>

                                                    {/* Пример: кнопка смены роли */}
                                                    <button onClick={() => handleUpdateUserRole(user.id,
                                                        user.role === 'Admin' ? 'User' : 'Admin')}>
                                                        {user.role === 'Admin' ? 'Разжаловать в User' : 'Назначить Admin'}
                                                    </button>

                                                    {/* Пример: кнопка "подробнее" */}
                                                    <button onClick={() => handleViewDetails(user.id)}>
                                                        Просмотр
                                                    </button>
                                                </div>
                                            </td>
                                        </tr>
                                    );
                                })}

                            </tbody>

                        </table>
                    </div>
                )}

                {/* ============ Вкладка "export" ============ */}
                {currentTab === 'export' && (
                    <div className="admin-section">
                        <h3 className="admin-section-title">Экспорт данных</h3>

                        <div className="admin-actions" style={{ marginBottom: '15px' }}>
                            <button
                                onClick={startExport}
                                className={`admin-button ${isExporting || isImporting ? 'admin-button-disabled' : ''}`}
                                disabled={isExporting || isImporting}
                            >
                                Начать экспорт в SQLite
                            </button>

                            {isExporting && exportTaskId && (
                                <button onClick={cancelExport} className="admin-button">
                                    Отменить экспорт
                                </button>
                            )}
                        </div>

                        {/* Блок отображения прогресса/ошибок */}
                        {exportTaskId && progress !== null && (
                            <div className="admin-export-status">
                                {progress === -1 ? (
                                    // Ошибка или отмена
                                    <div className="admin-error">
                                        Экспорт прерван: {exportError || 'Неизвестная причина'}
                                    </div>
                                ) : progress < 100 ? (
                                    <div>
                                        Прогресс экспорта: {progress}%
                                        {exportError && (
                                            <div style={{ marginTop: '10px', color: 'red', whiteSpace: 'pre-wrap' }}>
                                                {exportError}
                                            </div>
                                        )}
                                    </div>
                                ) : (
                                    <div className="admin-export-complete">
                                        Экспорт завершен!
                                        <button onClick={downloadExportedFile} className="admin-button">
                                            Скачать файл
                                        </button>
                                    </div>
                                )}
                            </div>
                        )}
                    </div>
                )}

                {/* ============ Вкладка "settings" ============ */}
                {currentTab === 'settings' && (
                    <div className="admin-section">
                        <h3>Редактирование настроек (appsettings.json)</h3>

                        {/* YandexKassa */}
                        <div
                            style={{
                                backgroundColor: '#f9f9f9',
                                padding: 10,
                                marginBottom: 10
                            }}
                        >
                            <h4>YandexKassa</h4>
                            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                                <div>
                                    <label>ShopId:</label>
                                    <br />
                                    <input
                                        type="text"
                                        value={yandexKassa.shopId}
                                        onChange={(e) =>
                                            setYandexKassa({
                                                ...yandexKassa,
                                                shopId: e.target.value
                                            })
                                        }
                                    />
                                </div>
                                <div>
                                    <label>SecretKey:</label>
                                    <br />
                                    <input
                                        type="text"
                                        value={yandexKassa.secretKey}
                                        onChange={(e) =>
                                            setYandexKassa({
                                                ...yandexKassa,
                                                secretKey: e.target.value
                                            })
                                        }
                                    />
                                </div>
                                <div>
                                    <label>ReturnUrl:</label>
                                    <br />
                                    <input
                                        type="text"
                                        value={yandexKassa.returnUrl}
                                        onChange={(e) =>
                                            setYandexKassa({
                                                ...yandexKassa,
                                                returnUrl: e.target.value
                                            })
                                        }
                                    />
                                </div>
                                <div>
                                    <label>WebhookUrl:</label>
                                    <br />
                                    <input
                                        type="text"
                                        value={yandexKassa.webhookUrl}
                                        onChange={(e) =>
                                            setYandexKassa({
                                                ...yandexKassa,
                                                webhookUrl: e.target.value
                                            })
                                        }
                                    />
                                </div>
                            </div>
                        </div>

                        {/* YandexDisk */}
                        <div
                            style={{
                                backgroundColor: '#f9f9f9',
                                padding: 10,
                                marginBottom: 10
                            }}
                        >
                            <h4>YandexDisk</h4>
                            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                                <div>
                                    <label>Token:</label>
                                    <br />
                                    <input
                                        type="text"
                                        value={yandexDisk.token}
                                        onChange={(e) =>
                                            setYandexDisk({
                                                ...yandexDisk,
                                                token: e.target.value
                                            })
                                        }
                                    />
                                </div>
                            </div>
                        </div>

                        {/* TypeOfAccessImages */}
                        <div
                            style={{
                                backgroundColor: '#f9f9f9',
                                padding: 10,
                                marginBottom: 10
                            }}
                        >
                            <h4>TypeOfAccessImages</h4>
                            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                                <div>
                                    <label>UseLocalFiles:</label>
                                    <br />
                                    <select
                                        value={typeOfAccessImages.useLocalFiles}
                                        onChange={(e) =>
                                            setTypeOfAccessImages({
                                                ...typeOfAccessImages,
                                                useLocalFiles: e.target.value
                                            })
                                        }
                                    >
                                        <option value="false">false</option>
                                        <option value="true">true</option>
                                    </select>
                                </div>
                                <div>
                                    <label>LocalPathOfImages:</label>
                                    <br />
                                    <input
                                        type="text"
                                        value={typeOfAccessImages.localPathOfImages}
                                        onChange={(e) =>
                                            setTypeOfAccessImages({
                                                ...typeOfAccessImages,
                                                localPathOfImages: e.target.value
                                            })
                                        }
                                    />
                                </div>
                            </div>
                        </div>

                        {/* YandexCloud */}
                        <div
                            style={{
                                backgroundColor: '#f9f9f9',
                                padding: 10,
                                marginBottom: 10
                            }}
                        >
                            <h4>YandexCloud</h4>
                            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                                <div>
                                    <label>AccessKey:</label>
                                    <br />
                                    <input
                                        type="text"
                                        value={yandexCloud.accessKey}
                                        onChange={(e) =>
                                            setYandexCloud({
                                                ...yandexCloud,
                                                accessKey: e.target.value
                                            })
                                        }
                                    />
                                </div>
                                <div>
                                    <label>SecretKey:</label>
                                    <br />
                                    <input
                                        type="text"
                                        value={yandexCloud.secretKey}
                                        onChange={(e) =>
                                            setYandexCloud({
                                                ...yandexCloud,
                                                secretKey: e.target.value
                                            })
                                        }
                                    />
                                </div>
                                <div>
                                    <label>ServiceUrl:</label>
                                    <br />
                                    <input
                                        type="text"
                                        value={yandexCloud.serviceUrl}
                                        onChange={(e) =>
                                            setYandexCloud({
                                                ...yandexCloud,
                                                serviceUrl: e.target.value
                                            })
                                        }
                                    />
                                </div>
                                <div>
                                    <label>BucketName:</label>
                                    <br />
                                    <input
                                        type="text"
                                        value={yandexCloud.bucketName}
                                        onChange={(e) =>
                                            setYandexCloud({
                                                ...yandexCloud,
                                                bucketName: e.target.value
                                            })
                                        }
                                    />
                                </div>
                            </div>
                        </div>

                        {/* SMTP */}
                        <div
                            style={{
                                backgroundColor: '#f9f9f9',
                                padding: 10,
                                marginBottom: 10
                            }}
                        >
                            <h4>SMTP</h4>
                            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                                <div>
                                    <label>Host:</label>
                                    <br />
                                    <input
                                        type="text"
                                        value={smtp.host}
                                        onChange={(e) =>
                                            setSmtp({ ...smtp, host: e.target.value })
                                        }
                                    />
                                </div>
                                <div>
                                    <label>Port:</label>
                                    <br />
                                    <input
                                        type="text"
                                        value={smtp.port}
                                        onChange={(e) =>
                                            setSmtp({ ...smtp, port: e.target.value })
                                        }
                                    />
                                </div>
                                <div>
                                    <label>User (email):</label>
                                    <br />
                                    <input
                                        type="text"
                                        value={smtp.user}
                                        onChange={(e) =>
                                            setSmtp({ ...smtp, user: e.target.value })
                                        }
                                    />
                                </div>
                                <div>
                                    <label>Pass (пароль):</label>
                                    <br />
                                    <input
                                        type="password"
                                        value={smtp.pass}
                                        onChange={(e) =>
                                            setSmtp({ ...smtp, pass: e.target.value })
                                        }
                                    />
                                </div>
                            </div>
                        </div>
                        <div style={{ backgroundColor: '#f9f9f9', padding: 10, marginBottom: 10 }}>
                            <h4>CacheSettings</h4>
                            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                                <div>
                                    <label>LocalCachePath:</label><br />
                                    <input
                                        type="text"
                                        value={cacheSettings.localCachePath}
                                        onChange={(e) =>
                                            setCacheSettings({ ...cacheSettings, localCachePath: e.target.value })
                                        }
                                    />
                                </div>
                                <div>
                                    <label>DaysToKeep:</label><br />
                                    <input
                                        type="number"
                                        value={cacheSettings.daysToKeep}
                                        onChange={(e) =>
                                            setCacheSettings({ ...cacheSettings, daysToKeep: e.target.value })
                                        }
                                    />
                                </div>
                                <div>
                                    <label>MaxCacheSizeMB:</label><br />
                                    <input
                                        type="number"
                                        value={cacheSettings.maxCacheSizeMB}
                                        onChange={(e) =>
                                            setCacheSettings({ ...cacheSettings, maxCacheSizeMB: e.target.value })
                                        }
                                    />
                                </div>
                            </div>
                        </div>

                        <div>
                            <button onClick={handleSaveSettings} className="admin-button">
                                Сохранить
                            </button>
                        </div>
                    </div>
                )}

                {/* ============ Вкладка "import" ============ */}
                {currentTab === 'import' && (
                    <div className="admin-section">
                        <h3 className="admin-section-title">Импорт данных из SQLite</h3>
                        <p>
                            Данные категорий и книг будут полностью перезаписаны.
                            Остальные данные (пользователи, подписки и пр.) не затрагиваются.
                        </p>

                        <div style={{ margin: '10px 0' }}>
                            <input
                                type="file"
                                accept=".zip"
                                onChange={handleSelectImportFile}
                                disabled={isImporting}
                            />
                        </div>
                        {importFile && <div>Выбран файл: {importFile.name}</div>}

                        <div style={{ marginTop: '10px' }}>
                            <button
                                className="admin-button"
                                onClick={handleImportData}
                                disabled={!importFile || isImporting}
                            >
                                Загрузить и импортировать
                            </button>
                            {isImporting && (
                                <button
                                    className="admin-button"
                                    onClick={handleCancelImport}
                                >
                                    Отменить
                                </button>
                            )}
                        </div>

                        {/* Прогресс загрузки файла */}
                        {importUploadProgress > 0 && importUploadProgress < 100 && (
                            <div style={{ marginTop: '10px' }}>
                                Загрузка файла: {importUploadProgress}%
                            </div>
                        )}
                        {importUploadProgress === 100 && <div>Файл загружен, идёт импорт...</div>}

                        {/* Прогресс импорта */}
                        {importProgress > 0 && importProgress < 100 && (
                            <div>Импорт: {importProgress}%</div>
                        )}
                        {importProgress === 100 && <div>Импорт завершён!</div>}

                        {importMessage && (
                            <div style={{ marginTop: '10px' }}>{importMessage}</div>
                        )}
                    </div>
                )}

                {/* ============ Вкладка "bookupdate" ============ */}
                {currentTab === 'bookupdate' && (
                    <div className="admin-section">
                        <h3 className="admin-section-title">
                            Сервис обновления книг (meshok.net)
                        </h3>

                        <div style={{ marginBottom: '10px' }}>
                            <button onClick={fetchBookUpdateStatus} className="admin-button">
                                Обновить статус
                            </button>
                        </div>

                        <div>
                            <p>Статус паузы: {bookUpdateStatus.isPaused ? 'ПАУЗА' : 'Активен'}</p>
                            <p>
                                Сейчас идёт обновление?:{' '}
                                {bookUpdateStatus.isRunningNow ? 'Да' : 'Нет'}
                            </p>
                            <p>
                                Последний запуск (UTC):{' '}
                                {bookUpdateStatus.lastRunTimeUtc || '-'}
                            </p>
                            <p>
                                Следующий запуск (UTC):{' '}
                                {bookUpdateStatus.nextRunTimeUtc || '-'}
                            </p>

                            <p>
                                Текущая операция:{' '}
                                {bookUpdateStatus.currentOperationName || '-'}
                            </p>
                            <p>
                                Обработано лотов за текущую операцию:{' '}
                                {bookUpdateStatus.processedCount}
                            </p>
                            <p>
                                Последний обработанный лот (ID):{' '}
                                {bookUpdateStatus.lastProcessedLotId}
                            </p>
                        </div>

                        <div style={{ marginTop: '10px' }}>
                            {!bookUpdateStatus.isPaused && (
                                <button onClick={pauseBookUpdate} className="admin-button">
                                    Поставить на паузу
                                </button>
                            )}
                            {bookUpdateStatus.isPaused && (
                                <button onClick={resumeBookUpdate} className="admin-button">
                                    Возобновить
                                </button>
                            )}

                            {!bookUpdateStatus.isRunningNow && (
                                <button
                                    onClick={runBookUpdateNow}
                                    className="admin-button"
                                    style={{ marginLeft: 8 }}
                                >
                                    Запустить обновление сейчас
                                </button>
                            )}
                        </div>

                        <div className="admin-log-container" style={{ marginTop: '20px' }}>
                            <h4>Подробная информация / логи:</h4>
                            <div>
                                {bookUpdateStatus.lastProcessedLotTitle
                                    ? bookUpdateStatus.lastProcessedLotTitle
                                    : 'Пока нет дополнительных сообщений.'}
                            </div>
                        </div>
                    </div>
                )}

                {/* ============ Вкладка "subplans" (новая) ============ */}
                {currentTab === 'subplans' && (
                    <div className="admin-section">
                        <h3 className="admin-section-title">Управление планами подписки</h3>

                        {/* Таблица планов */}
                        {loadingPlans && <p>Загрузка...</p>}
                        {!loadingPlans && (
                            <table className="admin-table responsive-table">
                                <thead>
                                    <tr>
                                        <th>ID</th>
                                        <th>Название</th>
                                        <th>Цена (руб/мес)</th>
                                        <th>Лимит запросов</th>
                                        <th>Активен?</th>
                                        <th>Действия</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {subPlans.map((plan) => (
                                        <tr key={plan.id}>
                                            <td data-label="ID">{plan.id}</td>
                                            <td data-label="Название">{plan.name}</td>
                                            <td data-label="Цена">{plan.price}</td>
                                            <td data-label="Лимит">{plan.monthlyRequestLimit}</td>
                                            <td data-label="Активен?">
                                                {plan.isActive ? 'Да' : 'Нет'}
                                            </td>
                                            <td data-label="Действия">
                                                <button onClick={() => handleEditPlan(plan)}>
                                                    Редактировать
                                                </button>
                                                &nbsp;
                                                <button onClick={() => handleDeletePlan(plan.id)}>
                                                    Удалить
                                                </button>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        )}

                        <hr style={{ margin: '20px 0' }} />

                        {/* Форма создания/редактирования плана */}
                        <h4>{editMode ? 'Редактировать план' : 'Создать новый план'}</h4>
                        <div style={{ margin: '10px 0' }}>
                            <label>
                                Название:{' '}
                                <input
                                    type="text"
                                    value={planForm.name}
                                    onChange={(e) =>
                                        setPlanForm({ ...planForm, name: e.target.value })
                                    }
                                />
                            </label>
                        </div>
                        <div style={{ margin: '10px 0' }}>
                            <label>
                                Цена (руб/мес):{' '}
                                <input
                                    type="number"
                                    step="0.01"
                                    value={planForm.price}
                                    onChange={(e) =>
                                        setPlanForm({
                                            ...planForm,
                                            price: parseFloat(e.target.value || '0')
                                        })
                                    }
                                />
                            </label>
                        </div>
                        <div style={{ margin: '10px 0' }}>
                            <label>
                                Лимит запросов в месяц:{' '}
                                <input
                                    type="number"
                                    value={planForm.monthlyRequestLimit}
                                    onChange={(e) =>
                                        setPlanForm({
                                            ...planForm,
                                            monthlyRequestLimit: parseInt(e.target.value || '0')
                                        })
                                    }
                                />
                            </label>
                        </div>
                        <div style={{ margin: '10px 0' }}>
                            <label>
                                Активен:{' '}
                                <input
                                    type="checkbox"
                                    checked={planForm.isActive}
                                    onChange={(e) =>
                                        setPlanForm({
                                            ...planForm,
                                            isActive: e.target.checked
                                        })
                                    }
                                />
                            </label>
                        </div>

                        <div style={{ marginTop: '15px' }}>
                            <button onClick={handleCreateOrUpdatePlan}>
                                {editMode ? 'Сохранить изменения' : 'Создать'}
                            </button>
                            {editMode && (
                                <button
                                    style={{ marginLeft: 8 }}
                                    onClick={() => {
                                        // Отмена редактирования
                                        setPlanForm({
                                            id: 0,
                                            name: '',
                                            price: 0,
                                            monthlyRequestLimit: 0,
                                            isActive: true
                                        });
                                        setEditMode(false);
                                    }}
                                >
                                    Отмена
                                </button>
                            )}
                        </div>
                    </div>
                )}
                {/* Модалка назначения плана */}
                {showSubModal && (
                    <div className="modal-overlay">
                        <div className="modal">
                            <h3>
                                Изменить подписку пользователя {selectedUserForSub?.email}
                            </h3>

                            <label>План подписки:</label>
                            <select
                                value={selectedPlanForSub}
                                onChange={(e) => setSelectedPlanForSub(e.target.value)}
                            >
                                <option value={0}> -- Отключить подписку -- </option>
                                {subPlans.map(plan => (
                                    <option key={plan.id} value={plan.id}>
                                        {plan.name} (лимит {plan.monthlyRequestLimit})
                                    </option>
                                ))}
                            </select>

                            <div style={{ marginTop: 8 }}>
                                <label>
                                    <input
                                        type="checkbox"
                                        checked={autoRenewForSub}
                                        onChange={(e) => setAutoRenewForSub(e.target.checked)}
                                    />
                                    Автопродление
                                </label>
                            </div>

                            <div style={{ marginTop: 16 }}>
                                <button onClick={handleAssignSubscriptionPlan}>
                                    Сохранить
                                </button>
                                <button onClick={() => setShowSubModal(false)} style={{ marginLeft: 8 }}>
                                    Отмена
                                </button>
                            </div>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
};

export default AdminPanel;
