// src/components/BookList.jsx
import React, { useEffect, useState } from 'react';
import { 
    Card, 
    CardContent, 
    Typography, 
    Box, 
    Button, 
    Pagination, 
    Grid, 
    Chip,
    Paper,
    Divider,
    CircularProgress,
    Container,
    useTheme,
    IconButton,
    Tooltip,
    Alert
} from '@mui/material';
import { useNavigate, Link } from 'react-router-dom';
import axios from 'axios';
import { API_URL, getAuthHeaders, checkIfBookIsFavorite, addBookToFavorites, removeBookFromFavorites } from '../api';
import Cookies from 'js-cookie';

// Импорт иконок
import BookIcon from '@mui/icons-material/Book';
import CategoryIcon from '@mui/icons-material/Category';
import StoreIcon from '@mui/icons-material/Store';
import AttachMoneyIcon from '@mui/icons-material/AttachMoney';
import DateRangeIcon from '@mui/icons-material/DateRange';
import InfoIcon from '@mui/icons-material/Info';
import FavoriteIcon from '@mui/icons-material/Favorite';
import FavoriteBorderIcon from '@mui/icons-material/FavoriteBorder';

function getBookImageFile(id, imageName) {
    return axios.get(`${API_URL}/books/${id}/images/${imageName}`, {
        headers: getAuthHeaders(),
        responseType: 'blob',
    });
}

