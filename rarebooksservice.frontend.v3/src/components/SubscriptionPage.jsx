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
    Snackbar
} from '@mui/material';
import { useNavigate } from 'react-router-dom';
import { UserContext } from '../context/UserContext';
import { getSubscriptionPlans, subscribeUser, cancelSubscription, checkSubscriptionStatus } from '../api';

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
            if (response.data.activeSubscription && user && !user.subscription) {
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
                setPlans(response.data);
                
                // Проверяем статус подписки только при первой загрузке
                if (user && initialLoadRef.current) {
                    initialLoadRef.current = false; // Отмечаем, что первая загрузка выполнена
                    await checkStatus();
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
            await subscribeUser(planId);
            
            // Сбрасываем флаг initialLoad, чтобы при перезагрузке компонента данные обновились
            initialLoadRef.current = true;
            
            await refreshUser(true);
            showSnackbar('Подписка успешно оформлена!', 'success');
            
            // Вызываем логирование после обновления данных пользователя
            logSubscriptionDiagnosticInfo();
        } catch (err) {
            console.error('Ошибка при оформлении подписки:', err);
            showSnackbar('Не удалось оформить подписку. Пожалуйста, попробуйте позже.', 'error');
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
        
        // Проверяем сначала статус
        if (subscription.status && subscription.status !== 'Active') {
            if (process.env.NODE_ENV !== 'production') {
                console.warn('Подписка не активна, статус:', subscription.status);
            }
            return false;
        }
        
        // Затем проверяем явно заданный флаг isActive
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
                <Paper elevation={2} sx={{ p: 3, mb: 4, borderRadius: '12px', bgcolor: 'rgba(211, 47, 47, 0.05)' }}>
                    <Typography variant="h6" fontWeight="bold" gutterBottom>
                        У вас нет активной подписки
                    </Typography>
                    <Typography variant="body1" paragraph>
                        Оформите подписку, чтобы получить доступ к полному функционалу сервиса оценки антикварных книг.
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        Выберите подходящий план подписки ниже.
                    </Typography>
                </Paper>
            );
        }

        const { subscription } = user;

        return (
            <Paper 
                elevation={2} 
                sx={{ 
                    p: 3, 
                    mb: 4, 
                    borderRadius: '12px',
                    bgcolor: subscriptionActive ? 'rgba(46, 125, 50, 0.05)' : 'rgba(211, 47, 47, 0.05)'
                }}
            >
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                    <VerifiedUserIcon 
                        color={subscriptionActive ? 'success' : 'error'} 
                        sx={{ mr: 1, fontSize: 28 }} 
                    />
                    <Typography variant="h5" fontWeight="bold">
                        Ваша текущая подписка
                    </Typography>
                </Box>
                
                <Grid container spacing={3}>
                    <Grid item xs={12} md={8}>
                        <Box sx={{ mb: 2 }}>
                            <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                                План:
                            </Typography>
                            <Typography variant="h6">
                                {subscription.planName || 'Стандартный план'}
                            </Typography>
                        </Box>
                        
                        <Box sx={{ mb: 2 }}>
                            <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                                Статус:
                            </Typography>
                            <Box sx={{ display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 1 }}>
                                <Chip 
                                    label={subscriptionActive ? 'Активна' : 'Неактивна'} 
                                    color={subscriptionActive ? 'success' : 'error'} 
                                    variant="outlined"
                                />
                                {!subscriptionActive && (
                                    <Typography variant="caption" color="error">
                                        {displayReason}
                                    </Typography>
                                )}
                            </Box>
                        </Box>
                        
                        <Box sx={{ mb: 2 }}>
                            <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
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
        
        const { subscription } = user;
        const now = new Date();
        const endDate = new Date(subscription.endDate);
        const startDate = new Date(subscription.startDate);
        
        const reasons = [];
        
        if (subscription.status !== 'Active') {
            reasons.push(`Статус подписки не активен (${subscription.status || 'не указан'})`);
        }
        
        if (!subscription.isActive) {
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

    const renderFeatureList = (features) => (
        <List dense>
            {features.map((feature, index) => (
                <ListItem key={index} disableGutters>
                    <ListItemIcon sx={{ minWidth: 36 }}>
                        <CheckIcon />
                    </ListItemIcon>
                    <ListItemText primary={feature} />
                </ListItem>
            ))}
        </List>
    );

    const renderPlans = () => {
        if (loading) {
            return (
                <Box sx={{ display: 'flex', justifyContent: 'center', p: 5 }}>
                    <CircularProgress />
                </Box>
            );
        }

        if (error) {
            return (
                <Alert severity="error" sx={{ mb: 4 }}>
                    {error}
                </Alert>
            );
        }
        
        // Если планы не загружены или их нет, показываем сообщение
        if (!plans || plans.length === 0) {
            return (
                <Alert severity="info" sx={{ mb: 4 }}>
                    В данный момент нет доступных планов подписки. Пожалуйста, попробуйте позже.
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
                <Box sx={{ mb: 4, textAlign: 'center' }}>
                    <Typography variant="h4" component="h2" fontWeight="bold" gutterBottom>
                        Выберите подходящий план подписки
                    </Typography>
                    <Typography variant="body1" color="text.secondary">
                        Получите доступ к полному функционалу сервиса оценки антикварных книг
                    </Typography>
                </Box>
                
                <Grid container spacing={3} id="subscription-plans">
                    {plans.map((plan) => {
                        // Определяем, является ли этот план текущим для пользователя
                        const isCurrentPlan = user?.subscription?.subscriptionPlanId === plan.id;
                        
                        // Получаем функции для плана из стандартного набора или используем общие
                        const features = defaultPlanFeatures[plan.name] || [
                            `Лимит запросов: ${plan.monthlyRequestLimit} в месяц`,
                            'Доступ к оценке стоимости книг',
                            'Поиск по базе данных антикварных книг'
                        ];
                        
                        // Получаем иконку для плана или используем стандартную
                        const featureIcon = featureIcons[plan.name] || <StarIcon />;
                        
                        // Определяем, является ли план премиальным
                        const isPremium = plan.name.toLowerCase().includes('премиум');
                        
                        return (
                            <Grid item xs={12} md={4} key={plan.id}>
                                <Card 
                                    elevation={3} 
                                    sx={{ 
                                        height: '100%', 
                                        display: 'flex', 
                                        flexDirection: 'column',
                                        borderRadius: '12px',
                                        position: 'relative',
                                        overflow: 'visible',
                                        transition: 'transform 0.2s ease, box-shadow 0.2s ease',
                                        '&:hover': {
                                            transform: 'translateY(-8px)',
                                            boxShadow: '0 12px 28px rgba(0,0,0,0.15)'
                                        },
                                        ...(isPremium && {
                                            border: '2px solid var(--secondary-color)',
                                        })
                                    }}
                                >
                                    {isPremium && (
                                        <Chip
                                            label="Рекомендуемый"
                                            color="secondary"
                                            sx={{
                                                position: 'absolute',
                                                top: -12,
                                                right: 16,
                                                fontWeight: 'bold'
                                            }}
                                        />
                                    )}
                                    
                                    <CardContent sx={{ p: 3, flexGrow: 1 }}>
                                        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                            {featureIcon}
                                            <Typography variant="h5" component="h2" fontWeight="bold" sx={{ ml: 1 }}>
                                                {plan.name}
                                            </Typography>
                                        </Box>
                                        
                                        <Typography variant="h4" color="primary" fontWeight="bold" sx={{ mb: 2 }}>
                                            {plan.price} ₽
                                            <Typography variant="body2" component="span" color="text.secondary" sx={{ ml: 1 }}>
                                                / месяц
                                            </Typography>
                                        </Typography>
                                        
                                        <Typography variant="body2" color="text.secondary" paragraph>
                                            {plan.description || `План "${plan.name}" для оценки стоимости антикварных книг. Лимит запросов: ${plan.monthlyRequestLimit} в месяц.`}
                                        </Typography>
                                        
                                        <Box sx={{ 
                                            display: 'flex', 
                                            alignItems: 'center', 
                                            mb: 2, 
                                            p: 1, 
                                            bgcolor: 'rgba(0, 0, 0, 0.03)', 
                                            borderRadius: 1 
                                        }}>
                                            <Typography variant="body2" fontWeight="bold">
                                                Лимит запросов: <span style={{ color: 'var(--primary-color)' }}>{plan.monthlyRequestLimit}</span> в месяц
                                            </Typography>
                                        </Box>
                                        
                                        <Divider sx={{ my: 2 }} />
                                        
                                        <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                                            Включено:
                                        </Typography>
                                        
                                        {renderFeatureList(features)}
                                    </CardContent>
                                    
                                    <CardActions sx={{ p: 3, pt: 0 }}>
                                        <Button 
                                            variant={isCurrentPlan ? "outlined" : "contained"} 
                                            color={isCurrentPlan ? "success" : "primary"}
                                            fullWidth
                                            disabled={subscribing || (isCurrentPlan && user?.subscription?.isActive)}
                                            onClick={() => handleSubscribe(plan.id)}
                                            sx={{ 
                                                py: 1.5,
                                                fontWeight: 'bold',
                                                ...(isPremium && !isCurrentPlan && {
                                                    background: 'linear-gradient(45deg, var(--primary-color) 30%, var(--secondary-color) 90%)',
                                                    boxShadow: '0 3px 5px 2px rgba(255, 105, 135, .3)',
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
                        color: 'var(--primary-dark)',
                        textShadow: '0px 2px 4px rgba(0,0,0,0.1)'
                    }}
                >
                    Подписка на сервис оценки
                </Typography>
                <Typography variant="h6" color="text.secondary" sx={{ maxWidth: '800px', mx: 'auto' }}>
                    Выберите подходящий план для доступа к инструментам оценки стоимости антикварных книг
                </Typography>
            </Box>
            
            {renderCurrentSubscription()}
            
            <Box sx={{ mb: 4 }}>
                <Typography variant="h5" fontWeight="bold" gutterBottom>
                    Преимущества подписки
                </Typography>
                <Grid container spacing={3}>
                    <Grid item xs={12} sm={6} md={3}>
                        <Paper elevation={1} sx={{ p: 3, height: '100%', borderRadius: '12px' }}>
                            <PriceChangeIcon />
                            <Typography variant="h6" fontWeight="bold" gutterBottom>
                                Актуальные цены
                            </Typography>
                            <Typography variant="body2">
                                Доступ к актуальным данным о ценах на редкие и антикварные издания из проверенных источников
                            </Typography>
                        </Paper>
                    </Grid>
                    <Grid item xs={12} sm={6} md={3}>
                        <Paper elevation={1} sx={{ p: 3, height: '100%', borderRadius: '12px' }}>
                            <HistoryIcon />
                            <Typography variant="h6" fontWeight="bold" gutterBottom>
                                История продаж
                            </Typography>
                            <Typography variant="body2">
                                Полная история продаж с динамикой изменения стоимости редких изданий за длительный период
                            </Typography>
                        </Paper>
                    </Grid>
                    <Grid item xs={12} sm={6} md={3}>
                        <Paper elevation={1} sx={{ p: 3, height: '100%', borderRadius: '12px' }}>
                            <ImageSearchIcon />
                            <Typography variant="h6" fontWeight="bold" gutterBottom>
                                Детальные изображения
                            </Typography>
                            <Typography variant="body2">
                                Высококачественные фотографии для точной оценки состояния и аутентичности издания
                            </Typography>
                        </Paper>
                    </Grid>
                    <Grid item xs={12} sm={6} md={3}>
                        <Paper elevation={1} sx={{ p: 3, height: '100%', borderRadius: '12px' }}>
                            <AnalyticsIcon />
                            <Typography variant="h6" fontWeight="bold" gutterBottom>
                                Аналитика рынка
                            </Typography>
                            <Typography variant="body2">
                                Профессиональные инструменты анализа рынка антикварных книг и прогнозирования стоимости
                            </Typography>
                        </Paper>
                    </Grid>
                </Grid>
            </Box>
            
            <Typography variant="h5" fontWeight="bold" gutterBottom>
                Планы подписки
            </Typography>
            {renderPlans()}
            
            <Box sx={{ mt: 6 }}>
                <Paper elevation={1} sx={{ p: 3, borderRadius: '12px' }}>
                    <Typography variant="h6" fontWeight="bold" gutterBottom>
                        Часто задаваемые вопросы
                    </Typography>
                    <Grid container spacing={3}>
                        <Grid item xs={12} md={6}>
                            <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                                Как оформить подписку?
                            </Typography>
                            <Typography variant="body2" paragraph>
                                Выберите подходящий план, нажмите кнопку "Выбрать план" и следуйте инструкциям по оплате. После успешной оплаты подписка будет активирована автоматически.
                            </Typography>
                            
                            <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                                Можно ли отменить подписку?
                            </Typography>
                            <Typography variant="body2" paragraph>
                                Да, вы можете отменить подписку в любое время. При этом вы сохраните доступ к сервису до окончания оплаченного периода.
                            </Typography>
                        </Grid>
                        <Grid item xs={12} md={6}>
                            <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                                Как часто обновляются данные о ценах?
                            </Typography>
                            <Typography variant="body2" paragraph>
                                Данные о ценах обновляются ежедневно на основе информации с аукционов, специализированных площадок и частных продаж.
                            </Typography>
                            
                            <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                                Можно ли изменить план подписки?
                            </Typography>
                            <Typography variant="body2" paragraph>
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
