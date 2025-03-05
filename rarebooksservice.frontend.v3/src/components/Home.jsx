// src/components/Home.jsx
import React, { useState, useEffect, useContext, useRef } from 'react';
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
import { getCategories, sendFeedback as sendFeedbackApi, API_URL, searchBooksByPriceRange, searchBooksByTitle } from '../api';
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
            <Paper elevation={3} sx={{ padding: { xs: 2, md: 3 }, mb: 4, bgcolor: '#f5f8ff', borderRadius: '12px' }}>
                <Box sx={{ 
                    display: 'flex', 
                    flexDirection: { xs: 'column', sm: 'row' },
                    justifyContent: 'space-between', 
                    alignItems: { xs: 'flex-start', sm: 'center' },
                    gap: { xs: 2, sm: 0 }
                }}>
                    <Box>
                        <Typography variant="h6" sx={{ fontWeight: 'bold', mb: 1, fontSize: { xs: '1rem', md: '1.25rem' } }}>
                            {t.subscriptionStatus}: {hasSubscription ? (
                                <Chip 
                                    label={t.active} 
                                    color="success" 
                                    size="small" 
                                    sx={{ ml: 1 }} 
                                />
                            ) : (
                                <Chip 
                                    label={t.inactive} 
                                    color="error" 
                                    size="small" 
                                    sx={{ ml: 1 }} 
                                />
                            )}
                        </Typography>
                        
                        {hasSubscription && (
                            <Typography variant="body2" color="text.secondary">
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
                                color="primary" 
                                component={Link} 
                                to="/subscription"
                                fullWidth={isMobile}
                                sx={{ 
                                    borderRadius: '8px', 
                                    textTransform: 'none',
                                    fontWeight: 'bold'
                                }}
                            >
                                {t.getSubscription}
                            </Button>
                        )}
                        
                        {/* Кнопка для администраторов */}
                        {user && user.role && user.role.toLowerCase() === 'admin' && (
                            <Button 
                                variant="contained" 
                                color="secondary" 
                                component={Link} 
                                to="/admin"
                                fullWidth={isMobile}
                                sx={{ 
                                    borderRadius: '8px', 
                                    textTransform: 'none',
                                    fontWeight: 'bold'
                                }}
                            >
                                {t.adminPanel}
                            </Button>
                        )}
                        
                        <Button 
                            variant="outlined" 
                            color="error" 
                            onClick={handleLogout}
                            fullWidth={isMobile}
                            sx={{ 
                                borderRadius: '8px', 
                                textTransform: 'none',
                                fontWeight: 'bold'
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
        <Paper elevation={3} sx={{ p: { xs: 2, sm: 3, md: 4 }, borderRadius: '12px', mb: 5, bgcolor: '#f8f9fa' }}>
            <Typography 
                variant="h2" 
                fontWeight="bold" 
                gutterBottom
                sx={{ fontSize: { xs: '1.5rem', sm: '1.75rem', md: '2rem' } }}
            >
                <MenuBookIcon sx={{ mr: 1, verticalAlign: 'middle' }} />
                Профессиональная оценка антикварных книг
            </Typography>
            
            <Typography variant="body1" paragraph sx={{ mb: 3, fontWeight: 'bold', fontSize: '1.1rem' }}>
                Коллекционируете редкие книги или занимаетесь антиквариатом? Теперь у вас есть инструмент, который раскрывает реальную рыночную стоимость редких книг!
            </Typography>
            
            <Typography variant="h3" gutterBottom sx={{ fontSize: { xs: '1.25rem', sm: '1.4rem', md: '1.5rem' }, mt: 4, mb: 2 }}>
                <MonetizationOnIcon sx={{ mr: 1, verticalAlign: 'middle' }} />
                Как это работает
            </Typography>
            
            <Grid container spacing={3} sx={{ mb: 3 }}>
                <Grid item xs={12} md={6}>
                    <Paper elevation={2} sx={{ p: 2, height: '100%', position: 'relative', borderLeft: '4px solid #2196f3' }}>
                        <Box sx={{ position: 'absolute', top: 10, right: 10, bgcolor: 'primary.main', color: 'white', width: 24, height: 24, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            1
                        </Box>
                        <Typography variant="h6" gutterBottom fontWeight="bold">
                            <SearchIcon sx={{ mr: 1, verticalAlign: 'middle', color: 'primary.main' }} />
                            База данных реальных продаж
                        </Typography>
                        <Typography variant="body2" paragraph>
                            Наш сервис — это уникальная база данных продаж антикварных и редких книг, 
                            собранная с одного из популярнейших порталов торговли редкими изданиями России.
                        </Typography>
                        <Typography variant="body2">
                            В базе содержатся историческая информация о 
                            <Chip 
                                label="230 000+ продаж" 
                                size="small" 
                                color="primary"
                                sx={{ mx: 1, fontWeight: 'bold' }} 
                            />
                            с реальными ценами и подробным описанием каждого лота.
                        </Typography>
                    </Paper>
                </Grid>
                
                <Grid item xs={12} md={6}>
                    <Paper elevation={2} sx={{ p: 2, height: '100%', position: 'relative', borderLeft: '4px solid #ff9800' }}>
                        <Box sx={{ position: 'absolute', top: 10, right: 10, bgcolor: 'warning.main', color: 'white', width: 24, height: 24, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            2
                        </Box>
                        <Typography variant="h6" gutterBottom fontWeight="bold">
                            <BookmarkAddedIcon sx={{ mr: 1, verticalAlign: 'middle', color: 'warning.main' }} />
                            Оформление подписки
                        </Typography>
                        <Typography variant="body2" paragraph>
                            Для доступа к полной базе данных и инструментам оценки необходимо 
                            оформить подписку. Это обеспечивает точность результатов и постоянное обновление информации.
                        </Typography>
                        <Typography variant="body2">
                            Доступны различные тарифы подписки с 
                            <Chip 
                                label="от 50₽/месяц" 
                                size="small" 
                                color="warning"
                                sx={{ mx: 1, fontWeight: 'bold' }} 
                            />
                            в зависимости от ваших потребностей.
                        </Typography>
                    </Paper>
                </Grid>
                
                <Grid item xs={12} md={6}>
                    <Paper elevation={2} sx={{ p: 2, height: '100%', position: 'relative', borderLeft: '4px solid #4caf50' }}>
                        <Box sx={{ position: 'absolute', top: 10, right: 10, bgcolor: 'success.main', color: 'white', width: 24, height: 24, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            3
                        </Box>
                        <Typography variant="h6" gutterBottom fontWeight="bold">
                            <DescriptionIcon sx={{ mr: 1, verticalAlign: 'middle', color: 'success.main' }} />
                            Поиск по вашим параметрам
                        </Typography>
                        <Typography variant="body2" paragraph>
                            Для точной оценки введите всю имеющуюся у вас информацию о книге: 
                            название, год издания, автора, особенности издания.
                        </Typography>
                        <Typography variant="body2">
                            Чем больше деталей вы укажете, тем точнее будет 
                            <Chip 
                                label="результат оценки" 
                                size="small" 
                                color="success"
                                sx={{ mx: 1, fontWeight: 'bold' }} 
                            />
                            и подбор аналогичных изданий.
                        </Typography>
                    </Paper>
                </Grid>
                
                <Grid item xs={12} md={6}>
                    <Paper elevation={2} sx={{ p: 2, height: '100%', position: 'relative', borderLeft: '4px solid #9c27b0' }}>
                        <Box sx={{ position: 'absolute', top: 10, right: 10, bgcolor: 'secondary.main', color: 'white', width: 24, height: 24, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            4
                        </Box>
                        <Typography variant="h6" gutterBottom fontWeight="bold">
                            <PriceChangeIcon sx={{ mr: 1, verticalAlign: 'middle', color: 'secondary.main' }} />
                            Самостоятельная оценка
                        </Typography>
                        <Typography variant="body2" paragraph>
                            Анализируйте результаты поиска — изучайте аналогичные издания, 
                            которые были проданы ранее, их состояние, даты продаж и фактические цены.
                        </Typography>
                        <Typography variant="body2">
                            На основе представленных данных вы можете 
                            <Chip 
                                label="самостоятельно определить" 
                                size="small" 
                                color="secondary"
                                sx={{ mx: 1, fontWeight: 'bold' }} 
                            />
                            справедливую рыночную стоимость вашей книги.
                        </Typography>
                    </Paper>
                </Grid>
            </Grid>

            <Typography variant="h3" gutterBottom sx={{ fontSize: { xs: '1.25rem', sm: '1.4rem', md: '1.5rem' }, mt: 4, mb: 2 }}>
                <AssessmentIcon sx={{ mr: 1, verticalAlign: 'middle' }} />
                Преимущества нашего сервиса
            </Typography>

            <Grid container spacing={3} sx={{ mb: 4 }}>
                <Grid item xs={12} md={6}>
                    <Box sx={{ mb: 2 }}>
                        <Typography variant="h6" fontWeight="bold" gutterBottom>
                            <HistoryIcon sx={{ mr: 1, verticalAlign: 'middle', color: 'primary.main' }} />
                            Доступ к 10-летнему архиву аукционов
                        </Typography>
                        <Typography variant="body2">
                            Более 230 000 записей о реальных продажах антикварных книг за последнее десятилетие.
                        </Typography>
                    </Box>
                    <Box sx={{ mb: 2 }}>
                        <Typography variant="h6" fontWeight="bold" gutterBottom>
                            <VerifiedUserIcon sx={{ mr: 1, verticalAlign: 'middle', color: 'success.main' }} />
                            Только реальные продажи
                        </Typography>
                        <Typography variant="body2">
                            Все книги в нашей базе реально проданы на meshok.net — никаких теоретических оценок!
                        </Typography>
                    </Box>
                </Grid>
                <Grid item xs={12} md={6}>
                    <Box sx={{ mb: 2 }}>
                        <Typography variant="h6" fontWeight="bold" gutterBottom>
                            <SearchIcon sx={{ mr: 1, verticalAlign: 'middle', color: 'primary.main' }} />
                            Гибкий поиск
                        </Typography>
                        <Typography variant="body2">
                            Ищите по названию, описанию и ценовому диапазону. База данных постоянно пополняется новыми лотами.
                        </Typography>
                    </Box>
                    <Box sx={{ mb: 2 }}>
                        <Typography variant="h6" fontWeight="bold" gutterBottom>
                            <PhotoLibraryIcon sx={{ mr: 1, verticalAlign: 'middle', color: 'secondary.main' }} />
                            Полная информация о лотах
                        </Typography>
                        <Typography variant="body2">
                            Фотографии лотов и все подробные данные аукционов помогут вам точно оценить ваши книги.
                        </Typography>
                    </Box>
                </Grid>
            </Grid>
            
            <Paper elevation={3} sx={{ p: 3, mb: 3, bgcolor: '#f5f5f5', borderRadius: '8px' }}>
                <Typography variant="h6" gutterBottom sx={{ display: 'flex', alignItems: 'center' }}>
                    <InfoIcon sx={{ mr: 1, color: 'info.main' }} />
                    Важная информация
                </Typography>
                <Typography variant="body2" paragraph>
                    Наш сервис предоставляет детальные <strong>исторические данные о реальных продажах</strong>, 
                    но не делает автоматическую оценку вашей книги. Рыночная стоимость антикварных и редких изданий 
                    зависит от множества факторов: состояния экземпляра, редкости издания, исторической ценности, 
                    наличия автографов, иллюстраций и других особенностей.
                </Typography>
                <Typography variant="body2">
                    Сопоставляя вашу книгу с аналогичными проданными экземплярами, вы можете сформировать наиболее 
                    объективное представление о ее реальной рыночной стоимости на текущий момент.
                </Typography>
            </Paper>

            <Box sx={{ 
                textAlign: 'center', 
                mt: 4, 
                p: 3, 
                bgcolor: 'primary.light', 
                borderRadius: '8px',
                color: 'white'
            }}>
                <Typography variant="h4" gutterBottom sx={{ fontWeight: 'bold' }}>
                    💰 Узнайте, сколько действительно стоят редкие книги!
                </Typography>
                <Typography variant="h6" gutterBottom>
                    🎟 Подписка от 50 рублей
                </Typography>
                <Button 
                    component={Link} 
                    to="/subscription" 
                    variant="contained" 
                    color="secondary"
                    size="large"
                    sx={{ mt: 2, fontWeight: 'bold', px: 4, py: 1.5 }}
                >
                    Начать оценку антикварных книг
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
