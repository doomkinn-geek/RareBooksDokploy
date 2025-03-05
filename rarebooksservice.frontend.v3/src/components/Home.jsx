// src/components/Home.jsx
import React, { useState, useEffect, useContext, useRef, useMemo } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
    Button,
    Typography,
    Checkbox,
    FormControlLabel,
    TextField,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    CircularProgress,
    Card,
    CardContent,
    CardMedia,
    Box,
    Paper,
    Chip,
    Grid,
    Divider,
    Container,
    Alert,
    Snackbar,
    IconButton,
    Tooltip,
    useMediaQuery,
    useTheme,
    InputAdornment,
    Accordion,
    AccordionSummary,
    AccordionDetails
} from '@mui/material';
import axios from 'axios';
import Cookies from 'js-cookie';
import { getCategories, sendFeedback as sendFeedbackApi, API_URL, searchBooksByPriceRange, searchBooksByTitle, getPriceStatistics } from '../api';
import { UserContext } from '../context/UserContext';
import { LanguageContext } from '../context/LanguageContext';
import translations from '../translations';
import ErrorMessage from './ErrorMessage';
import RecentSales from './RecentSales'; // Импорт компонента RecentSales

// Импорт иконок
import SearchIcon from '@mui/icons-material/Search';
import CategoryIcon from '@mui/icons-material/Category';
import TrendingUpIcon from '@mui/icons-material/TrendingUp';
import InfoIcon from '@mui/icons-material/Info';
import HistoryIcon from '@mui/icons-material/History';
import VerifiedUserIcon from '@mui/icons-material/VerifiedUser';
import PriceChangeIcon from '@mui/icons-material/PriceChange';
import BookmarkAddedIcon from '@mui/icons-material/BookmarkAdded';
import CloseIcon from '@mui/icons-material/Close';
import DescriptionIcon from '@mui/icons-material/Description';
import EuroIcon from '@mui/icons-material/Euro';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import MenuBookIcon from '@mui/icons-material/MenuBook';
import AssessmentIcon from '@mui/icons-material/Assessment';
import MonetizationOnIcon from '@mui/icons-material/MonetizationOn';
import PhotoLibraryIcon from '@mui/icons-material/PhotoLibrary';
import CurrencyRubleIcon from '@mui/icons-material/CurrencyRuble';
import AutoStoriesIcon from '@mui/icons-material/AutoStories';
import DatasetIcon from '@mui/icons-material/Dataset';
import AssignmentIcon from '@mui/icons-material/Assignment';
import FindInPageIcon from '@mui/icons-material/FindInPage';
import LoopIcon from '@mui/icons-material/Loop';
import StorageIcon from '@mui/icons-material/Storage';
import LockIcon from '@mui/icons-material/Lock';

