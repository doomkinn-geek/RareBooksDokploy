//src/components/AdminPanel.jsx
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
    // Вкладки: 'users' | 'export' | 'settings' | 'import'
    const [currentTab, setCurrentTab] = useState('users');

    // Состояния пользователей
    const [users, setUsers] = useState([]);
    const [error, setError] = useState('');

    // Экспорт
    const [exportTaskId, setExportTaskId] = useState(null);
    const [progress, setProgress] = useState(null);
    const [isExporting, setIsExporting] = useState(false);
    const [intervalId, setIntervalId] = useState(null);

    // Настройки
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
    // ---- Добавляем блок YandexCloud ----
    const [yandexCloud, setYandexCloud] = useState({
        accessKey: '',
        secretKey: '',
        serviceUrl: '',
        bucketName: ''
    });

    const [bookUpdateStatus, setBookUpdateStatus] = useState({
        isPaused: false,
        isRunningNow: false,
        lastRunTimeUtc: null,
        nextRunTimeUtc: null
    });


    // Импорт SQLite
    const [importTaskId, setImportTaskId] = useState(null);
    const [importFile, setImportFile] = useState(null);
    const [importUploadProgress, setImportUploadProgress] = useState(0);
    const [importProgress, setImportProgress] = useState(0);
    const [importMessage, setImportMessage] = useState('');
    const [isImporting, setIsImporting] = useState(false);
    const [importPollIntervalId, setImportPollIntervalId] = useState(null);

    const history = useNavigate();

    // ------------------- Загрузка пользователей -------------------
    useEffect(() => {
        const fetchUsers = async () => {
            try {
                const response = await getUsers();
                setUsers(response.data);
            } catch (error) {
                console.error('Error fetching users:', error);
            }
        };
        fetchUsers();
    }, []);

    // ------------------- Загрузка настроек -------------------
    const fetchSettings = async () => {
        try {
            const data = await getAdminSettings();
            // Пример ответа (часть может быть null):
            // {
            //   "yandexKassa": null,
            //   "yandexDisk": { "Token": "..." },
            //   "typeOfAccessImages": { "UseLocalFiles": "...", "LocalPathOfImages": "..." },
            //   "yandexCloud": { ... }
            // }

            // Если yandexKassa = null, подставляем пустые строки
            setYandexKassa({
                shopId: data.yandexKassa?.ShopId ?? '',
                secretKey: data.yandexKassa?.SecretKey ?? '',
                returnUrl: data.yandexKassa?.ReturnUrl ?? '',
                webhookUrl: data.yandexKassa?.WebhookUrl ?? ''
            });

            // Аналогично для остальных
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

        } catch (error) {
            console.error('Error fetching admin settings:', error);
        }
    };
    useEffect(() => {
        fetchSettings();
    }, []);

    // ------------------- Методы работы с пользователями -------------------
    const handleUpdateUserSubscription = async (userId, hasSubscription) => {
        if (isExporting || isImporting) return;
        try {
            await updateUserSubscription(userId, hasSubscription);
            setUsers(users.map(user => user.id === userId ? { ...user, hasSubscription } : user));
        } catch (error) {
            console.error('Error updating subscription:', error);
        }
    };

    const handleUpdateUserRole = async (userId, role) => {
        if (isExporting || isImporting) return;
        try {
            await updateUserRole(userId, role);
            setUsers(users.map(user => user.id === userId ? { ...user, role } : user));
        } catch (error) {
            console.error('Error updating role:', error);
        }
    };

    const handleViewDetails = async (userId) => {
        if (isExporting || isImporting) return;
        try {
            await getUserById(userId);
            history(`/user/${userId}`);
        } catch (error) {
            console.error('Error fetching user details:', error);
        }
    };

    // ------------------- Экспорт -------------------
    const startExport = async () => {
        if (isExporting || isImporting) return;
        try {
            setError('');
            setProgress(null);
            setIsExporting(true);

            const token = Cookies.get('token');
            const response = await axios.post(`${API_URL}/admin/export-data`, {}, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setExportTaskId(response.data.taskId);

            const id = setInterval(async () => {
                try {
                    const progressRes = await axios.get(
                        `${API_URL}/admin/export-progress/${response.data.taskId}`,
                        { headers: { Authorization: `Bearer ${token}` } }
                    );
                    setProgress(progressRes.data.progress);

                    if (progressRes.data.progress >= 100 || progressRes.data.progress === -1) {
                        clearInterval(id);
                        setIntervalId(null);
                        setIsExporting(false);
                    }
                } catch (e) {
                    console.error(e);
                    setError('Ошибка при получении прогресса экспорта.');
                    clearInterval(id);
                    setIntervalId(null);
                    setIsExporting(false);
                }
            }, 500);
            setIntervalId(id);

        } catch (e) {
            console.error(e);
            setError('Ошибка при запуске экспорта.');
            setIsExporting(false);
        }
    };

    const cancelExport = async () => {
        if (!exportTaskId) return;
        const token = Cookies.get('token');
        try {
            await axios.post(`${API_URL}/admin/cancel-export/${exportTaskId}`, {}, {
                headers: { Authorization: `Bearer ${token}` }
            });
        } catch (e) {
            console.error(e);
            setError('Ошибка при отмене экспорта.');
        }
    };

    const downloadExportedFile = async () => {
        if (!exportTaskId) return;
        const token = Cookies.get('token');
        try {
            const response = await fetch(`${API_URL}/admin/download-exported-file/${exportTaskId}`, {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            if (!response.ok) throw new Error('Не удалось скачать файл');

            const blob = await response.blob();
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `export_${exportTaskId}.db`;
            document.body.appendChild(a);
            a.click();
            a.remove();
            URL.revokeObjectURL(url);
        } catch (error) {
            console.error('Error downloading file:', error);
            setError('Ошибка при скачивании файла.');
        }
    };

    // ------------------- Сохранение настроек -------------------
    const handleSaveSettings = async () => {
        try {
            // Всегда передаём все поля, даже если они пустые
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
                }
            };
            await updateAdminSettings(settingsDto);
            alert('Настройки сохранены успешно');
        } catch (err) {
            console.error('Error saving settings:', err);
            alert('Ошибка при сохранении настроек.');
        }
    };


    // ------------------- Импорт SQLite -------------------
    const initImportTask = async (fileSize) => {
        const res = await initImport(fileSize);
        setImportTaskId(res.importTaskId); // обновляем стейт
        return res.importTaskId; // возвращаем, чтобы сразу использовать
    };

    const uploadFileChunks = async (file, taskId) => {
        const chunkSize = 1024 * 256; // 256 KB
        let offset = 0;
        while (offset < file.size) {
            const slice = file.slice(offset, offset + chunkSize);
            await uploadImportChunk(taskId, slice, (progressEvent) => {
                const percent = Math.round((progressEvent.loaded * 100) / progressEvent.total);
                // ... можно логировать
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
        } catch (e) {
            console.error('Poll error:', e);
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
            // init
            const newTaskId = await initImportTask(importFile.size);

            // upload
            await uploadFileChunks(importFile, newTaskId);

            // finish
            await finishUpload(newTaskId);

            // poll
            const pid = setInterval(() => {
                pollImportProgress(newTaskId);
            }, 500);
            setImportPollIntervalId(pid);

        } catch (e) {
            console.error('Import error:', e);
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
            alert("Импорт отменён");
            setIsImporting(false);
            if (importPollIntervalId) {
                clearInterval(importPollIntervalId);
                setImportPollIntervalId(null);
            }
        } catch (e) {
            console.error(e);
            alert("Ошибка отмены импорта");
        }
    };

    // ------------------- Контроль сервиса обновления данных -----------------
    const fetchBookUpdateStatus = async () => {
        const token = Cookies.get('token');
        const response = await axios.get(`${API_URL}/bookupdateservice/status`, {
            headers: { Authorization: `Bearer ${token}` }
        });
        setBookUpdateStatus(response.data);
    };

    const pauseBookUpdate = async () => {
        const token = Cookies.get('token');
        await axios.post(`${API_URL}/bookupdateservice/pause`, {}, {
            headers: { Authorization: `Bearer ${token}` }
        });
        await fetchBookUpdateStatus(); // обновим статус
    };

    const resumeBookUpdate = async () => {
        const token = Cookies.get('token');
        await axios.post(`${API_URL}/bookupdateservice/resume`, {}, {
            headers: { Authorization: `Bearer ${token}` }
        });
        await fetchBookUpdateStatus();
    };
    useEffect(() => {
        if (currentTab === 'bookupdate') {
            fetchBookUpdateStatus();
        }
    }, [currentTab]);


    // ------------------- Рендер -------------------
    // Кнопки для вкладок
    /*const renderTabButtons = (
        <div className="admin-tabs">
            <button
                className={`admin-tab-button ${currentTab === 'users' ? 'active' : ''}`}
                onClick={() => setCurrentTab('users')}>
                Пользователи
            </button>
            <button
                className={`admin-tab-button ${currentTab === 'export' ? 'active' : ''}`}
                onClick={() => setCurrentTab('export')}>
                Экспорт данных
            </button>
            <button
                className={`admin-tab-button ${currentTab === 'settings' ? 'active' : ''}`}
                onClick={() => setCurrentTab('settings')}>
                Настройки
            </button>
            <button
                className={`admin-tab-button ${currentTab === 'import' ? 'active' : ''}`}
                onClick={() => setCurrentTab('import')}>
                Импорт данных
            </button>
            <button
                className={`admin-tab-button ${currentTab === 'bookupdate' ? 'active' : ''}`}
                onClick={() => setCurrentTab('bookupdate')}>
                Обновление книг
            </button>
        </div>
    );*/

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
            </select>
        </div>
    );

    return (
        <div className="admin-panel-container">
            <h2 className="admin-title">Панель администратора</h2>
            {error && <div className="admin-error">{error}</div>}

            {/* Рендерим кнопки вкладок */}
            {renderTabButtons}

            {/* Контейнер для вкладок */}
            <div className="admin-tab-content">

                {/* Вкладка "users" */}
                {currentTab === 'users' && (
                    <div className="admin-section">
                        <h3 className="admin-section-title">Управление пользователями</h3>
                        <table className="admin-table">
                            <thead>
                                <tr>
                                    <th>E-mail</th>
                                    <th>Роль</th>
                                    <th>Подписка</th>
                                    <th>Действия</th>
                                </tr>
                            </thead>
                            <tbody>
                                {users.map(user => (
                                    <tr key={user.id}>
                                        <td>{user.email}</td>
                                        <td>{user.role}</td>
                                        <td>{user.hasSubscription ? 'Да' : 'Нет'}</td>
                                        <td>
                                            <button
                                                onClick={() => handleUpdateUserSubscription(user.id, !user.hasSubscription)}
                                                disabled={isExporting || isImporting}
                                                className={`admin-button ${isExporting || isImporting ? 'admin-button-disabled' : ''}`}
                                            >
                                                {user.hasSubscription ? 'Отменить подписку' : 'Подключить подписку'}
                                            </button>
                                            <button
                                                onClick={() => handleUpdateUserRole(user.id, user.role === 'Admin' ? 'User' : 'Admin')}
                                                disabled={isExporting || isImporting}
                                                className={`admin-button ${isExporting || isImporting ? 'admin-button-disabled' : ''}`}
                                            >
                                                {user.role === 'Admin' ? 'Разжаловать в User' : 'Предоставить Admin'}
                                            </button>
                                            <button
                                                onClick={() => handleViewDetails(user.id)}
                                                disabled={isExporting || isImporting}
                                                className={`admin-button ${isExporting || isImporting ? 'admin-button-disabled' : ''}`}
                                            >
                                                Просмотр
                                            </button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}

                {/* Вкладка "export" */}
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
                                <button
                                    onClick={cancelExport}
                                    className="admin-button"
                                >
                                    Отменить экспорт
                                </button>
                            )}
                        </div>

                        {exportTaskId && progress !== null && (
                            <div className="admin-export-status">
                                {progress === -1 && (
                                    <div className="admin-error">
                                        Экспорт отменен или произошла ошибка.
                                    </div>
                                )}
                                {progress >= 0 && progress < 100 && progress !== -1 && (
                                    <div>Прогресс экспорта: {progress}%</div>
                                )}
                                {progress >= 100 && (
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

                {/* 3) Вкладка 'settings' */}
                {currentTab === 'settings' && (
                    <div className="admin-section">
                        <h3>Редактирование настроек (appsettings.json)</h3>

                        {/* YandexKassa */}
                        <div style={{ backgroundColor: '#f9f9f9', padding: 10, marginBottom: 10 }}>
                            <h4>YandexKassa</h4>
                            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                                <div>
                                    <label>ShopId:</label><br />
                                    <input
                                        type="text"
                                        value={yandexKassa.shopId}
                                        onChange={(e) => setYandexKassa({ ...yandexKassa, shopId: e.target.value })}
                                    />
                                </div>
                                <div>
                                    <label>SecretKey:</label><br />
                                    <input
                                        type="text"
                                        value={yandexKassa.secretKey}
                                        onChange={(e) => setYandexKassa({ ...yandexKassa, secretKey: e.target.value })}
                                    />
                                </div>
                                <div>
                                    <label>ReturnUrl:</label><br />
                                    <input
                                        type="text"
                                        value={yandexKassa.returnUrl}
                                        onChange={(e) => setYandexKassa({ ...yandexKassa, returnUrl: e.target.value })}
                                    />
                                </div>
                                <div>
                                    <label>WebhookUrl:</label><br />
                                    <input
                                        type="text"
                                        value={yandexKassa.webhookUrl}
                                        onChange={(e) => setYandexKassa({ ...yandexKassa, webhookUrl: e.target.value })}
                                    />
                                </div>
                            </div>
                        </div>

                        {/* YandexDisk */}
                        <div style={{ backgroundColor: '#f9f9f9', padding: 10, marginBottom: 10 }}>
                            <h4>YandexDisk</h4>
                            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                                <div>
                                    <label>Token:</label><br />
                                    <input
                                        type="text"
                                        value={yandexDisk.token}
                                        onChange={(e) => setYandexDisk({ ...yandexDisk, token: e.target.value })}
                                    />
                                </div>
                            </div>
                        </div>

                        {/* TypeOfAccessImages */}
                        <div style={{ backgroundColor: '#f9f9f9', padding: 10, marginBottom: 10 }}>
                            <h4>TypeOfAccessImages</h4>
                            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                                <div>
                                    <label>UseLocalFiles:</label><br />
                                    <select
                                        value={typeOfAccessImages.useLocalFiles}
                                        onChange={(e) => setTypeOfAccessImages({ ...typeOfAccessImages, useLocalFiles: e.target.value })}
                                    >
                                        <option value="false">false</option>
                                        <option value="true">true</option>
                                    </select>
                                </div>
                                <div>
                                    <label>LocalPathOfImages:</label><br />
                                    <input
                                        type="text"
                                        value={typeOfAccessImages.localPathOfImages}
                                        onChange={(e) => setTypeOfAccessImages({ ...typeOfAccessImages, localPathOfImages: e.target.value })}
                                    />
                                </div>
                            </div>
                        </div>

                        {/* YandexCloud */}
                        <div style={{ backgroundColor: '#f9f9f9', padding: 10, marginBottom: 10 }}>
                            <h4>YandexCloud</h4>
                            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                                <div>
                                    <label>AccessKey:</label><br />
                                    <input
                                        type="text"
                                        value={yandexCloud.accessKey}
                                        onChange={(e) => setYandexCloud({ ...yandexCloud, accessKey: e.target.value })}
                                    />
                                </div>
                                <div>
                                    <label>SecretKey:</label><br />
                                    <input
                                        type="text"
                                        value={yandexCloud.secretKey}
                                        onChange={(e) => setYandexCloud({ ...yandexCloud, secretKey: e.target.value })}
                                    />
                                </div>
                                <div>
                                    <label>ServiceUrl:</label><br />
                                    <input
                                        type="text"
                                        value={yandexCloud.serviceUrl}
                                        onChange={(e) => setYandexCloud({ ...yandexCloud, serviceUrl: e.target.value })}
                                    />
                                </div>
                                <div>
                                    <label>BucketName:</label><br />
                                    <input
                                        type="text"
                                        value={yandexCloud.bucketName}
                                        onChange={(e) => setYandexCloud({ ...yandexCloud, bucketName: e.target.value })}
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

                {/* Вкладка "import" */}
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
                                accept=".db"
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

                        {/* Прогресс ЗАГРУЗКИ файла */}
                        {importUploadProgress > 0 && importUploadProgress < 100 && (
                            <div style={{ marginTop: '10px' }}>
                                Загрузка файла: {importUploadProgress}%
                            </div>
                        )}
                        {importUploadProgress === 100 && <div>Файл загружен, идёт импорт...</div>}

                        {/* Прогресс ИМПОРТА */}
                        {importProgress > 0 && importProgress < 100 && (
                            <div>Импорт: {importProgress}%</div>
                        )}
                        {importProgress === 100 && <div>Импорт завершён!</div>}

                        {importMessage && <div style={{ marginTop: '10px' }}>{importMessage}</div>}
                    </div>
                )}
                {/* Добавим блок рендера вкладки */}
                {currentTab === 'bookupdate' && (
                    <div className="admin-section">
                        <h3 className="admin-section-title">Сервис обновления книг (meshok.net)</h3>

                        <div style={{ marginBottom: '10px' }}>
                            <button onClick={fetchBookUpdateStatus} className="admin-button">
                                Обновить статус
                            </button>
                        </div>

                        <div>
                            <p>Статус паузы: {bookUpdateStatus.isPaused ? 'ПАУЗА' : 'Активен'}</p>
                            <p>Сейчас идёт обновление?: {bookUpdateStatus.isRunningNow ? 'Да, в процессе' : 'Нет'}</p>
                            <p>Последний запуск (UTC): {bookUpdateStatus.lastRunTimeUtc || '-'}</p>
                            <p>Следующий запуск (UTC): {bookUpdateStatus.nextRunTimeUtc || '-'}</p>
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
                        </div>
                    </div>
                )}

            </div>
        </div>
    );
};

export default AdminPanel;
