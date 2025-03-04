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
import ArrowForwardIcon from '@mui/icons-material/ArrowForward';
import DescriptionIcon from '@mui/icons-material/Description';
import EuroIcon from '@mui/icons-material/Euro';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import MenuBookIcon from '@mui/icons-material/MenuBook';
import AssessmentIcon from '@mui/icons-material/Assessment';
import MonetizationOnIcon from '@mui/icons-material/MonetizationOn';

const Home = () => {
    const { user, setUser, loading } = useContext(UserContext);
    const { language } = useContext(LanguageContext);
    const navigate = useNavigate();
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    
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
    
    // Состояния статистики цен
    const [priceStatistics, setPriceStatistics] = useState(null);
    const [loadingStats, setLoadingStats] = useState(false);
    
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

    // Загрузка категорий и статистики
    useEffect(() => {
        const fetchInitialData = async () => {
            try {
                setLoadingStats(true);
                
                // Загрузка категорий
                const categoriesResponse = await getCategories();
                setCategories(categoriesResponse.data);
                setApiConnected(true);
                setApiStatus(t.apiConnected);
                
                // Загрузка статистики цен
                await fetchPriceStatistics();
            } catch (error) {
                console.error("Ошибка загрузки данных:", error);
                setApiConnected(false);
                setApiStatus(t.apiConnectionError);
            } finally {
                setLoadingStats(false);
            }
        };
        
        fetchInitialData();
    }, [t]);

    // useEffect для отслеживания монтирования/размонтирования компонента
    useEffect(() => {
        // При монтировании isMounted = true
        isMounted.current = true;
        
        // Очистка при размонтировании компонента
        return () => {
            isMounted.current = false;
        };
    }, []);

    // Функция для получения статистики цен
    const fetchPriceStatistics = async () => {
        setLoadingStats(true);
        try {
            const response = await getPriceStatistics();
            setPriceStatistics(response.data);
        } catch (error) {
            console.error('Ошибка при загрузке статистики цен:', error);
        } finally {
            setLoadingStats(false);
        }
    };

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
            <Paper elevation={3} sx={{ padding: 2, mb: 4, bgcolor: '#f5f8ff', borderRadius: '12px' }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <Box>
                        <Typography variant="h6" sx={{ fontWeight: 'bold', mb: 1 }}>
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
                    
                    <Box sx={{ display: 'flex', gap: 2 }}>
                        {!hasSubscription && (
                            <Button 
                                variant="contained" 
                                color="primary" 
                                component={Link} 
                                to="/subscription"
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

    // Компонент статистики цен
    const PriceStatistics = () => {
        if (loadingStats) {
            return (
                <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
                    <CircularProgress />
                </Box>
            );
        }
        
        if (!user) {
            return (
                <Paper elevation={2} sx={{ p: 3, borderRadius: '12px', mb: 3 }}>
                    <Typography variant="h6" fontWeight="bold" gutterBottom>
                        Статистика цен на антикварные книги
                    </Typography>
                    <Typography variant="body1" paragraph>
                        Для доступа к статистике цен необходимо авторизоваться и оформить подписку.
                    </Typography>
                    <Button 
                        variant="contained" 
                        color="primary" 
                        onClick={() => navigate('/login')}
                        sx={{ mr: 2, borderRadius: '8px', textTransform: 'none' }}
                    >
                        {t.login}
                    </Button>
                    <Button 
                        variant="outlined" 
                        onClick={() => navigate('/register')}
                        sx={{ borderRadius: '8px', textTransform: 'none' }}
                    >
                        {t.register}
                    </Button>
                </Paper>
            );
        }
        
        if (!priceStatistics && user.subscription?.status === 'Active') {
            return (
                <Paper elevation={2} sx={{ p: 3, borderRadius: '12px', mb: 3 }}>
                    <Typography variant="h6" fontWeight="bold" gutterBottom>
                        Статистика цен на антикварные книги
                    </Typography>
                    <Typography variant="body1" color="text.secondary">
                        Данные статистики временно недоступны. Пожалуйста, попробуйте позже.
                    </Typography>
                </Paper>
            );
        }
        
        if (!user.subscription || user.subscription.status !== 'Active') {
            return (
                <Paper elevation={2} sx={{ p: 3, borderRadius: '12px', mb: 3 }}>
                    <Typography variant="h6" fontWeight="bold" gutterBottom>
                        Статистика цен на антикварные книги
                    </Typography>
                    <Typography variant="body1" paragraph>
                        Для доступа к статистике цен необходимо оформить подписку.
                    </Typography>
                    <Button 
                        variant="contained" 
                        color="secondary" 
                        onClick={() => navigate('/subscription')}
                        sx={{ borderRadius: '8px', textTransform: 'none' }}
                    >
                        {t.getSubscription}
                    </Button>
                </Paper>
            );
        }
        
        return (
            <Paper elevation={2} sx={{ p: 3, borderRadius: '12px', mb: 3 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                    <TrendingUpIcon />
                    <Typography variant="h6" fontWeight="bold">
                        Статистика цен на антикварные книги
                    </Typography>
                </Box>
                
                <Grid container spacing={3}>
                    <Grid item xs={12} md={4}>
                        <Card sx={{ height: '100%', bgcolor: 'rgba(69, 39, 160, 0.05)', borderRadius: '8px' }}>
                            <CardContent>
                                <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                                    Средняя цена
                                </Typography>
                                <Typography variant="h4" color="primary" fontWeight="bold">
                                    {formatPrice(priceStatistics.averagePrice)}
                                </Typography>
                                <Typography variant="body2" color="text.secondary">
                                    По всем категориям
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                    
                    <Grid item xs={12} md={4}>
                        <Card sx={{ height: '100%', bgcolor: 'rgba(69, 39, 160, 0.05)', borderRadius: '8px' }}>
                            <CardContent>
                                <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                                    Максимальная цена
                                </Typography>
                                <Typography variant="h4" color="error" fontWeight="bold">
                                    {formatPrice(priceStatistics.maxPrice)}
                                </Typography>
                                <Typography variant="body2" color="text.secondary">
                                    {priceStatistics.maxPriceCategory}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                    
                    <Grid item xs={12} md={4}>
                        <Card sx={{ height: '100%', bgcolor: 'rgba(69, 39, 160, 0.05)', borderRadius: '8px' }}>
                            <CardContent>
                                <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                                    Минимальная цена
                                </Typography>
                                <Typography variant="h4" color="success.main" fontWeight="bold">
                                    {formatPrice(priceStatistics.minPrice)}
                                </Typography>
                                <Typography variant="body2" color="text.secondary">
                                    {priceStatistics.minPriceCategory}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                </Grid>
                
                <Box sx={{ mt: 3 }}>
                    <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                        Популярные категории
                    </Typography>
                    <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                        {priceStatistics.topCategories.map((category, index) => (
                            <Chip 
                                key={index}
                                label={`${category.name} (${formatPrice(category.averagePrice)})`}
                                onClick={() => navigate(`/searchByCategory/${category.id}`)}
                                color="primary"
                                variant="outlined"
                                clickable
                            />
                        ))}
                    </Box>
                </Box>
            </Paper>
        );
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
            py: 10,
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
                                mb: 2
                            }}
                        >
                            {t.mainTitle}
                        </Typography>
                        
                        <Typography 
                            variant="h5" 
                            sx={{ 
                                mb: 4,
                                fontWeight: 400
                            }}
                        >
                            {t.mainSubtitle}
                        </Typography>
                        
                        <Button 
                            variant="contained" 
                            size="large"
                            component={Link}
                            to="/categories"
                            startIcon={<AssessmentIcon />}
                            endIcon={<ArrowForwardIcon />}
                            sx={{ 
                                px: 4,
                                py: 1.5,
                                borderRadius: '8px',
                                textTransform: 'none',
                                fontSize: '1.1rem'
                            }}
                        >
                            {t.startEvaluation}
                        </Button>
                    </Grid>
                    
                    <Grid item xs={12} md={4}>
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
            <Typography variant="h4" component="h2" fontWeight="bold" mb={4}>
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
                                <Typography variant="h6">{t.descriptionSearch}</Typography>
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
        <Paper elevation={3} sx={{ p: 4, borderRadius: '12px', mb: 5, bgcolor: '#f8f9fa' }}>
            <Typography variant="h5" fontWeight="bold" gutterBottom>
                <MenuBookIcon sx={{ mr: 1, verticalAlign: 'middle' }} />
                {t.howItWorks}
            </Typography>
            
            <Typography variant="body1" paragraph sx={{ mb: 3 }}>
                {t.serviceDescription}
            </Typography>
            
            <Grid container spacing={3}>
                <Grid item xs={12} md={4}>
                    <Box sx={{ textAlign: 'center', p: 2 }}>
                        <SearchIcon fontSize="large" color="primary" />
                        <Typography variant="h6" gutterBottom>
                            {t.findAnalogs}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            {t.findAnalogsDesc}
                        </Typography>
                    </Box>
                </Grid>
                
                <Grid item xs={12} md={4}>
                    <Box sx={{ textAlign: 'center', p: 2 }}>
                        <AssessmentIcon fontSize="large" color="primary" />
                        <Typography variant="h6" gutterBottom>
                            {t.dataAnalysis}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            {t.dataAnalysisDesc}
                        </Typography>
                    </Box>
                </Grid>
                
                <Grid item xs={12} md={4}>
                    <Box sx={{ textAlign: 'center', p: 2 }}>
                        <PriceChangeIcon fontSize="large" color="primary" />
                        <Typography variant="h6" gutterBottom>
                            {t.getEstimate}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            {t.getEstimateDesc}
                        </Typography>
                    </Box>
                </Grid>
            </Grid>
            
            <Divider sx={{ my: 3 }} />
            
            <Typography variant="body1" sx={{ fontStyle: 'italic' }}>
                {t.subscriptionPromo}
                <Link to="/subscription" style={{ textDecoration: 'none', ml: 1 }}>
                    {t.getSubscription}
                </Link>.
            </Typography>
        </Paper>
    );

    // Основной UI компонент
    return (
        <Container maxWidth="xl" sx={{ pb: 4 }}>
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
