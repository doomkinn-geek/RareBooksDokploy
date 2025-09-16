import React, { useState, useEffect } from 'react';
import {
    Box, Typography, TextField, Grid, Switch, Card, CardContent, 
    Button, FormControlLabel
} from '@mui/material';
import axios from 'axios';
import { API_URL, getAdminSettings, updateAdminSettings } from '../../api';

const SettingsPanel = () => {
    const [error, setError] = useState('');
    
    // ----- Настройки
    const [yandexKassa, setYandexKassa] = useState({
        shopId: '',
        secretKey: '',
        returnUrl: '',
        webhookUrl: ''
    });
    
    const [yandexDisk, setYandexDisk] = useState({ 
        token: '' 
    });
    
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

    const [telegramBot, setTelegramBot] = useState({
        token: ''
    });

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
                setTelegramBot({
                    token: data.telegramBot?.Token ?? ''
                });
            } catch (err) {
                console.error('Error fetching admin settings:', err);
                setError('Ошибка при загрузке настроек');
            }
        };
        fetchSettings();
    }, []);

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
                },
                telegramBot: {
                    Token: telegramBot.token
                }
            };

            await updateAdminSettings(settings);
            setError('');
        } catch (err) {
            console.error('Error updating settings:', err);
            setError('Ошибка при сохранении настроек');
        }
    };

    return (
        <Box>
            <Typography variant="h5" component="h2" gutterBottom sx={{ fontWeight: 'bold', color: '#2c3e50', mb: 3 }}>
                Редактирование настроек (appsettings.json)
            </Typography>

            {error && (
                <Typography color="error" sx={{ mb: 2 }}>
                    {error}
                </Typography>
            )}

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

            {/* Настройки Telegram бота */}
            <Card sx={{ mb: 2 }}>
                <CardContent>
                    <Typography variant="h5" gutterBottom sx={{ color: 'primary.main', mb: 2 }}>
                        Telegram Bot
                    </Typography>
                    <Grid container spacing={2}>
                        <Grid item xs={12}>
                            <TextField
                                fullWidth
                                label="Токен бота"
                                variant="outlined"
                                size="small"
                                value={telegramBot.token}
                                onChange={(e) =>
                                    setTelegramBot({
                                        ...telegramBot,
                                        token: e.target.value
                                    })
                                }
                                helperText="Токен получен от @BotFather в Telegram"
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
    );
};

export default SettingsPanel; 