const BookList = ({ books, totalPages, currentPage, setCurrentPage }) => {
    const navigate = useNavigate();
    const theme = useTheme();

    const [thumbnails, setThumbnails] = useState({});
    const [error, setError] = useState('');
    const [showSubscriptionCTA, setShowSubscriptionCTA] = useState(false);
    const [loading, setLoading] = useState(false);
    const [favoriteBooks, setFavoriteBooks] = useState({});
    const [favoritesLoading, setFavoritesLoading] = useState({});

    useEffect(() => {
        if (!books || books.length === 0) {
            setThumbnails({});
            setError('');
            setShowSubscriptionCTA(false);
            return;
        }

        setThumbnails({});
        setError('');
        setLoading(true);

        // Проверяем, есть ли среди книг дата "Только для подписчиков"
        const hasPaidOnlyBooks = books.some((book) => book.date === 'Только для подписчиков');
        setShowSubscriptionCTA(hasPaidOnlyBooks);

        // Параллельная загрузка изображений
        books.forEach(async (book) => {
            if (book.firstImageName) {
                try {
                    const response = await getBookImageFile(book.id, book.firstImageName);
                    const imageUrl = URL.createObjectURL(response.data);
                    
                    // Обновляем thumbnails для каждой книги сразу после загрузки
                    setThumbnails(prev => ({
                        ...prev,
                        [book.id]: imageUrl
                    }));
                } catch (error) {
                    console.error(`Ошибка при загрузке изображения для книги ${book.id}:`, error);
                    // В случае ошибки продолжаем работу
                }
            }
        });

        // Отмечаем, что основная загрузка завершена
        setLoading(false);

        // Очистка URL объектов при размонтировании
        return () => {
            Object.values(thumbnails).forEach(url => {
                if (url && typeof url === 'string' && url.startsWith('blob:')) {
                    URL.revokeObjectURL(url);
                }
            });
        };
    }, [books]);

    // Проверка статуса избранных книг
    useEffect(() => {
        const checkFavorites = async () => {
            // Проверяем, авторизован ли пользователь
            const token = Cookies.get('token');
            if (!token || !books || books.length === 0) return;

            try {
                // Проверяем статус избранного для каждой книги
                books.forEach(async (book) => {
                    try {
                        const response = await checkIfBookIsFavorite(book.id);
                        setFavoriteBooks(prev => ({
                            ...prev,
                            [book.id]: response.data
                        }));
                    } catch (error) {
                        console.error(`Ошибка при проверке статуса избранного для книги ${book.id}:`, error);
                    }
                });
            } catch (error) {
                console.error('Ошибка при проверке статуса избранных книг:', error);
            }
        };

        checkFavorites();
    }, [books]);

    // Форматирование даты в удобный для чтения вид
    const formatDate = (dateString) => {
        if (!dateString) return 'Нет данных';
        if (dateString === 'Только для подписчиков') return dateString;
        
        // Проверяем, если дата в формате ДД.ММ.ГГГГ
        if (typeof dateString === 'string' && dateString.match(/^\d{2}\.\d{2}\.\d{4}$/)) {
            // Разбиваем строку на день, месяц и год
            const [day, month, year] = dateString.split('.');
            // Создаем дату из компонентов для корректного форматирования
            const date = new Date(`${year}-${month}-${day}`);
            
            if (!isNaN(date.getTime())) {
                return date.toLocaleDateString('ru-RU', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                });
            }
            // Если преобразование не удалось, возвращаем как есть
            return dateString;
        }
        
        try {
            const date = new Date(dateString);
            if (isNaN(date.getTime())) {
                return dateString; // Возвращаем исходную строку если дата невалидна
            }
            return date.toLocaleDateString('ru-RU', {
                year: 'numeric',
                month: 'long',
                day: 'numeric'
            });
        } catch (error) {
            return dateString;
        }
    };

    // Обработка клика по книге
    const handleBookClick = (bookId) => {
        navigate(`/books/${bookId}`);
    };

    // Обработка добавления/удаления книги из избранного
    const handleToggleFavorite = async (bookId, event) => {
        event.stopPropagation();
        
        // Проверяем, авторизован ли пользователь
        const token = Cookies.get('token');
        if (!token) {
            navigate('/login', { state: { from: window.location.pathname } });
            return;
        }

        try {
            setFavoritesLoading(prev => ({
                ...prev,
                [bookId]: true
            }));

            const isFavorite = favoriteBooks[bookId];

            if (isFavorite) {
                // Удаляем из избранного
                await removeBookFromFavorites(bookId);
                setFavoriteBooks(prev => ({
                    ...prev,
                    [bookId]: false
                }));
            } else {
                // Добавляем в избранное
                await addBookToFavorites(bookId);
                setFavoriteBooks(prev => ({
                    ...prev,
                    [bookId]: true
                }));
            }
        } catch (error) {
            console.error('Ошибка при изменении статуса избранного:', error);
        } finally {
            setFavoritesLoading(prev => ({
                ...prev,
                [bookId]: false
            }));
        }
    };

    // Обработка изменения страницы
    const handlePageChange = (event, value) => {
        setCurrentPage(value);
    };

    // Компонент для отображения пагинации
    const renderPagination = () => (
        <Box sx={{ 
            display: 'flex', 
            justifyContent: 'center', 
            mt: 4, 
            mb: 4,
            '& .MuiPagination-ul': {
                '& .MuiPaginationItem-root': {
                    fontSize: '1rem',
                    minWidth: '36px',
                    height: '36px',
                    borderRadius: '50%',
                    transition: 'all 0.2s',
                    '&.Mui-selected': {
                        fontWeight: 'bold',
                        backgroundColor: theme.palette.primary.main,
                        color: 'white',
                        '&:hover': {
                            backgroundColor: theme.palette.primary.dark,
                        }
                    },
                    '&:hover': {
                        backgroundColor: 'rgba(69, 39, 160, 0.08)',
                    }
                }
            }
        }}>
            <Pagination
                count={totalPages}
                page={currentPage}
                onChange={handlePageChange}
                color="primary"
                size="large"
                showFirstButton
                showLastButton
                siblingCount={1}
                boundaryCount={1}
            />
        </Box>
    );

    if (loading && books.length === 0) {
        return (
            <Box sx={{ display: 'flex', justifyContent: 'center', p: 5 }}>
                <CircularProgress size={60} thickness={4} sx={{ color: theme.palette.primary.main }} />
            </Box>
        );
    }

    return (
        <Container maxWidth="xl">
            <Box sx={{ my: 3 }} className="fade-in">
                {error && (
                    <Alert severity="error" sx={{ mb: 3, borderRadius: '8px' }}>
                        {error}
                    </Alert>
                )}

                {/* Если есть книги, доступные только по подписке, показываем CTA */}
                {showSubscriptionCTA && (
                    <Paper 
                        elevation={3} 
                        sx={{
                            p: 3,
                            mb: 4,
                            borderRadius: '12px',
                            bgcolor: 'rgba(255, 171, 0, 0.1)',
                            border: '1px solid rgba(255, 171, 0, 0.3)'
                        }}
                    >
                        <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                            <InfoIcon sx={{ mr: 1, color: theme.palette.secondary.main }} />
                            <Typography variant="h6" sx={{ color: theme.palette.secondary.dark, fontWeight: 'bold' }}>
                                Данные о ценах, датах и изображения доступны только по подписке
                            </Typography>
                        </Box>
                        <Typography variant="body1" sx={{ mb: 2 }}>
                            Чтобы увидеть полную информацию по этим книгам и получить доступ к инструментам оценки стоимости, оформите подписку.
                        </Typography>
                        <Button
                            variant="contained"
                            color="secondary"
                            onClick={() => navigate('/subscription')}
                            sx={{ 
                                borderRadius: '8px', 
                                textTransform: 'none', 
                                fontWeight: 'bold',
                                px: 3,
                                py: 1
                            }}
                        >
                            Оформить подписку
                        </Button>
                    </Paper>
                )}

                {books.length > 0 && (
                    <Typography 
                        variant="h5" 
                        component="h1" 
                        sx={{ 
                            mb: 3, 
                            fontWeight: 'bold',
                            color: theme.palette.primary.dark,
                            borderLeft: `4px solid ${theme.palette.primary.main}`,
                            pl: 2
                        }}
                    >
                        Найдено книг: {books.length}
                    </Typography>
                )}

                {books.length > 0 && renderPagination()}

                <Grid container spacing={3}>
                    {books.map((book) => (
                        <Grid item xs={12} key={book.id}>
                            <Card 
                                sx={{
                                    borderRadius: '12px',
                                    overflow: 'hidden',
                                    transition: 'transform 0.2s ease, box-shadow 0.2s ease',
                                    boxShadow: '0 4px 12px rgba(0,0,0,0.08)',
                                    '&:hover': {
                                        transform: 'translateY(-4px)',
                                        boxShadow: '0 8px 24px rgba(0,0,0,0.12)'
                                    },
                                    position: 'relative'
                                }}
                            >
                                {/* Кнопка добавления в избранное */}
                                <Tooltip title={favoriteBooks[book.id] ? "Удалить из избранного" : "Добавить в избранное"}>
                                    <IconButton
                                        sx={{
                                            position: 'absolute',
                                            top: 8,
                                            right: 8,
                                            zIndex: 10,
                                            backgroundColor: 'rgba(255, 255, 255, 0.8)',
                                            '&:hover': {
                                                backgroundColor: 'rgba(255, 255, 255, 0.9)'
                                            }
                                        }}
                                        onClick={(e) => handleToggleFavorite(book.id, e)}
                                        disabled={favoritesLoading[book.id]}
                                    >
                                        {favoritesLoading[book.id] ? (
                                            <CircularProgress size={24} />
                                        ) : favoriteBooks[book.id] ? (
                                            <FavoriteIcon sx={{ color: 'red' }} />
                                        ) : (
                                            <FavoriteBorderIcon />
                                        )}
                                    </IconButton>
                                </Tooltip>
                                <CardContent sx={{ p: 0 }}>
                                    <Grid container>
                                        {/* Изображение книги */}
                                        <Grid item xs={12} sm={3} md={2} 
                                            sx={{ 
                                                bgcolor: '#f5f5f5',
                                                display: 'flex',
                                                alignItems: 'center',
                                                justifyContent: 'center',
                                                cursor: 'pointer',
                                                minHeight: '200px',
                                                position: 'relative'
                                            }}
                                            onClick={() => handleBookClick(book.id)}
                                        >
                                            {book.firstImageName && thumbnails[book.id] ? (
                                                <img
                                                    src={thumbnails[book.id]}
                                                    alt={book.title}
                                                    style={{
                                                        width: '100%',
                                                        height: '100%',
                                                        objectFit: 'contain',
                                                        maxHeight: '200px',
                                                        padding: '12px'
                                                    }}
                                                />
                                            ) : (
                                                <Box sx={{ 
                                                    p: 3, 
                                                    height: '100%', 
                                                    width: '100%',
                                                    display: 'flex', 
                                                    flexDirection: 'column',
                                                    alignItems: 'center', 
                                                    justifyContent: 'center',
                                                    backgroundColor: 'rgba(69, 39, 160, 0.05)'
                                                }}>
                                                    {book.firstImageName ? (
                                                        // Индикатор загрузки, если изображение загружается
                                                        <React.Fragment>
                                                            <CircularProgress 
                                                                size={50} 
                                                                sx={{ 
                                                                    color: theme.palette.primary.main,
                                                                    mb: 1 
                                                                }} 
                                                            />
                                                            <Typography variant="body2" color="text.secondary" align="center">
                                                                Загрузка изображения...
                                                            </Typography>
                                                        </React.Fragment>
                                                    ) : (
                                                        // Если у книги вообще нет изображения
                                                        <React.Fragment>
                                                            <BookIcon sx={{ fontSize: 60, color: 'rgba(69, 39, 160, 0.2)', mb: 1 }} />
                                                            <Typography variant="body2" color="text.secondary" align="center">
                                                                Изображение отсутствует
                                                            </Typography>
                                                        </React.Fragment>
                                                    )}
                                                </Box>
                                            )}
                                        </Grid>
                                        
                                        {/* Информация о книге */}
                                        <Grid item xs={12} sm={9} md={10}>
                                            <Box sx={{ p: 3 }}>
                                                <Typography 
                                                    variant="h5" 
                                                    component="h2"
                                                    fontWeight="bold"
                                                    sx={{ 
                                                        mb: 1,
                                                        cursor: 'pointer',
                                                        color: theme.palette.primary.dark,
                                                        '&:hover': { color: theme.palette.primary.main },
                                                        transition: 'color 0.2s'
                                                    }}
                                                    onClick={() => handleBookClick(book.id)}
                                                >
                                                    {book.title}
                                                </Typography>
                                                
                                                <Grid container spacing={2} sx={{ mb: 2 }}>
                                                    <Grid item xs={12} md={8}>
                                                        <Typography 
                                                            variant="body1" 
                                                            color="text.secondary" 
                                                            paragraph
                                                            sx={{ 
                                                                mb: 2,
                                                                lineHeight: 1.6
                                                            }}
                                                        >
                                                            {book.description && book.description.length > 150 
                                                                ? `${book.description.substring(0, 150)}...` 
                                                                : book.description}
                                                        </Typography>
                                                        
                                                        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1, mb: 2 }}>
                                                            {book.categoryName && (
                                                                <Chip 
                                                                    icon={<CategoryIcon />}
                                                                    label={book.categoryName} 
                                                                    size="small" 
                                                                    variant="outlined"
                                                                    color="primary"
                                                                    sx={{ 
                                                                        borderRadius: '16px',
                                                                        '& .MuiChip-label': { fontWeight: 500 }
                                                                    }}
                                                                />
                                                            )}
                                                            {book.type && (
                                                                <Chip 
                                                                    label={book.type} 
                                                                    size="small" 
                                                                    variant="outlined"
                                                                    sx={{ 
                                                                        borderRadius: '16px',
                                                                        '& .MuiChip-label': { fontWeight: 500 }
                                                                    }}
                                                                />
                                                            )}
                                                            {book.sellerName && (
                                                                <Chip 
                                                                    icon={<StoreIcon />}
                                                                    label={book.sellerName}
                                                                    size="small" 
                                                                    variant="outlined"
                                                                    color="secondary" 
                                                                    component={Link}
                                                                    to={`/searchBySeller/${book.sellerName}`}
                                                                    clickable
                                                                    sx={{ 
                                                                        borderRadius: '16px',
                                                                        '& .MuiChip-label': { fontWeight: 500 }
                                                                    }}
                                                                />
                                                            )}
                                                        </Box>
                                                    </Grid>
                                                    
                                                    <Grid item xs={12} md={4}>
                                                        <Paper 
                                                            elevation={0}
                                                            sx={{ 
                                                                p: 2, 
                                                                bgcolor: 'rgba(69, 39, 160, 0.05)', 
                                                                borderRadius: '8px',
                                                                height: '100%',
                                                                display: 'flex',
                                                                flexDirection: 'column',
                                                                justifyContent: 'center'
                                                            }}
                                                        >
                                                            <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                                                <AttachMoneyIcon sx={{ mr: 1, color: theme.palette.primary.main }} />
                                                                <Typography variant="body1" fontWeight="medium">
                                                                    Цена: 
                                                                    <span style={{ 
                                                                        color: theme.palette.primary.dark, 
                                                                        fontWeight: 'bold',
                                                                        marginLeft: '8px'
                                                                    }}>
                                                                        {book.price === 'Только для подписчиков' 
                                                                            ? 'Только для подписчиков' 
                                                                            : book.price ? `${book.price} ₽` : 'Нет данных'}
                                                                    </span>
                                                                </Typography>
                                                            </Box>

                                                            <Box sx={{ display: 'flex', alignItems: 'center' }}>
                                                                <DateRangeIcon sx={{ mr: 1, color: theme.palette.primary.main }} />
                                                                <Typography variant="body1" fontWeight="medium">
                                                                    Дата: 
                                                                    <span style={{ 
                                                                        color: theme.palette.primary.dark, 
                                                                        fontWeight: 'bold',
                                                                        marginLeft: '8px'
                                                                    }}>
                                                                        {formatDate(book.date)}
                                                                    </span>
                                                                </Typography>
                                                            </Box>
                                                        </Paper>
                                                    </Grid>
                                                </Grid>

                                                <Box sx={{ display: 'flex', justifyContent: 'flex-end', mt: 2 }}>
                                                    <Box sx={{ display: 'flex', justifyContent: 'space-between', width: '100%', alignItems: 'center' }}>
                                                        <Box>
                                                            {favoriteBooks[book.id] && (
                                                                <Chip
                                                                    icon={<FavoriteIcon sx={{ color: 'red !important' }} />}
                                                                    label="В избранном"
                                                                    variant="outlined"
                                                                    size="small"
                                                                    sx={{ 
                                                                        borderColor: 'red',
                                                                        color: 'red',
                                                                        mr: 1
                                                                    }}
                                                                />
                                                            )}
                                                        </Box>
                                                        <Button
                                                            variant="contained"
                                                            color="primary"
                                                            onClick={() => handleBookClick(book.id)}
                                                            sx={{ 
                                                                borderRadius: '8px', 
                                                                textTransform: 'none',
                                                                fontWeight: 'bold',
                                                                px: 3
                                                            }}
                                                        >
                                                            Подробнее
                                                        </Button>
                                                    </Box>
                                                </Box>
                                            </Box>
                                        </Grid>
                                    </Grid>
                                </CardContent>
                            </Card>
                        </Grid>
                    ))}
                </Grid>

                {books.length > 0 && renderPagination()}
            </Box>
        </Container>
    );
};

export default BookList;
