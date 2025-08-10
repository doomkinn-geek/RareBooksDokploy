import React, { useState, useEffect, useContext, useRef } from 'react';
import {
    Box,
    Typography,
    Button,
    Card,
    CardContent,
    CardActions,
    Grid,
    Container,
    Paper,
    Divider,
    Chip,
    CircularProgress,
    List,
    ListItem,
    ListItemIcon,
    ListItemText,
    Alert,
    Snackbar,
    AlertTitle
} from '@mui/material';
import { useNavigate } from 'react-router-dom';
import { UserContext } from '../context/UserContext';
import { getSubscriptionPlans, subscribeUser, cancelSubscription, checkSubscriptionStatus } from '../api';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';

// Временное решение: заменяем импорты иконок на простые строки
const CheckIcon = () => "✓";
const CloseIcon = () => "✕";
const StarIcon = () => "★";
const StarBorderIcon = () => "☆";
const VerifiedUserIcon = () => "✓";
const PriceChangeIcon = () => "₽";
const HistoryIcon = () => "⏱";
const AnalyticsIcon = () => "📊";
const ImageSearchIcon = () => "🔍";

// Заменяем переменные CSS с цветами на константы
const COLORS = {
    primary: '#d32f2f',
    primaryLight: 'rgba(211, 47, 47, 0.1)',
    primaryDark: '#a82222',
    textPrimary: '#333',
    textSecondary: '#555',
    textLight: '#888',
    background: '#ffffff',
    backgroundLight: '#fafafa',
    backgroundMedium: '#f5f5f5',
};

