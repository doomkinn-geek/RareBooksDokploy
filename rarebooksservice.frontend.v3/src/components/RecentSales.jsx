import React, { useState, useEffect, useContext, useRef } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
    Button,
    Typography,
    CircularProgress,
    Card,
    CardContent,
    CardMedia,
    Box,
    Paper,
    Chip,
    Grid,
    Alert,
    useMediaQuery,
    useTheme
} from '@mui/material';
import Cookies from 'js-cookie';
import { getRecentSales } from '../api';
import { UserContext } from '../context/UserContext';
import { LanguageContext } from '../context/LanguageContext';
import HistoryIcon from '@mui/icons-material/History';

const RecentSales = () => {
    const { user } = useContext(UserContext);
    const { language } = useContext(LanguageContext);
    const navigate = useNavigate();
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    
    const [recentSales, setRecentSales] = useState([]);
    const [loadingRecentSales, setLoadingRecentSales] = useState(false);
    const [recentSalesError, setRecentSalesError] = useState(null);
    const isMounted = useRef(true);
    
    // Эффект для отслеживания монтирования компонента
    useEffect(() => {
        isMounted.current = true;
        
        // Загружаем данные о недавних продажах при монтировании компонента
        fetchRecentSales();
        
        return () => {
            isMounted.current = false;
        };
    }, []);
    
    // Функция для получения недавних продаж
    const fetchRecentSales = async () => {
        console.log('Вызвана функция fetchRecentSales в компоненте RecentSales');
        console.log('Состояние пользователя:', user);
        
        try {
            setLoadingRecentSales(true);
            setRecentSalesError(null);
            
            // Получаем токен аутентификации
            const token = Cookies.get('token');
            console.log('Токен аутентификации:', token ? 'Токен существует' : 'Токен отсутствует');
            
            // Используем импортированную функцию API
            console.log('Отправка запроса getRecentSales...');
            const response = await getRecentSales(5);
            console.log('Полученные данные о недавних продажах:', response.data);
            
            // Проверяем, смонтирован ли компонент перед обновлением состояния
            if (isMounted.current) {
                setRecentSales(response.data);
            }
        } catch (error) {
            console.error('Ошибка при загрузке недавних продаж:', error);
            console.error('Код ошибки:', error.response?.status);
            console.error('Сообщение ошибки:', error.response?.data?.message);
            
            // Проверяем, смонтирован ли компонент перед обновлением состояния
            if (isMounted.current) {
                setRecentSalesError(error.response?.data?.message || 'Ошибка при загрузке недавних продаж');
                setRecentSales([]);
            }
        } finally {
            // Проверяем, смонтирован ли компонент перед обновлением состояния
            if (isMounted.current) {
                setLoadingRecentSales(false);
            }
        }
    };
    
    // Обработчик ошибок при загрузке изображений
    const handleImageError = (e) => {
        e.target.onerror = null;
        e.target.src = 'https://via.placeholder.com/200x150?text=Нет+изображения';
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
    
    // Форматирование цены
    const formatPrice = (price) => {
        return new Intl.NumberFormat(language === 'RU' ? 'ru-RU' : 'en-US', {
            style: 'currency',
            currency: language === 'RU' ? 'RUB' : 'USD',
            maximumFractionDigits: 0
        }).format(price);
    };
    
    // Проверяем авторизацию пользователя
    if (!user) {
        console.log('Пользователь не авторизован. Компонент RecentSales не будет отображен.');
        return null;
    }
    
    return (
        <Paper elevation={2} sx={{ p: { xs: 2, sm: 3 }, borderRadius: '12px', mb: 3 }}>
            <Box sx={{ 
                display: 'flex', 
                flexDirection: { xs: 'column', sm: 'row' },
                justifyContent: 'space-between', 
                alignItems: { xs: 'flex-start', sm: 'center' }, 
                mb: 2,
                gap: { xs: 2, sm: 0 }
            }}>
                <Box sx={{ display: 'flex', alignItems: 'center' }}>
                    <HistoryIcon sx={{ mr: 1 }} color="primary" />
                    <Typography variant="h6" fontWeight="bold" sx={{ fontSize: { xs: '1.1rem', md: '1.25rem' } }}>
                        Недавние продажи
                    </Typography>
                </Box>
                
                {/* Кнопка для обновления данных */}
                <Button 
                    variant="outlined" 
                    size="small" 
                    onClick={fetchRecentSales}
                    fullWidth={isMobile}
                >
                    Обновить данные
                </Button>
            </Box>
            
            {!user.hasSubscription && (
                <Alert 
                    severity="warning" 
                    sx={{ mb: 2 }}
                    action={
                        <Button 
                            component={Link} 
                            to="/subscription" 
                            color="primary" 
                            size="small"
                            sx={{ ml: { xs: 0, sm: 1 }, mt: { xs: 1, sm: 0 } }}
                        >
                            Оформить подписку
                        </Button>
                    }
                >
                    Для просмотра недавних продаж требуется активная подписка.
                </Alert>
            )}
            
            {loadingRecentSales ? (
                <Box sx={{ display: 'flex', justifyContent: 'center', p: 3 }}>
                    <CircularProgress size={40} />
                </Box>
            ) : recentSalesError ? (
                <Alert severity="error" sx={{ mt: 2 }}>
                    {recentSalesError}
                </Alert>
            ) : recentSales && recentSales.length > 0 ? (
                <Grid container spacing={isMobile ? 1 : 2}>
                    {recentSales.map((book) => (
                        <Grid item xs={12} sm={6} md={4} key={book.bookId}>
                            <Card 
                                sx={{ 
                                    height: '100%', 
                                    borderRadius: '8px',
                                    transition: 'transform 0.2s ease, box-shadow 0.2s ease',
                                    '&:hover': {
                                        transform: 'translateY(-4px)',
                                        boxShadow: '0 8px 24px rgba(0,0,0,0.12)'
                                    },
                                    cursor: 'pointer',
                                    overflow: 'hidden',
                                    display: 'flex',
                                    flexDirection: 'column',
                                    width: '100%',
                                    maxWidth: '100%'
                                }}
                                onClick={() => navigate(`/books/${book.bookId}`)}
                                className="recent-sales-card"
                            >
                                {/* Контейнер для изображения с фиксированной высотой */}
                                <Box sx={{ 
                                    height: isMobile ? 120 : 140, 
                                    bgcolor: '#f5f5f5',
                                    display: 'flex',
                                    justifyContent: 'center',
                                    alignItems: 'center',
                                    overflow: 'hidden'
                                }}
                                className="book-image-container"
                                >
                                    {/* Изображения с обработчиком ошибок */}
                                    {book.imageUrl ? (
                                        <img
                                            src={book.imageUrl}
                                            alt={book.title}
                                            onError={handleImageError}
                                            style={{ 
                                                maxWidth: '100%',
                                                maxHeight: '100%',
                                                objectFit: 'contain'
                                            }}
                                        />
                                    ) : book.thumbnailUrl ? (
                                        <img
                                            src={book.thumbnailUrl}
                                            alt={book.title}
                                            onError={handleImageError}
                                            style={{ 
                                                maxWidth: '100%',
                                                maxHeight: '100%',
                                                objectFit: 'contain'
                                            }}
                                        />
                                    ) : (
                                        <Typography variant="body2" color="text.secondary">
                                            Нет изображения
                                        </Typography>
                                    )}
                                </Box>
                                <CardContent sx={{ p: isMobile ? 1.5 : 2 }}>
                                    <Typography 
                                        variant="subtitle1" 
                                        fontWeight="bold" 
                                        noWrap 
                                        title={book.title}
                                        sx={{ fontSize: { xs: '0.9rem', md: '1rem' } }}
                                    >
                                        {book.title}
                                    </Typography>
                                    <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                        <Chip 
                                            label={book.category || 'Без категории'} 
                                            size="small" 
                                            color="primary" 
                                            variant="outlined"
                                            sx={{ fontSize: '0.75rem' }}
                                        />
                                    </Box>
                                    <Typography 
                                        variant="body2" 
                                        color="text.secondary" 
                                        gutterBottom
                                        sx={{ fontSize: { xs: '0.75rem', md: '0.875rem' } }}
                                    >
                                        Дата продажи: {formatDate(book.saleDate)}
                                    </Typography>
                                    <Typography 
                                        variant="h6" 
                                        color="primary" 
                                        fontWeight="bold"
                                        sx={{ fontSize: { xs: '1rem', md: '1.25rem' } }}
                                    >
                                        {formatPrice(book.finalPrice || book.price)}
                                    </Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                    ))}
                </Grid>
            ) : (
                <Alert severity="info" sx={{ mt: 2 }}>
                    В настоящее время нет данных о недавних продажах. Попробуйте зайти позже.
                </Alert>
            )}
        </Paper>
    );
};

export default RecentSales; 