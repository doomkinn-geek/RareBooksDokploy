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
    useTheme,
    IconButton,
    Skeleton,
    Divider,
    Tooltip
} from '@mui/material';
import Cookies from 'js-cookie';
import { getRecentSales } from '../api';
import { UserContext } from '../context/UserContext';
import { LanguageContext } from '../context/LanguageContext';
import HistoryIcon from '@mui/icons-material/History';
import RefreshIcon from '@mui/icons-material/Refresh';
import BookmarkIcon from '@mui/icons-material/Bookmark';
import AttachMoneyIcon from '@mui/icons-material/AttachMoney';
import TodayIcon from '@mui/icons-material/Today';

const RecentSales = () => {
    const { user } = useContext(UserContext);
    const { language } = useContext(LanguageContext);
    const navigate = useNavigate();
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const isTablet = useMediaQuery(theme.breakpoints.down('md'));
    
    const [recentSales, setRecentSales] = useState([]);
    const [loadingRecentSales, setLoadingRecentSales] = useState(false);
    const [recentSalesError, setRecentSalesError] = useState(null);
    const [refreshing, setRefreshing] = useState(false);
    const isMounted = useRef(true);
    
    // Защита от ошибок: убедиться, что recentSales всегда массив
    useEffect(() => {
        if (!Array.isArray(recentSales)) {
            console.warn('recentSales не является массивом, сбрасываем в пустой массив');
            setRecentSales([]);
        }
    }, [recentSales]);
    
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
        
        try {
            setLoadingRecentSales(true);
            setRecentSalesError(null);
            setRefreshing(true);
            
            // Используем импортированную функцию API
            const response = await getRecentSales(5);
            console.log('Полученные данные о продажах:', response.data);
            
            // Проверяем, что данные являются массивом
            const salesData = Array.isArray(response.data) ? response.data : [];
            
            // Проверяем, смонтирован ли компонент перед обновлением состояния
            if (isMounted.current) {
                setRecentSales(salesData); // Устанавливаем массив или пустой массив
            }
        } catch (error) {
            console.error('Ошибка при загрузке недавних продаж:', error);
            
            // Проверяем, смонтирован ли компонент перед обновлением состояния
            if (isMounted.current) {
                setRecentSalesError(error.response?.data?.message || 'Ошибка при загрузке недавних продаж');
                setRecentSales([]); // Устанавливаем пустой массив при ошибке
            }
        } finally {
            // Проверяем, смонтирован ли компонент перед обновлением состояния
            if (isMounted.current) {
                setLoadingRecentSales(false);
                setTimeout(() => {
                    setRefreshing(false);
                }, 300);
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
        try {
            if (price === undefined || price === null) {
                console.warn('Цена не определена');
                return 'Цена неизвестна';
            }
            
            return new Intl.NumberFormat('ru-RU', {
                style: 'decimal',
                maximumFractionDigits: 0
            }).format(price) + ' ₽';
        } catch (error) {
            console.error('Ошибка форматирования цены:', error, price);
            return 'Ошибка цены';
        }
    };
    
    // Проверяем авторизацию пользователя
    if (!user) {
        console.log('Пользователь не авторизован. Компонент RecentSales не будет отображен.');
        return null;
    }
    
    // Компонент-скелетон для загрузки карточек
    const LoadingSkeleton = () => (
        <Grid container spacing={isMobile ? 1 : 2}>
            {[1, 2, 3].map((item) => (
                <Grid item xs={12} sm={6} md={4} key={item}>
                    <Card sx={{ height: '100%', borderRadius: '8px' }}>
                        <Skeleton variant="rectangular" height={isMobile ? 120 : 140} />
                        <CardContent>
                            <Skeleton variant="text" width="80%" height={24} />
                            <Skeleton variant="text" width="40%" height={20} sx={{ mt: 1 }} />
                            <Skeleton variant="text" width="60%" height={16} sx={{ mt: 1 }} />
                            <Skeleton variant="text" width="30%" height={30} sx={{ mt: 1 }} />
                        </CardContent>
                    </Card>
                </Grid>
            ))}
        </Grid>
    );
    
    return (
        <Paper 
            elevation={2} 
            sx={{ 
                p: { xs: 2, sm: 3 }, 
                borderRadius: '12px', 
                mb: 3,
                transition: 'all 0.3s ease'
            }}
            className="recent-sales-paper"
        >
            <Box sx={{ 
                display: 'flex', 
                flexDirection: { xs: 'column', sm: 'row' },
                justifyContent: 'space-between', 
                alignItems: { xs: 'flex-start', sm: 'center' }, 
                mb: 2,
                gap: { xs: 1.5, sm: 0 }
            }}>
                <Box sx={{ display: 'flex', alignItems: 'center', width: { xs: '100%', sm: 'auto' } }}>
                    <HistoryIcon 
                        sx={{ 
                            mr: 1, 
                            fontSize: { xs: '1.3rem', md: '1.5rem' } 
                        }} 
                        color="primary" 
                    />
                    <Typography 
                        variant="h6" 
                        fontWeight="bold" 
                        sx={{ 
                            fontSize: { xs: '1.1rem', md: '1.25rem' },
                            flex: 1
                        }}
                    >
                        Недавние продажи
                    </Typography>
                    
                    {/* Мобильная кнопка обновления */}
                    {isMobile && (
                        <Tooltip title="Обновить данные">
                            <IconButton 
                                color="primary" 
                                onClick={fetchRecentSales}
                                disabled={refreshing}
                                size="small"
                                sx={{ ml: 'auto' }}
                            >
                                <RefreshIcon 
                                    sx={{ 
                                        animation: refreshing ? 'spin 1s linear infinite' : 'none',
                                        '@keyframes spin': {
                                            '0%': { transform: 'rotate(0deg)' },
                                            '100%': { transform: 'rotate(360deg)' }
                                        }
                                    }} 
                                />
                            </IconButton>
                        </Tooltip>
                    )}
                </Box>
                
                {/* Кнопка для обновления данных - только для планшетов и десктопов */}
                {!isMobile && (
                    <Button 
                        variant="outlined" 
                        size="small" 
                        onClick={fetchRecentSales}
                        disabled={refreshing}
                        startIcon={
                            <RefreshIcon 
                                sx={{ 
                                    animation: refreshing ? 'spin 1s linear infinite' : 'none',
                                    '@keyframes spin': {
                                        '0%': { transform: 'rotate(0deg)' },
                                        '100%': { transform: 'rotate(360deg)' }
                                    }
                                }} 
                            />
                        }
                    >
                        Обновить данные
                    </Button>
                )}
            </Box>
            
            {!user.hasSubscription && (
                <Alert 
                    severity="warning" 
                    sx={{ 
                        mb: 2,
                        fontSize: { xs: '0.8rem', sm: '0.875rem' },
                        '& .MuiAlert-icon': {
                            fontSize: { xs: '1.2rem', sm: '1.5rem' }
                        }
                    }}
                    action={
                        <Button 
                            component={Link} 
                            to="/subscription" 
                            color="primary" 
                            size="small"
                            sx={{ 
                                ml: { xs: 0, sm: 1 }, 
                                mt: { xs: 1, sm: 0 },
                                fontSize: { xs: '0.7rem', sm: '0.8rem' }
                            }}
                        >
                            Оформить подписку
                        </Button>
                    }
                >
                    Для просмотра недавних продаж требуется активная подписка.
                </Alert>
            )}
            
            {loadingRecentSales && (!Array.isArray(recentSales) || recentSales.length === 0) ? (
                <LoadingSkeleton />
            ) : recentSalesError ? (
                <Alert 
                    severity="error" 
                    sx={{ 
                        mt: 2,
                        fontSize: { xs: '0.8rem', sm: '0.875rem' }
                    }}
                >
                    {recentSalesError}
                </Alert>
            ) : Array.isArray(recentSales) && recentSales.length > 0 ? (
                <Grid 
                    container 
                    spacing={isMobile ? 1 : 2}
                    sx={{ 
                        opacity: refreshing ? 0.7 : 1,
                        transition: 'opacity 0.3s ease'
                    }}
                >
                    {recentSales.map((book) => (
                        <Grid item xs={12} sm={6} md={4} key={book?.bookId || Math.random()}>
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
                                    maxWidth: '100%',
                                    position: 'relative'
                                }}
                                onClick={() => book?.bookId && navigate(`/books/${book.bookId}`)}
                                className="recent-sales-card"
                            >
                                {/* Контейнер для изображения с фиксированной высотой */}
                                <Box 
                                    sx={{ 
                                        height: isMobile ? 120 : 140, 
                                        bgcolor: '#f5f5f5',
                                        display: 'flex',
                                        justifyContent: 'center',
                                        alignItems: 'center',
                                        overflow: 'hidden',
                                        position: 'relative'
                                    }}
                                    className="book-image-container"
                                >
                                    {/* Изображения с обработчиком ошибок */}
                                    {book?.imageUrl ? (
                                        <img
                                            src={book.imageUrl}
                                            alt={book.title || 'Книга'}
                                            onError={handleImageError}
                                            style={{ 
                                                maxWidth: '100%',
                                                maxHeight: '100%',
                                                objectFit: 'contain'
                                            }}
                                        />
                                    ) : book?.thumbnailUrl ? (
                                        <img
                                            src={book.thumbnailUrl}
                                            alt={book.title || 'Книга'}
                                            onError={handleImageError}
                                            style={{ 
                                                maxWidth: '100%',
                                                maxHeight: '100%',
                                                objectFit: 'contain'
                                            }}
                                        />
                                    ) : (
                                        <img
                                            src="https://via.placeholder.com/200x150?text=Нет+изображения"
                                            alt="Нет изображения"
                                            style={{ 
                                                maxWidth: '100%',
                                                maxHeight: '100%',
                                                objectFit: 'contain'
                                            }}
                                        />
                                    )}
                                </Box>
                                
                                {/* Содержимое карточки */}
                                <CardContent sx={{ 
                                    p: isMobile ? 2 : 3,
                                    '&:last-child': { pb: isMobile ? 2 : 3 } 
                                }}>
                                    <Typography 
                                        variant="h6" 
                                        component="div" 
                                        sx={{ 
                                            mb: 1,
                                            fontSize: { xs: '0.9rem', sm: '1rem' },
                                            fontWeight: 'bold',
                                            lineHeight: 1.2,
                                            maxHeight: '2.4em',
                                            overflow: 'hidden',
                                            textOverflow: 'ellipsis',
                                            display: '-webkit-box',
                                            WebkitLineClamp: 2,
                                            WebkitBoxOrient: 'vertical'
                                        }}
                                    >
                                        {book?.title || 'Название отсутствует'}
                                    </Typography>
                                    
                                    {book?.category && (
                                        <Box sx={{ mb: 1 }}>
                                            <Chip 
                                                label={book.category} 
                                                size="small" 
                                                sx={{ fontSize: '0.7rem' }}
                                            />
                                        </Box>
                                    )}
                                    
                                    <Box sx={{ 
                                        display: 'flex', 
                                        alignItems: 'center', 
                                        mb: 0.5,
                                        fontSize: { xs: '0.75rem', sm: '0.8rem' },
                                        color: 'text.secondary'
                                    }}>
                                        <TodayIcon sx={{ fontSize: '0.9rem', mr: 0.5 }} />
                                        Продана: {formatDate(book?.saleDate)}
                                    </Box>
                                    
                                    <Box sx={{ 
                                        display: 'flex',
                                        justifyContent: 'space-between',
                                        alignItems: 'center',
                                        mt: 1
                                    }}>
                                        <Typography 
                                            variant="h6" 
                                            color="primary"
                                            sx={{ 
                                                fontWeight: 'bold',
                                                display: 'flex',
                                                alignItems: 'center',
                                                fontSize: { xs: '1rem', sm: '1.1rem' }
                                            }}
                                        >
                                            <AttachMoneyIcon sx={{ 
                                                fontSize: { xs: '1.1rem', sm: '1.2rem' },
                                                mr: 0.3
                                            }} />
                                            Цена: {formatPrice(book?.finalPrice || 0)}
                                        </Typography>
                                    </Box>
                                </CardContent>
                            </Card>
                        </Grid>
                    ))}
                </Grid>
            ) : (
                <Alert 
                    severity="info" 
                    sx={{ 
                        mt: 2,
                        fontSize: { xs: '0.8rem', sm: '0.875rem' }
                    }}
                >
                    В настоящее время нет данных о недавних продажах. Попробуйте зайти позже.
                </Alert>
            )}
        </Paper>
    );
};

export default RecentSales; 