const SubscriptionPage = () => {
    const { user, refreshUser, setUser } = useContext(UserContext);
    const navigate = useNavigate();
    
    const [plans, setPlans] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [subscribing, setSubscribing] = useState(false);
    const [cancelling, setCancelling] = useState(false);
    const [snackbarOpen, setSnackbarOpen] = useState(false);
    const [snackbarMessage, setSnackbarMessage] = useState('');
    const [snackbarSeverity, setSnackbarSeverity] = useState('info');
    const [statusCheckComplete, setStatusCheckComplete] = useState(false);
    const [isCheckingStatus, setIsCheckingStatus] = useState(false);
    const initialLoadRef = useRef(true);

    // Выносим функцию проверки статуса на уровень компонента для возможности вызова по кнопке
    const checkStatus = async () => {
        // Если уже выполняется проверка, не запускаем еще одну
        if (isCheckingStatus) return;
        
        try {
            setIsCheckingStatus(true);
            setLoading(true); // Показываем загрузку
            
            const response = await checkSubscriptionStatus();
            console.log('Результат проверки статуса подписки:', response.data);
            
            // Обновляем данные пользователя
            await refreshUser(true);
            
            // Если активная подписка есть на сервере, но не в объекте пользователя - исправляем это
            if (response.data.activeSubscription && user) {
                // Определяем, нужно ли обновлять данные пользователя
                const needsUpdate = !user.subscription || 
                                   user.hasSubscription !== true ||
                                   response.data.activeSubscription.id !== user.subscription.id;
                
                if (needsUpdate) {
                    // Создаем обновленный объект пользователя с данными подписки
                    const updatedUser = {
                        ...user,
                        subscription: response.data.activeSubscription,
                        hasSubscription: true
                    };
                    
                    // Обновляем состояние пользователя вручную
                    console.log('Обновляем данные пользователя вручную:', updatedUser);
                    setUser(updatedUser);
                    
                    showSnackbar('Данные о подписке обновлены', 'success');
                }
            }
            
            // Если сервер вернул исправленный флаг, показываем уведомление
            if (response.data.flagCorrected) {
                showSnackbar(
                    'Информация о статусе подписки была обновлена', 
                    'info'
                );
            }
            
            // Логируем диагностическую информацию в консоль после обновления
            logSubscriptionDiagnosticInfo();
            
        } catch (err) {
            console.error('Ошибка при проверке статуса подписки:', err);
            setError('Не удалось проверить статус подписки. Пожалуйста, попробуйте позже.');
        } finally {
            setStatusCheckComplete(true);
            setLoading(false); // Скрываем загрузку после проверки
            setIsCheckingStatus(false); // Сбрасываем флаг проверки
        }
    };

    useEffect(() => {
        // Функция загрузки планов подписки
        const fetchPlans = async () => {
            try {
                setLoading(true);
                const response = await getSubscriptionPlans();
                
                // Проверяем, что полученные данные являются массивом
                if (response && response.data) {
                    console.log('Получены данные о планах:', response.data);
                    
                    // Если response.data это массив, используем его,
                    // если это объект с полем plans, которое является массивом, используем его,
                    // иначе - используем пустой массив
                    let plansData;
                    if (Array.isArray(response.data)) {
                        plansData = response.data;
                    } else if (response.data.plans && Array.isArray(response.data.plans)) {
                        plansData = response.data.plans;
                    } else {
                        console.warn('Данные о планах не являются массивом:', response.data);
                        plansData = [];
                    }
                    
                    setPlans(plansData);
                    
                    // Проверяем статус подписки при первой загрузке или если у пользователя должна быть активная подписка, но она не определена
                    if (user && (initialLoadRef.current || (user.hasSubscription === true && !user.subscription))) {
                        initialLoadRef.current = false; // Отмечаем, что первая загрузка выполнена
                        await checkStatus();
                    }
                } else {
                    console.warn('Не получены данные о планах подписки:', response);
                    setPlans([]);
                }
            } catch (err) {
                console.error('Error fetching subscription plans:', err);
                setError('Не удалось загрузить планы подписки. Пожалуйста, попробуйте позже.');
            } finally {
                setLoading(false);
            }
        };

        fetchPlans();
    // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [user]);

    // Если подписка активна и есть сохранённый путь возврата — делаем редирект назад
    useEffect(() => {
        try {
            if (user && isSubscriptionActive()) {
                const returnTo = localStorage.getItem('returnTo');
                if (returnTo) {
                    localStorage.removeItem('returnTo');
                    navigate(returnTo, { replace: true });
                }
            }
        } catch (_e) {}
    }, [user, statusCheckComplete]);

    // Сбрасываем флаг initialLoadRef при размонтировании компонента
    useEffect(() => {
        return () => {
            initialLoadRef.current = true;
        };
    }, []);

    const handleSubscribe = async (planId) => {
        if (!user) {
            navigate('/login', { state: { from: '/subscription' } });
            return;
        }

        try {
            setSubscribing(true);
            // Вызов subscribeUser теперь может перенаправить пользователя на страницу оплаты
            // при успешном ответе от сервера
            await subscribeUser(planId);
            
            // Эта часть кода может не выполниться, если произошло перенаправление
            // Сбрасываем флаг initialLoad, чтобы при перезагрузке компонента данные обновились
            initialLoadRef.current = true;
            
            await refreshUser(true);
            showSnackbar('Переход к оплате подписки...', 'success');
            
            // Вызываем логирование после обновления данных пользователя
            logSubscriptionDiagnosticInfo();
        } catch (err) {
            console.error('Ошибка при оформлении подписки:', err);
            const errorMessage = err.response?.data?.message || 
                                err.message || 
                                'Не удалось оформить подписку. Пожалуйста, попробуйте позже.';
            showSnackbar(errorMessage, 'error');
        } finally {
            setSubscribing(false);
        }
    };

    const handleCancelSubscription = async () => {
        if (!window.confirm('Вы уверены, что хотите отменить подписку?')) return;

        try {
            setCancelling(true);
            await cancelSubscription();
            
            // Сбрасываем флаг initialLoad, чтобы при перезагрузке компонента данные обновились
            initialLoadRef.current = true;
            
            await refreshUser(true);
            showSnackbar('Подписка успешно отменена', 'success');
            
            // Вызываем логирование после обновления данных пользователя
            logSubscriptionDiagnosticInfo();
        } catch (err) {
            console.error('Ошибка при отмене подписки:', err);
            showSnackbar('Не удалось отменить подписку. Пожалуйста, попробуйте позже.', 'error');
        } finally {
            setCancelling(false);
        }
    };

    const showSnackbar = (message, severity = 'info') => {
        setSnackbarMessage(message);
        setSnackbarSeverity(severity);
        setSnackbarOpen(true);
    };

    // Функция для логирования диагностической информации в консоль
    const logSubscriptionDiagnosticInfo = () => {
        // Не логируем в production режиме
        if (process.env.NODE_ENV === 'production') return;
        
        if (!user) {
            console.log('Диагностика подписки: пользователь не авторизован');
            return;
        }
        
        console.log('===== ДИАГНОСТИКА ПОДПИСКИ =====');
        console.log('Данные пользователя:', user);
        
        if (user.subscription) {
            console.log('Информация о подписке:');
            console.log('ID плана:', user.subscription.subscriptionPlanId);
            console.log('Название плана:', user.subscription.planName);
            console.log('Начало подписки:', new Date(user.subscription.startDate).toLocaleString());
            console.log('Окончание подписки:', new Date(user.subscription.endDate).toLocaleString());
            console.log('Статус:', user.subscription.status);
            console.log('Активна:', user.subscription.isActive ? 'Да' : 'Нет');
            console.log('Осталось дней:', getDaysRemaining(user.subscription.endDate));
            console.log('Подписка действительна:', isSubscriptionActive() ? 'Да' : 'Нет');
            
            if (!isSubscriptionActive()) {
                console.log('Причина неактивности:', getSubscriptionDisplayReason());
            }
        } else {
            console.log('У пользователя нет активной подписки');
        }
        
        console.log('================================');
    };

    const formatDate = (dateString) => {
        if (!dateString) return 'Н/Д';
        
        const date = new Date(dateString);
        return new Intl.DateTimeFormat('ru-RU', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric'
        }).format(date);
    };

    const isSubscriptionActive = () => {
        if (!user || !user.subscription) {
            // Упрощаем логирование
            if (process.env.NODE_ENV !== 'production') {
                console.log('Нет пользователя или подписки');
            }
            return false;
        }
        
        const { subscription } = user;
        const now = new Date();
        const endDate = new Date(subscription.endDate);
        const startDate = new Date(subscription.startDate);
        
        // Логируем только в режиме разработки
        if (process.env.NODE_ENV !== 'production') {
            console.log('Проверка активности подписки:', { 
                status: subscription.status, 
                isActive: subscription.isActive, 
                endDate, 
                now,
                hasSubscriptionFlag: user.hasSubscription
            });
        }
        
        // Если у пользователя явно установлен флаг hasSubscription в true, считаем подписку активной
        if (user.hasSubscription === true) {
            if (process.env.NODE_ENV !== 'production') {
                console.log('Подписка активна по флагу hasSubscription');
            }
            return true;
        }
        
        // Проверяем сначала статус
        if (subscription.status && subscription.status !== 'Active') {
            if (process.env.NODE_ENV !== 'production') {
                console.warn('Подписка не активна, статус:', subscription.status);
            }
            return false;
        }
        
        // Проверка isActive только если явно установлен в false
        // Если isActive не определен или равен true, не учитываем этот флаг
        if (subscription.isActive === false) {
            if (process.env.NODE_ENV !== 'production') {
                console.warn('Подписка явно помечена как неактивная (isActive: false)');
            }
            return false;
        }
        
        // Наконец, проверяем сроки действия
        const isValid = endDate > now && startDate <= now;
        
        if (!isValid) {
            if (process.env.NODE_ENV !== 'production') {
                console.warn('Подписка истекла:', endDate.toLocaleString(), '<', now.toLocaleString());
            }
        } else {
            if (process.env.NODE_ENV !== 'production') {
                console.log('Подписка действительна до:', endDate.toLocaleString());
            }
        }
        
        return isValid;
    };

    const renderCurrentSubscription = () => {
        const subscriptionActive = isSubscriptionActive();
        const displayReason = getSubscriptionDisplayReason();
        
        if (!user || !user.subscription) {
            return (
                <Paper elevation={3} sx={{ p: 3, mb: 4, borderRadius: '12px', bgcolor: 'white', border: `1px solid ${COLORS.primary}` }}>
                    <Typography variant="h6" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                        У вас нет активной подписки
                    </Typography>
                    <Typography variant="body1" paragraph color={COLORS.textSecondary}>
                        Оформите подписку, чтобы получить доступ к полному функционалу сервиса оценки антикварных книг.
                    </Typography>
                    <Typography variant="body2" color={COLORS.textLight}>
                        Выберите подходящий план подписки ниже.
                    </Typography>
                    <Button 
                        variant="outlined" 
                        sx={{ 
                            mt: 2, 
                            borderRadius: '8px', 
                            textTransform: 'none', 
                            borderColor: COLORS.primary, 
                            color: COLORS.primary,
                            '&:hover': {
                                borderColor: COLORS.primaryDark,
                                backgroundColor: COLORS.primaryLight,
                            }
                        }}
                        onClick={checkStatus}
                        disabled={isCheckingStatus}
                    >
                        {isCheckingStatus ? <CircularProgress size={24} sx={{ color: COLORS.primary }} /> : 'Проверить статус подписки'}
                    </Button>
                </Paper>
            );
        }

        const { subscription } = user;

        // Сортируем планы по возрастанию цены
        const sortedPlans = (Array.isArray(plans) ? [...plans] : []).sort((a, b) => {
            const pa = Number(a?.price ?? Number.POSITIVE_INFINITY);
            const pb = Number(b?.price ?? Number.POSITIVE_INFINITY);
            if (Number.isNaN(pa) && Number.isNaN(pb)) return 0;
            if (Number.isNaN(pa)) return 1;
            if (Number.isNaN(pb)) return -1;
            return pa - pb;
        });

        return (
            <Paper 
                elevation={3} 
                sx={{ 
                    p: 3, 
                    mb: 4, 
                    borderRadius: '12px',
                    bgcolor: 'white',
                    border: `1px solid ${subscriptionActive ? COLORS.primary : '#999'}`
                }}
            >
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                    <VerifiedUserIcon 
                        sx={{ mr: 1, fontSize: 28, color: subscriptionActive ? COLORS.primary : COLORS.textLight }} 
                    />
                    <Typography variant="h5" fontWeight="bold" color={COLORS.textPrimary}>
                        Ваша текущая подписка
                    </Typography>
                </Box>
                
                <Grid container spacing={3}>
                    <Grid item xs={12} md={8}>
                        <Box sx={{ mb: 2 }}>
                            <Typography variant="subtitle1" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                                План:
                            </Typography>
                            <Typography variant="h6" color={COLORS.textSecondary}>
                                {subscription.planName || 'Стандартный план'}
                            </Typography>
                        </Box>
                        
                        <Box sx={{ mb: 2 }}>
                            <Typography variant="subtitle1" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                                Статус:
                            </Typography>
                            <Box sx={{ display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 1 }}>
                                <Chip 
                                    label={subscriptionActive ? 'Активна' : 'Неактивна'} 
                                    sx={{ 
                                        color: 'white', 
                                        bgcolor: subscriptionActive ? COLORS.primary : COLORS.textLight,
                                        borderColor: subscriptionActive ? COLORS.primary : COLORS.textLight,
                                    }} 
                                />
                                {!subscriptionActive && (
                                    <Typography variant="caption" color={COLORS.primary}>
                                        {displayReason}
                                    </Typography>
                                )}
                                <Button
                                    size="small"
                                    variant="text"
                                    sx={{ 
                                        ml: 1, 
                                        minWidth: 'auto', 
                                        textTransform: 'none',
                                        color: COLORS.primary,
                                        '&:hover': {
                                            backgroundColor: COLORS.primaryLight,
                                        }
                                    }}
                                    onClick={checkStatus}
                                    disabled={isCheckingStatus}
                                >
                                    {isCheckingStatus ? <CircularProgress size={16} sx={{ color: COLORS.primary }} /> : 'Обновить статус'}
                                </Button>
                            </Box>
                        </Box>
                        
                        <Box sx={{ mb: 2 }}>
                            <Typography variant="subtitle1" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                                Период:
                            </Typography>
                            <Typography variant="body1">
                                {formatDate(subscription.startDate)} — {formatDate(subscription.endDate)}
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                                {new Date(subscription.endDate) < new Date() ? 
                                    'Срок действия истек' : 
                                    `Осталось: ${getDaysRemaining(subscription.endDate)} дней`
                                }
                            </Typography>
                        </Box>
                    </Grid>
                    
                    <Grid item xs={12} md={4}>
                        <Box 
                            sx={{ 
                                height: '100%', 
                                display: 'flex', 
                                flexDirection: 'column', 
                                justifyContent: 'center',
                                alignItems: 'center',
                                p: 2,
                                bgcolor: 'rgba(0, 0, 0, 0.02)',
                                borderRadius: '8px'
                            }}
                        >
                            {subscriptionActive ? (
                                <>
                                    <Typography variant="body1" align="center" gutterBottom>
                                        Ваша подписка активна до {formatDate(subscription.endDate)}
                                    </Typography>
                                    <Button 
                                        variant="outlined" 
                                        color="error" 
                                        onClick={handleCancelSubscription}
                                        disabled={cancelling}
                                        sx={{ mt: 1, borderRadius: '8px', textTransform: 'none' }}
                                    >
                                        {cancelling ? <CircularProgress size={24} /> : 'Отменить подписку'}
                                    </Button>
                                </>
                            ) : (
                                <>
                                    <Typography variant="body1" align="center" gutterBottom>
                                        Ваша подписка неактивна
                                    </Typography>
                                    <Button 
                                        variant="contained" 
                                        color="primary" 
                                        onClick={() => window.scrollTo({ top: document.getElementById('subscription-plans').offsetTop, behavior: 'smooth' })}
                                        sx={{ mt: 1, borderRadius: '8px', textTransform: 'none' }}
                                    >
                                        Выбрать новый план
                                    </Button>
                                </>
                            )}
                        </Box>
                    </Grid>
                </Grid>
            </Paper>
        );
    };

    const getSubscriptionDisplayReason = () => {
        if (!user || !user.subscription) return "Подписка отсутствует";
        
        // Если у пользователя явно установлен флаг hasSubscription в true, считаем подписку активной
        if (user.hasSubscription === true) {
            return ""; // Подписка активна, причина не требуется
        }
        
        const { subscription } = user;
        const now = new Date();
        const endDate = new Date(subscription.endDate);
        const startDate = new Date(subscription.startDate);
        
        const reasons = [];
        
        if (subscription.status !== 'Active') {
            reasons.push(`Статус подписки не активен (${subscription.status || 'не указан'})`);
        }
        
        if (subscription.isActive === false) {
            reasons.push("Подписка помечена как неактивная в системе");
        }
        
        if (endDate <= now) {
            reasons.push(`Срок действия подписки истек (${endDate.toLocaleString()})`);
        }
        
        if (startDate > now) {
            reasons.push(`Подписка еще не началась (${startDate.toLocaleString()})`);
        }
        
        if (reasons.length === 0 && !isSubscriptionActive()) {
            reasons.push("Неизвестная причина неактивности подписки");
        }
        
        return reasons.join("; ");
    };
    
    const getDaysRemaining = (endDateStr) => {
        const endDate = new Date(endDateStr);
        const now = new Date();
        
        const diffTime = endDate.getTime() - now.getTime();
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        
        return diffDays > 0 ? diffDays : 0;
    };

    const renderFeatureList = (features) => {
        return (
            <List disablePadding>
                {features.map((feature, index) => (
                    <ListItem 
                        key={index} 
                        disablePadding 
                        sx={{ py: 0.5 }}
                    >
                        <ListItemIcon sx={{ minWidth: 32 }}>
                            <CheckCircleOutlineIcon sx={{ color: COLORS.primary, fontSize: 20 }} />
                        </ListItemIcon>
                        <ListItemText 
                            primary={feature} 
                            primaryTypographyProps={{ 
                                variant: 'body2', 
                                color: COLORS.textSecondary 
                            }} 
                        />
                    </ListItem>
                ))}
            </List>
        );
    };

    const renderPlans = () => {
        if (loading) {
            return (
                <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
                    <CircularProgress sx={{ color: COLORS.primary }} />
                </Box>
            );
        }

        if (!plans || !Array.isArray(plans) || plans.length === 0) {
            if (process.env.NODE_ENV !== 'production') {
                console.warn('[SubscriptionPage] Планы подписки не найдены или имеют неверный формат');
            }

            return (
                <Alert 
                    severity="info" 
                    sx={{ 
                        my: 2, 
                        borderRadius: '8px', 
                        bgcolor: COLORS.primaryLight, 
                        color: COLORS.textPrimary,
                        border: `1px solid ${COLORS.primary}` 
                    }}
                >
                    <AlertTitle>Информация о планах подписки</AlertTitle>
                    В настоящий момент информация о планах подписки недоступна. Пожалуйста, повторите попытку позже.
                </Alert>
            );
        }
        
        // Стандартные функции для каждого плана, если они не указаны в описании
        const defaultPlanFeatures = {
            'Минимальный': [
                'Базовый доступ к оценке книг',
                'Ограниченное количество запросов в месяц',
                'Стандартная точность оценки'
            ],
            'Стандарт': [
                'Все функции минимального плана',
                'Увеличенное количество запросов',
                'Повышенная точность оценки',
                'Доступ к истории оценок'
            ],
            'Премиум': [
                'Все функции стандартного плана',
                'Неограниченное количество запросов',
                'Максимальная точность оценки',
                'Приоритетная поддержка',
                'Доступ к эксклюзивным функциям'
            ]
        };

        // Иконки для каждого плана
        const featureIcons = {
            'Минимальный': <PriceChangeIcon />,
            'Стандарт': <HistoryIcon />,
            'Премиум': <AnalyticsIcon />
        };

        return (
            <>
                {error && (
                    <Alert 
                        severity="error" 
                        sx={{ 
                            my: 2, 
                            borderRadius: '8px', 
                            bgcolor: 'rgba(211, 47, 47, 0.05)', 
                            color: COLORS.primary,
                            border: `1px solid ${COLORS.primary}`
                        }}
                    >
                        <AlertTitle>Ошибка</AlertTitle>
                        {error}
                    </Alert>
                )}
                
                <Grid container spacing={3}>
                    {sortedPlans.map((plan, index) => {
                        // Определяем, является ли этот план текущим для пользователя
                        const isCurrentPlan = user?.subscription?.subscriptionPlanId === plan?.id;
                        
                        // Получаем функции для плана из стандартного набора или используем общие
                        const features = defaultPlanFeatures[plan?.name] || [
                            `Лимит запросов: ${plan?.monthlyRequestLimit || 'не указан'} в месяц`,
                            'Доступ к оценке стоимости книг',
                            'Поиск по базе данных антикварных книг'
                        ];
                        
                        // Получаем иконку для плана или используем стандартную
                        const featureIcon = featureIcons[plan?.name] || <StarIcon />;
                        
                        // Определяем, является ли план премиальным
                        const isPremium = plan?.name.toLowerCase().includes('премиум');
                        
                        return (
                            <Grid item xs={12} sm={6} md={4} key={plan?.id || index}>
                                <Card 
                                    raised={isPremium}
                                    sx={{ 
                                        height: '100%', 
                                        display: 'flex', 
                                        flexDirection: 'column',
                                        position: 'relative',
                                        borderRadius: '12px',
                                        bgcolor: 'white',
                                        transition: 'transform 0.2s, box-shadow 0.2s',
                                        '&:hover': {
                                            transform: 'translateY(-5px)',
                                            boxShadow: '0 12px 28px rgba(0,0,0,0.15)'
                                        },
                                        ...(isPremium && {
                                            border: `2px solid ${COLORS.primary}`,
                                        })
                                    }}
                                >
                                    {isPremium && (
                                        <Chip
                                            label="Рекомендуемый"
                                            sx={{
                                                position: 'absolute',
                                                top: -12,
                                                right: 16,
                                                fontWeight: 'bold',
                                                bgcolor: COLORS.primary,
                                                color: 'white'
                                            }}
                                        />
                                    )}
                                    
                                    <CardContent sx={{ p: 3, flexGrow: 1 }}>
                                        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                            <Box sx={{ color: COLORS.primary }}>
                                                {featureIcon}
                                            </Box>
                                            <Typography variant="h5" component="h2" fontWeight="bold" sx={{ ml: 1 }} color={COLORS.textPrimary}>
                                                {plan?.name}
                                            </Typography>
                                        </Box>
                                        
                                        <Typography variant="h4" fontWeight="bold" sx={{ mb: 2 }} color={COLORS.primary}>
                                            {plan?.price} ₽
                                            <Typography variant="body2" component="span" color={COLORS.textLight} sx={{ ml: 1 }}>
                                                / месяц
                                            </Typography>
                                        </Typography>
                                        
                                        <Typography variant="body2" color={COLORS.textSecondary} paragraph>
                                            {plan?.description || `План "${plan?.name}" для оценки стоимости антикварных книг. Лимит запросов: ${plan?.monthlyRequestLimit || 'не указан'} в месяц.`}
                                        </Typography>
                                        
                                        <Box sx={{ 
                                            display: 'flex', 
                                            alignItems: 'center', 
                                            mb: 2, 
                                            p: 1, 
                                            bgcolor: COLORS.backgroundLight, 
                                            borderRadius: 1 
                                        }}>
                                            <Typography variant="body2" fontWeight="bold" color={COLORS.textSecondary}>
                                                Лимит запросов: <span style={{ color: COLORS.primary }}>{plan?.monthlyRequestLimit || 'не указан'}</span> в месяц
                                            </Typography>
                                        </Box>
                                        
                                        <Divider sx={{ my: 2 }} />
                                        
                                        <Typography variant="subtitle1" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                                            Включено:
                                        </Typography>
                                        
                                        {renderFeatureList(features)}
                                    </CardContent>
                                    
                                    <CardActions sx={{ p: 3, pt: 0 }}>
                                        <Button 
                                            variant={isCurrentPlan ? "outlined" : "contained"} 
                                            fullWidth
                                            disabled={subscribing || (isCurrentPlan && user?.subscription?.isActive)}
                                            onClick={() => handleSubscribe(plan?.id)}
                                            sx={{ 
                                                py: 1.5,
                                                fontWeight: 'bold',
                                                color: isCurrentPlan ? COLORS.primary : 'white',
                                                borderColor: COLORS.primary,
                                                bgcolor: isCurrentPlan ? 'transparent' : COLORS.primary,
                                                '&:hover': {
                                                    bgcolor: isCurrentPlan ? COLORS.primaryLight : COLORS.primaryDark,
                                                    borderColor: COLORS.primaryDark,
                                                    color: isCurrentPlan ? COLORS.primary : 'white',
                                                },
                                                ...(isPremium && !isCurrentPlan && {
                                                    bgcolor: COLORS.primary,
                                                    '&:hover': {
                                                        bgcolor: COLORS.primaryDark,
                                                    }
                                                })
                                            }}
                                        >
                                            {isCurrentPlan 
                                                ? (user?.subscription?.isActive 
                                                    ? 'Текущий план' 
                                                    : 'Возобновить подписку')
                                                : 'Выбрать план'}
                                        </Button>
                                    </CardActions>
                                </Card>
                            </Grid>
                        );
                    })}
                </Grid>
            </>
        );
    };

    return (
        <Container maxWidth="lg" sx={{ py: 4 }}>
            <Box sx={{ mb: 4, textAlign: 'center' }}>
                <Typography 
                    variant="h3" 
                    component="h1" 
                    fontWeight="bold"
                    sx={{ 
                        mb: 2,
                        color: COLORS.textPrimary,
                    }}
                >
                    Подписка на сервис оценки
                </Typography>
                <Typography variant="h6" color={COLORS.textSecondary} sx={{ maxWidth: '800px', mx: 'auto' }}>
                    Выберите подходящий план для доступа к инструментам оценки стоимости антикварных книг
                </Typography>
            </Box>
            
            {renderCurrentSubscription()}
            
            <Box sx={{ mb: 4 }}>
                <Typography variant="h5" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                    Преимущества подписки
                </Typography>
                <Grid container spacing={3}>
                    <Grid item xs={12} sm={6} md={3}>
                        <Paper elevation={2} sx={{ p: 3, height: '100%', borderRadius: '12px', bgcolor: 'white' }}>
                            <PriceChangeIcon sx={{ color: COLORS.primary }} />
                            <Typography variant="h6" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                                Актуальные цены
                            </Typography>
                            <Typography variant="body2" color={COLORS.textSecondary}>
                                Доступ к актуальным данным о ценах на редкие и антикварные издания из проверенных источников
                            </Typography>
                        </Paper>
                    </Grid>
                    <Grid item xs={12} sm={6} md={3}>
                        <Paper elevation={2} sx={{ p: 3, height: '100%', borderRadius: '12px', bgcolor: 'white' }}>
                            <HistoryIcon sx={{ color: COLORS.primary }} />
                            <Typography variant="h6" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                                История продаж
                            </Typography>
                            <Typography variant="body2" color={COLORS.textSecondary}>
                                Полная история продаж с динамикой изменения стоимости редких изданий за длительный период
                            </Typography>
                        </Paper>
                    </Grid>
                    <Grid item xs={12} sm={6} md={3}>
                        <Paper elevation={2} sx={{ p: 3, height: '100%', borderRadius: '12px', bgcolor: 'white' }}>
                            <ImageSearchIcon sx={{ color: COLORS.primary }} />
                            <Typography variant="h6" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                                Детальные изображения
                            </Typography>
                            <Typography variant="body2" color={COLORS.textSecondary}>
                                Высококачественные фотографии для точной оценки состояния и аутентичности издания
                            </Typography>
                        </Paper>
                    </Grid>
                    <Grid item xs={12} sm={6} md={3}>
                        <Paper elevation={2} sx={{ p: 3, height: '100%', borderRadius: '12px', bgcolor: 'white' }}>
                            <AnalyticsIcon sx={{ color: COLORS.primary }} />
                            <Typography variant="h6" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                                Аналитика рынка
                            </Typography>
                            <Typography variant="body2" color={COLORS.textSecondary}>
                                Профессиональные инструменты анализа рынка антикварных книг и прогнозирования стоимости
                            </Typography>
                        </Paper>
                    </Grid>
                </Grid>
            </Box>
            
            <Typography variant="h5" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                Планы подписки
            </Typography>
            {renderPlans()}
            
            <Box sx={{ mt: 6 }}>
                <Paper elevation={2} sx={{ p: 3, borderRadius: '12px', bgcolor: 'white' }}>
                    <Typography variant="h6" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                        Часто задаваемые вопросы
                    </Typography>
                    <Grid container spacing={3}>
                        <Grid item xs={12} md={6}>
                            <Typography variant="subtitle1" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                                Как оформить подписку?
                            </Typography>
                            <Typography variant="body2" paragraph color={COLORS.textSecondary}>
                                Выберите подходящий план, нажмите кнопку "Выбрать план" и следуйте инструкциям по оплате. После успешной оплаты подписка будет активирована автоматически.
                            </Typography>
                            
                            <Typography variant="subtitle1" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                                Можно ли отменить подписку?
                            </Typography>
                            <Typography variant="body2" paragraph color={COLORS.textSecondary}>
                                Да, вы можете отменить подписку в любое время. При этом вы сохраните доступ к сервису до окончания оплаченного периода.
                            </Typography>
                        </Grid>
                        <Grid item xs={12} md={6}>
                            <Typography variant="subtitle1" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                                Как часто обновляются данные о ценах?
                            </Typography>
                            <Typography variant="body2" paragraph color={COLORS.textSecondary}>
                                Данные о ценах обновляются ежедневно на основе информации с аукционов, специализированных площадок и частных продаж.
                            </Typography>
                            
                            <Typography variant="subtitle1" fontWeight="bold" gutterBottom color={COLORS.textPrimary}>
                                Можно ли изменить план подписки?
                            </Typography>
                            <Typography variant="body2" paragraph color={COLORS.textSecondary}>
                                Да, вы можете изменить план в любое время. При переходе на более дорогой план разница будет рассчитана пропорционально оставшемуся времени текущей подписки.
                            </Typography>
                        </Grid>
                    </Grid>
                </Paper>
            </Box>
            
            <Snackbar
                open={snackbarOpen}
                autoHideDuration={6000}
                onClose={() => setSnackbarOpen(false)}
                message={snackbarMessage}
                severity={snackbarSeverity}
            />
        </Container>
    );
};

export default SubscriptionPage;