const Home = () => {
    const { user, setUser, loading } = useContext(UserContext);
    const { language } = useContext(LanguageContext);
    const navigate = useNavigate();
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const isTablet = useMediaQuery(theme.breakpoints.down('md'));
    
    // Получаем переводы для текущего языка
    const t = translations[language];

    // Состояния компонента
    const [title, setTitle] = useState('');
    const [exactPhraseTitle, setExactPhraseTitle] = useState(false);
    const [description, setDescription] = useState('');
    const [exactPhraseDescription, setExactPhraseDescription] = useState(false);
    const [minPrice, setMinPrice] = useState('');
    const [maxPrice, setMaxPrice] = useState('');
    const [categories, setCategories] = useState([]);
    const [selectedCategory, setSelectedCategory] = useState('');
    
    // Состояния API
    const [apiConnected, setApiConnected] = useState(false);
    const [apiStatus, setApiStatus] = useState(t.checkingApiConnection);
    
    // Состояния диалога обратной связи
    const [isFeedbackOpen, setIsFeedbackOpen] = useState(false);
    const [feedbackText, setFeedbackText] = useState('');
    const [feedbackError, setFeedbackError] = useState('');
    const [feedbackLoading, setFeedbackLoading] = useState(false);
    
    // Состояния snackbar
    const [snackbarOpen, setSnackbarOpen] = useState(false);
    const [snackbarMessage, setSnackbarMessage] = useState('');
    const [snackbarSeverity, setSnackbarSeverity] = useState('info');
    
    // Флаг для отслеживания монтирования компонента
    const isMounted = useRef(true);

    // Обновляем тексты при изменении языка
    useEffect(() => {
        setApiStatus(apiConnected ? t.apiConnected : t.apiConnectionError);
    }, [language, apiConnected, t]);

    // Загрузка категорий
    useEffect(() => {
        const fetchInitialData = async () => {
            try {                
                console.log("Начало загрузки данных на главной странице");
                
                // Загрузка категорий
                try {
                    console.log("Начало запроса категорий");
                    const categoriesResponse = await getCategories();
                    setCategories(categoriesResponse.data);
                    setApiConnected(true);
                    setApiStatus(t.apiConnected);
                    console.log("Успешно загружены категории:", categoriesResponse.data);
                } catch (categoryError) {
                    console.error("Ошибка загрузки категорий:", categoryError);
                    setApiConnected(false);
                    setApiStatus(t.apiConnectionError);
                    
                    // Диагностика ошибки категорий
                    let errorDetails = "Неизвестная ошибка";
                    if (categoryError.response) {
                        errorDetails = `Сервер ответил с ошибкой ${categoryError.response.status}: ${JSON.stringify(categoryError.response.data)}`;
                    } else if (categoryError.request) {
                        errorDetails = "Нет ответа от сервера. Возможно, сервер недоступен или отклонил запрос.";
                    } else {
                        errorDetails = categoryError.message || "Неизвестная ошибка";
                    }
                    console.error("Детали ошибки категорий:", errorDetails);
                }
                
                console.log("Завершена попытка загрузки данных на главной странице");
            } catch (error) {
                console.error("Общая ошибка загрузки данных:", error);
                setApiConnected(false);
                setApiStatus(t.apiConnectionError);
            }
        };
        
        fetchInitialData();
    }, [t, apiConnected]);

    // useEffect для отслеживания монтирования/размонтирования компонента
    useEffect(() => {
        // При монтировании isMounted = true
        isMounted.current = true;
        
        // Очистка при размонтировании компонента
        return () => {
            isMounted.current = false;
        };
    }, []);

    // --- Поиск ---

    // Обёртка, чтобы проверять авторизацию перед поиском
    const checkAuthBeforeSearch = (searchFn) => {
        if (!user) {
            alert(t.authRequired);
            return;
        }
        // Если авторизован, запускаем реальный поиск
        searchFn();
    };

    const handleTitleSearch = () => {
        checkAuthBeforeSearch(() => {
            if (title.trim()) {
                navigate(`/searchByTitle/${title}?exactPhrase=${exactPhraseTitle}`);
            }
        });
    };

    const handleDescriptionSearch = () => {
        checkAuthBeforeSearch(() => {
            if (description.trim()) {
                navigate(`/searchByDescription/${description}?exactPhrase=${exactPhraseDescription}`);
            }
        });
    };

    const handlePriceRangeSearch = () => {
        checkAuthBeforeSearch(() => {
            if (minPrice.trim() && maxPrice.trim()) {
                navigate(`/searchByPriceRange/${minPrice}/${maxPrice}`);
            }
        });
    };
    
    // Форматирование даты
    const formatDate = (dateString) => {
        try {
            if (!dateString) return 'Дата не указана';
            
            const date = new Date(dateString);
            
            // Проверка валидности даты
            if (isNaN(date.getTime())) {
                return 'Некорректная дата';
            }
            
            return new Intl.DateTimeFormat('ru-RU', {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric'
            }).format(date);
        } catch (error) {
            console.error('Ошибка форматирования даты:', error);
            return 'Ошибка даты';
        }
    };

    // Функция для выхода из системы
    const handleLogout = () => {
        // Удаляем токен из cookie
        Cookies.remove('token');
        // Очищаем информацию о пользователе в контексте
        setUser(null);
        // Показываем сообщение об успешном выходе
        showSnackbar(t.logoutSuccess, 'success');
        // Опционально можно перенаправить на главную страницу
        navigate('/');
    };

    // Функция для перехода на страницу администратора
    const goToAdminPanel = () => {
        navigate('/admin');
    };

    // Отображение статуса подписки
    const renderSubscriptionStatus = () => {
        if (!user) return null;

        // Проверяем наличие свойства hasSubscription
        const hasSubscription = user.hasSubscription || false;

        return (
            <Paper elevation={3} sx={{ p: { xs: 2, sm: 3, md: 4 }, mb: 4, bgcolor: 'white', borderRadius: '12px' }}>
                <Box sx={{ 
                    display: 'flex', 
                    flexDirection: { xs: 'column', sm: 'row' },
                    justifyContent: 'space-between', 
                    alignItems: { xs: 'flex-start', sm: 'center' },
                    gap: { xs: 2, sm: 0 }
                }}>
                    <Box>
                        <Typography variant="h6" sx={{ 
                            fontWeight: 'bold', 
                            mb: 1, 
                            fontSize: { xs: '1rem', md: '1.25rem' },
                            color: '#333',
                            display: 'flex',
                            alignItems: 'center',
                            flexWrap: 'wrap'
                        }}>
                            <VerifiedUserIcon sx={{ mr: 1, color: '#d32f2f', fontSize: '1.2rem' }} />
                            {t.subscriptionStatus}: {hasSubscription ? (
                                <Chip 
                                    label={t.active} 
                                    size="small" 
                                    sx={{ 
                                        ml: 1,
                                        bgcolor: '#d32f2f',
                                        color: 'white',
                                        fontWeight: 'bold'
                                    }} 
                                />
                            ) : (
                                <Chip 
                                    label={t.inactive} 
                                    size="small" 
                                    sx={{ 
                                        ml: 1,
                                        bgcolor: '#888',
                                        color: 'white',
                                        fontWeight: 'bold'
                                    }} 
                                />
                            )}
                        </Typography>
                        
                        {hasSubscription && (
                            <Typography variant="body2" sx={{ color: '#555' }}>
                                {t.subscriptionType}: <strong>{user.subscriptionType || t.standard}</strong><br />
                                {t.validUntil}: <strong>{formatDate(user.subscriptionExpiryDate)}</strong>
                            </Typography>
                        )}
                    </Box>
                    
                    <Box sx={{ 
                        display: 'flex', 
                        gap: 2,
                        flexDirection: { xs: 'column', sm: 'row' },
                        width: { xs: '100%', sm: 'auto' }
                    }}>
                        {!hasSubscription && (
                            <Button 
                                variant="contained" 
                                component={Link} 
                                to="/subscription"
                                fullWidth={isMobile}
                                sx={{ 
                                    borderRadius: '8px', 
                                    textTransform: 'none',
                                    fontWeight: 'bold',
                                    bgcolor: '#d32f2f',
                                    '&:hover': {
                                        bgcolor: '#b71c1c'
                                    }
                                }}
                            >
                                {t.getSubscription}
                            </Button>
                        )}
                        
                        {/* Кнопка для администраторов */}
                        {user && user.role && user.role.toLowerCase() === 'admin' && (
                            <Button 
                                variant="contained" 
                                component={Link} 
                                to="/admin"
                                fullWidth={isMobile}
                                sx={{ 
                                    borderRadius: '8px', 
                                    textTransform: 'none',
                                    fontWeight: 'bold',
                                    bgcolor: '#555',
                                    '&:hover': {
                                        bgcolor: '#333'
                                    }
                                }}
                            >
                                {t.adminPanel}
                            </Button>
                        )}
                        
                        <Button 
                            variant="outlined" 
                            onClick={handleLogout}
                            fullWidth={isMobile}
                            sx={{ 
                                borderRadius: '8px', 
                                textTransform: 'none',
                                fontWeight: 'bold',
                                borderColor: '#d32f2f',
                                color: '#d32f2f',
                                '&:hover': {
                                    borderColor: '#b71c1c',
                                    bgcolor: 'rgba(211, 47, 47, 0.04)'
                                }
                            }}
                        >
                            {t.logout}
                        </Button>
                    </Box>
                </Box>
            </Paper>
        );
    };

    // Функция для отображения уведомлений
    const showSnackbar = (message, severity = 'info') => {
        setSnackbarMessage(message);
        setSnackbarSeverity(severity);
        setSnackbarOpen(true);
    };

    // Форматирование цены
    const formatPrice = (price) => {
        return new Intl.NumberFormat(language === 'RU' ? 'ru-RU' : 'en-US', {
            style: 'currency',
            currency: language === 'RU' ? 'RUB' : 'USD',
            maximumFractionDigits: 0
        }).format(price);
    };

    const renderHeroSection = () => (
        <Box sx={{ 
            backgroundImage: 'linear-gradient(rgba(0, 0, 0, 0.5), rgba(0, 0, 0, 0.7)), url(https://images.unsplash.com/photo-1507842217343-583bb7270b66?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80)',
            backgroundSize: 'cover',
            backgroundPosition: 'center',
            color: 'white',
            py: { xs: 6, sm: 8, md: 10 },
            mb: 5,
            borderRadius: 2
        }}>
            <Container maxWidth="xl">
                <Grid container spacing={4}>
                    <Grid item xs={12} md={8}>
                        <Typography 
                            variant="h2" 
                            component="h1" 
                            sx={{ 
                                fontWeight: 'bold',
                                mb: 2,
                                fontSize: { xs: '2rem', sm: '2.5rem', md: '3rem' }
                            }}
                        >
                            {t.mainTitle}
                        </Typography>
                        
                        <Typography 
                            variant="h5" 
                            sx={{ 
                                mb: 4,
                                fontWeight: 400,
                                fontSize: { xs: '1rem', sm: '1.2rem', md: '1.5rem' }
                            }}
                        >
                            {t.mainSubtitle}
                        </Typography>
                    </Grid>
                    
                    <Grid item xs={12} md={4} sx={{ mt: { xs: 4, md: 0 } }}>
                        <Paper sx={{ p: 3, borderRadius: 2, bgcolor: 'rgba(255, 255, 255, 0.95)' }}>
                            <Typography variant="h6" color="primary.main" fontWeight="bold" mb={2}>
                                {t.titleSearch}
                            </Typography>
                            
                            <TextField
                                fullWidth
                                variant="outlined"
                                placeholder={t.bookTitle}
                                value={title}
                                onChange={(e) => setTitle(e.target.value)}
                                onKeyPress={(e) => {
                                    if (e.key === 'Enter' && title.trim()) {
                                        navigate(`/searchByTitle/${title}`);
                                    }
                                }}
                                sx={{ mb: 2 }}
                                InputProps={{
                                    endAdornment: (
                                        <InputAdornment position="end">
                                            <IconButton 
                                                edge="end" 
                                                onClick={() => {
                                                    if (title.trim()) navigate(`/searchByTitle/${title}`);
                                                }}
                                            >
                                                <SearchIcon />
                                            </IconButton>
                                        </InputAdornment>
                                    ),
                                }}
                            />
                            
                            <FormControlLabel
                                control={
                                    <Checkbox 
                                        checked={exactPhraseTitle} 
                                        onChange={(e) => setExactPhraseTitle(e.target.checked)}
                                        size="small"
                                    />
                                }
                                label={t.exactMatch}
                            />
                        </Paper>
                    </Grid>
                </Grid>
            </Container>
        </Box>
    );

    const renderAdditionalSearch = () => (
        <Box sx={{ mt: 4, mb: 6 }}>
            <Typography 
                variant="h4" 
                component="h2" 
                fontWeight="bold" 
                mb={4}
                sx={{ fontSize: { xs: '1.5rem', sm: '1.75rem', md: '2rem' } }}
            >
                {t.advancedSearch}
            </Typography>
            
            <Grid container spacing={3}>
                <Grid item xs={12} md={6}>
                    <Accordion>
                        <AccordionSummary
                            expandIcon={<ExpandMoreIcon />}
                            aria-controls="description-search-content"
                            id="description-search-header"
                        >
                            <Box sx={{ display: 'flex', alignItems: 'center' }}>
                                <DescriptionIcon sx={{ mr: 1 }} />
                                <Typography variant="h6" sx={{ fontSize: { xs: '1rem', md: '1.25rem' } }}>{t.descriptionSearch}</Typography>
                            </Box>
                        </AccordionSummary>
                        <AccordionDetails>
                            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                                {t.descriptionSearchHint}
                            </Typography>
                            <TextField
                                fullWidth
                                variant="outlined"
                                placeholder={t.keywordsPlaceholder}
                                value={description}
                                onChange={(e) => setDescription(e.target.value)}
                                onKeyPress={(e) => {
                                    if (e.key === 'Enter' && description.trim()) {
                                        handleDescriptionSearch();
                                    }
                                }}
                                sx={{ mb: 2 }}
                            />
                            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                <FormControlLabel
                                    control={
                                        <Checkbox 
                                            checked={exactPhraseDescription} 
                                            onChange={(e) => setExactPhraseDescription(e.target.checked)}
                                            size="small"
                                        />
                                    }
                                    label={t.exactMatch}
                                />
                                <Button 
                                    variant="contained" 
                                    onClick={handleDescriptionSearch}
                                    disabled={!description.trim()}
                                    startIcon={<SearchIcon />}
                                >
                                    {t.search}
                                </Button>
                            </Box>
                        </AccordionDetails>
                    </Accordion>
                </Grid>
                
                <Grid item xs={12} md={6}>
                    <Accordion>
                        <AccordionSummary
                            expandIcon={<ExpandMoreIcon />}
                            aria-controls="price-range-search-content"
                            id="price-range-search-header"
                        >
                            <Box sx={{ display: 'flex', alignItems: 'center' }}>
                                <MonetizationOnIcon sx={{ mr: 1 }} />
                                <Typography variant="h6">{t.priceRangeSearch}</Typography>
                            </Box>
                        </AccordionSummary>
                        <AccordionDetails>
                            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                                {t.priceRangeSearchHint}
                            </Typography>
                            <Grid container spacing={2} sx={{ mb: 2 }}>
                                <Grid item xs={6}>
                                    <TextField
                                        fullWidth
                                        variant="outlined"
                                        label={t.minPrice}
                                        type="number"
                                        value={minPrice}
                                        onChange={(e) => setMinPrice(e.target.value)}
                                        onKeyPress={(e) => {
                                            if (e.key === 'Enter' && minPrice.trim() && maxPrice.trim()) {
                                                handlePriceRangeSearch();
                                            }
                                        }}
                                        inputProps={{ 
                                            inputMode: 'numeric', 
                                            pattern: '[0-9]*',
                                            step: "any" 
                                        }}
                                        InputProps={{
                                            startAdornment: (
                                                <InputAdornment position="start">
                                                    ₽
                                                </InputAdornment>
                                            ),
                                            disableUnderline: true
                                        }}
                                    />
                                </Grid>
                                <Grid item xs={6}>
                                    <TextField
                                        fullWidth
                                        variant="outlined"
                                        label={t.maxPrice}
                                        type="number"
                                        value={maxPrice}
                                        onChange={(e) => setMaxPrice(e.target.value)}
                                        onKeyPress={(e) => {
                                            if (e.key === 'Enter' && minPrice.trim() && maxPrice.trim()) {
                                                handlePriceRangeSearch();
                                            }
                                        }}
                                        inputProps={{ 
                                            inputMode: 'numeric', 
                                            pattern: '[0-9]*',
                                            step: "any" 
                                        }}
                                        InputProps={{
                                            startAdornment: (
                                                <InputAdornment position="start">
                                                    ₽
                                                </InputAdornment>
                                            ),
                                            disableUnderline: true
                                        }}
                                    />
                                </Grid>
                            </Grid>
                            <Box sx={{ display: 'flex', justifyContent: 'flex-end' }}>
                                <Button 
                                    variant="contained" 
                                    onClick={handlePriceRangeSearch}
                                    disabled={!minPrice.trim() || !maxPrice.trim()}
                                    startIcon={<SearchIcon />}
                                >
                                    {t.search}
                                </Button>
                            </Box>
                        </AccordionDetails>
                    </Accordion>
                </Grid>
            </Grid>
        </Box>
    );

    // Добавляем информационный блок о сервисе оценки
    const renderAntiqueBooksValuationInfo = () => (
        <Paper elevation={3} sx={{ p: { xs: 2, sm: 3, md: 4 }, borderRadius: '12px', mb: 5, bgcolor: 'white' }}>
            <Typography 
                variant="h2" 
                fontWeight="bold" 
                gutterBottom
                sx={{ fontSize: { xs: '1.5rem', sm: '1.75rem', md: '2rem' }, color: '#333' }}
            >
                <MenuBookIcon sx={{ mr: 1, verticalAlign: 'middle', color: '#d32f2f' }} />
                {t.professionalAppraisal}
            </Typography>
            
            <Typography variant="body1" paragraph sx={{ mb: 3, fontWeight: 'bold', fontSize: '1.1rem', color: '#555' }}>
                {t.collectorsIntro}
            </Typography>
            
            <Typography variant="h3" gutterBottom sx={{ 
                fontSize: { xs: '1.25rem', sm: '1.4rem', md: '1.5rem' }, 
                mt: 4, 
                mb: 2,
                color: '#d32f2f'
            }}>
                <MonetizationOnIcon sx={{ mr: 1, verticalAlign: 'middle', color: '#d32f2f' }} />
                {t.howItWorksTitle}
            </Typography>
            
            <Grid container spacing={3} sx={{ mb: 3 }}>
                <Grid item xs={12} md={6}>
                    <Paper elevation={2} sx={{ 
                        p: 2, 
                        height: '100%', 
                        position: 'relative', 
                        borderLeft: '4px solid #d32f2f',
                        borderRadius: '4px',
                        bgcolor: '#fafafa'
                    }}>
                        <Box sx={{ 
                            position: 'absolute', 
                            top: 10, 
                            right: 10, 
                            bgcolor: '#d32f2f', 
                            color: 'white', 
                            width: 24, 
                            height: 24, 
                            borderRadius: '50%', 
                            display: 'flex', 
                            alignItems: 'center', 
                            justifyContent: 'center',
                            fontWeight: 'bold'
                        }}>
                            1
                        </Box>
                        <Typography variant="h6" gutterBottom fontWeight="bold" sx={{ color: '#333' }}>
                            <SearchIcon sx={{ mr: 1, verticalAlign: 'middle', color: '#d32f2f' }} />
                            {t.realSalesDatabase}
                        </Typography>
                        <Typography variant="body2" paragraph sx={{ color: '#555' }}>
                            {t.realSalesDesc}
                        </Typography>
                        <Typography variant="body2" sx={{ color: '#555' }}>
                            {t.serviceDescription}
                            <Chip 
                                label={t.salesRecords}
                                size="small" 
                                sx={{ 
                                    mx: 1, 
                                    fontWeight: 'bold',
                                    bgcolor: '#d32f2f',
                                    color: 'white'
                                }} 
                            />
                            {t.salesRecordsDesc}
                        </Typography>
                    </Paper>
                </Grid>
                
                <Grid item xs={12} md={6}>
                    <Paper elevation={2} sx={{ 
                        p: 2, 
                        height: '100%', 
                        position: 'relative', 
                        borderLeft: '4px solid #888',
                        borderRadius: '4px',
                        bgcolor: '#fafafa'
                    }}>
                        <Box sx={{ 
                            position: 'absolute', 
                            top: 10, 
                            right: 10, 
                            bgcolor: '#888', 
                            color: 'white', 
                            width: 24, 
                            height: 24, 
                            borderRadius: '50%', 
                            display: 'flex', 
                            alignItems: 'center', 
                            justifyContent: 'center',
                            fontWeight: 'bold'
                        }}>
                            2
                        </Box>
                        <Typography variant="h6" gutterBottom fontWeight="bold" sx={{ color: '#333' }}>
                            <BookmarkAddedIcon sx={{ mr: 1, verticalAlign: 'middle', color: '#888' }} />
                            {t.subscription}
                        </Typography>
                        <Typography variant="body2" paragraph sx={{ color: '#555' }}>
                            {t.subscriptionDesc}
                        </Typography>
                        <Typography variant="body2" sx={{ color: '#555' }}>
                            {t.subscriptionPromo}
                            <Chip 
                                label={t.fromPricePerMonth}
                                size="small" 
                                sx={{ 
                                    mx: 1, 
                                    fontWeight: 'bold',
                                    bgcolor: '#888',
                                    color: 'white'
                                }} 
                            />
                            {t.subscriptionNeedsDesc}
                        </Typography>
                    </Paper>
                </Grid>
                
                <Grid item xs={12} md={6}>
                    <Paper elevation={2} sx={{ 
                        p: 2, 
                        height: '100%', 
                        position: 'relative', 
                        borderLeft: '4px solid #888',
                        borderRadius: '4px',
                        bgcolor: '#fafafa'
                    }}>
                        <Box sx={{ 
                            position: 'absolute', 
                            top: 10, 
                            right: 10, 
                            bgcolor: '#888', 
                            color: 'white', 
                            width: 24, 
                            height: 24, 
                            borderRadius: '50%', 
                            display: 'flex', 
                            alignItems: 'center', 
                            justifyContent: 'center',
                            fontWeight: 'bold'
                        }}>
                            3
                        </Box>
                        <Typography variant="h6" gutterBottom fontWeight="bold" sx={{ color: '#333' }}>
                            <DescriptionIcon sx={{ mr: 1, verticalAlign: 'middle', color: '#888' }} />
                            {t.searchByParams}
                        </Typography>
                        <Typography variant="body2" paragraph sx={{ color: '#555' }}>
                            {t.searchByParamsDesc}
                        </Typography>
                        <Typography variant="body2" sx={{ color: '#555' }}>
                            {t.moreDetailsMoreAccurate}
                            <Chip 
                                label={t.accurateResult}
                                size="small" 
                                sx={{ 
                                    mx: 1, 
                                    fontWeight: 'bold',
                                    bgcolor: '#888',
                                    color: 'white'
                                }} 
                            />
                            {t.findAnalogsDesc}
                        </Typography>
                    </Paper>
                </Grid>
                
                <Grid item xs={12} md={6}>
                    <Paper elevation={2} sx={{ 
                        p: 2, 
                        height: '100%', 
                        position: 'relative', 
                        borderLeft: '4px solid #d32f2f',
                        borderRadius: '4px',
                        bgcolor: '#fafafa'
                    }}>
                        <Box sx={{ 
                            position: 'absolute', 
                            top: 10, 
                            right: 10, 
                            bgcolor: '#d32f2f', 
                            color: 'white', 
                            width: 24, 
                            height: 24, 
                            borderRadius: '50%', 
                            display: 'flex', 
                            alignItems: 'center', 
                            justifyContent: 'center',
                            fontWeight: 'bold'
                        }}>
                            4
                        </Box>
                        <Typography variant="h6" gutterBottom fontWeight="bold" sx={{ color: '#333' }}>
                            <PriceChangeIcon sx={{ mr: 1, verticalAlign: 'middle', color: '#d32f2f' }} />
                            {t.selfAppraisal}
                        </Typography>
                        <Typography variant="body2" paragraph sx={{ color: '#555' }}>
                            {t.selfAppraisalDesc}
                        </Typography>
                        <Typography variant="body2" sx={{ color: '#555' }}>
                            {t.dataAnalysisDesc}
                            <Chip 
                                label={t.determineSelf}
                                size="small" 
                                sx={{ 
                                    mx: 1, 
                                    fontWeight: 'bold',
                                    bgcolor: '#d32f2f',
                                    color: 'white'
                                }} 
                            />
                            {t.fairMarketValue}
                        </Typography>
                    </Paper>
                </Grid>
            </Grid>

            <Typography variant="h3" gutterBottom sx={{ 
                fontSize: { xs: '1.25rem', sm: '1.4rem', md: '1.5rem' }, 
                mt: 4, 
                mb: 2,
                color: '#d32f2f'
            }}>
                <AssessmentIcon sx={{ mr: 1, verticalAlign: 'middle', color: '#d32f2f' }} />
                {t.serviceAdvantages}
            </Typography>

            <Grid container spacing={3} sx={{ mb: 4 }}>
                <Grid item xs={12} md={6}>
                    <Box sx={{ mb: 2 }}>
                        <Typography variant="h6" fontWeight="bold" gutterBottom sx={{ color: '#333' }}>
                            <HistoryIcon sx={{ mr: 1, verticalAlign: 'middle', color: '#d32f2f' }} />
                            {t.tenYearArchive}
                        </Typography>
                        <Typography variant="body2" sx={{ color: '#555' }}>
                            {t.archiveRecords}
                        </Typography>
                    </Box>
                    <Box sx={{ mb: 2 }}>
                        <Typography variant="h6" fontWeight="bold" gutterBottom sx={{ color: '#333' }}>
                            <VerifiedUserIcon sx={{ mr: 1, verticalAlign: 'middle', color: '#888' }} />
                            {t.onlyRealSales}
                        </Typography>
                        <Typography variant="body2" sx={{ color: '#555' }}>
                            {t.realSalesExplanation}
                        </Typography>
                    </Box>
                </Grid>
                <Grid item xs={12} md={6}>
                    <Box sx={{ mb: 2 }}>
                        <Typography variant="h6" fontWeight="bold" gutterBottom sx={{ color: '#333' }}>
                            <SearchIcon sx={{ mr: 1, verticalAlign: 'middle', color: '#888' }} />
                            {t.flexibleSearch}
                        </Typography>
                        <Typography variant="body2" sx={{ color: '#555' }}>
                            {t.flexibleSearchDesc}
                        </Typography>
                    </Box>
                    <Box sx={{ mb: 2 }}>
                        <Typography variant="h6" fontWeight="bold" gutterBottom sx={{ color: '#333' }}>
                            <PhotoLibraryIcon sx={{ mr: 1, verticalAlign: 'middle', color: '#d32f2f' }} />
                            {t.completeLotInfo}
                        </Typography>
                        <Typography variant="body2" sx={{ color: '#555' }}>
                            {t.lotInfoDesc}
                        </Typography>
                    </Box>
                </Grid>
            </Grid>
            
            <Paper elevation={3} sx={{ p: 3, mb: 3, bgcolor: '#f5f5f5', borderRadius: '8px' }}>
                <Typography variant="h6" gutterBottom sx={{ display: 'flex', alignItems: 'center', color: '#333' }}>
                    <InfoIcon sx={{ mr: 1, color: '#d32f2f' }} />
                    {t.importantInfo}
                </Typography>
                <Typography variant="body2" paragraph sx={{ color: '#555' }}>
                    {t.serviceProvides}
                </Typography>
                <Typography variant="body2" sx={{ color: '#555' }}>
                    {t.compareBooks}
                </Typography>
            </Paper>

            <Box sx={{ 
                textAlign: 'center', 
                mt: 4, 
                p: 3, 
                bgcolor: '#f5f5f5', 
                borderRadius: '8px',
                color: '#333',
                border: '1px solid #ddd'
            }}>
                <Typography variant="h4" gutterBottom sx={{ fontWeight: 'bold', color: '#333', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Box sx={{ 
                        display: 'inline-flex', 
                        alignItems: 'center', 
                        mr: 1,
                        position: 'relative',
                        bgcolor: '#d32f2f',
                        p: 1,
                        borderRadius: '50%',
                        width: 40,
                        height: 40,
                        justifyContent: 'center'
                    }}>
                        <AutoStoriesIcon sx={{ color: 'white', fontSize: '1.2rem', position: 'absolute' }} />
                        <CurrencyRubleIcon sx={{ color: 'white', fontSize: '1.2rem', ml: 1.5, mt: 1.5 }} />
                    </Box>
                    {t.discoverValue.replace('💰', '')}
                </Typography>
                <Typography variant="h6" gutterBottom sx={{ color: '#555' }}>
                    {t.subscriptionFrom}
                </Typography>
                <Button 
                    component={Link} 
                    to="/subscription" 
                    variant="contained" 
                    size="large"
                    sx={{ 
                        mt: 2, 
                        fontWeight: 'bold', 
                        px: 4, 
                        py: 1.5,
                        bgcolor: '#d32f2f',
                        '&:hover': {
                            bgcolor: '#b71c1c'
                        }
                    }}
                >
                    {t.startAppraisal}
                </Button>
            </Box>
        </Paper>
    );

    // Основной UI компонент
    return (
        <Container maxWidth="xl" sx={{ pb: 4, px: { xs: 2, sm: 3, md: 4 } }}>
            {renderHeroSection()}

            {!apiConnected && (
                <Alert severity="error" sx={{ mb: 3 }}>
                    {apiStatus}
                </Alert>
            )}
            
            {/* Информация об оценке антикварных книг */}
            {renderAntiqueBooksValuationInfo()}
            
            {/* Секция статуса подписки для авторизованных пользователей */}
            {user && renderSubscriptionStatus()}
            
            {/* Дополнительные опции поиска */}
            {renderAdditionalSearch()}
            
            {/* Компонент недавних продаж */}
            <RecentSales />
            
            <Snackbar
                open={snackbarOpen}
                autoHideDuration={6000}
                onClose={() => setSnackbarOpen(false)}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'left' }}
            >
                <Alert 
                    onClose={() => setSnackbarOpen(false)} 
                    severity={snackbarSeverity}
                    sx={{ width: '100%' }}
                >
                    {snackbarMessage}
                </Alert>
            </Snackbar>
            
            {/* Диалог обратной связи */}
            <Dialog open={isFeedbackOpen} onClose={() => setIsFeedbackOpen(false)} fullWidth maxWidth="sm">
                <DialogTitle>
                    {t.feedback}
                    <IconButton
                        aria-label="close"
                        onClick={() => setIsFeedbackOpen(false)}
                        sx={{ position: 'absolute', right: 8, top: 8 }}
                    >
                        <CloseIcon />
                    </IconButton>
                </DialogTitle>
                <DialogContent>
                    <TextField
                        autoFocus
                        margin="dense"
                        label={t.feedbackPlaceholder}
                        fullWidth
                        multiline
                        rows={4}
                        value={feedbackText}
                        onChange={(e) => setFeedbackText(e.target.value)}
                        error={!!feedbackError}
                        helperText={feedbackError}
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setIsFeedbackOpen(false)} color="primary">
                        {t.cancel}
                    </Button>
                    <Button 
                        onClick={() => {}} 
                        color="primary"
                        disabled={feedbackLoading || !feedbackText.trim()}
                    >
                        {feedbackLoading ? <CircularProgress size={24} /> : t.send}
                    </Button>
                </DialogActions>
            </Dialog>
        </Container>
    );
};

export default Home;
