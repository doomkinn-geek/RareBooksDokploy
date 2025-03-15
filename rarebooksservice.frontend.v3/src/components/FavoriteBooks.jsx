import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { 
    Container, 
    Typography, 
    Box, 
    Pagination,
    CircularProgress,
    IconButton,
    Tooltip,
    Alert,
    List,
    ListItem,
    ListItemText,
    ListItemSecondaryAction,
    Paper,
    Divider,
    Avatar
} from '@mui/material';
import { getFavoriteBooks, removeBookFromFavorites, getBookImages, getBookImageFile } from '../api';
import DeleteIcon from '@mui/icons-material/Delete';
import Cookies from 'js-cookie';
import BookIcon from '@mui/icons-material/Book';
import FavoriteIcon from '@mui/icons-material/Favorite';

const FavoriteBooks = () => {
    const navigate = useNavigate();
    const [books, setBooks] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [page, setPage] = useState(1);
    const [totalPages, setTotalPages] = useState(1);
    const [removingIds, setRemovingIds] = useState([]);
    const [bookImages, setBookImages] = useState({});

    useEffect(() => {
        const fetchFavoriteBooks = async () => {
            try {
                // Проверяем, авторизован ли пользователь
                const token = Cookies.get('token');
                if (!token) {
                    navigate('/login', { state: { from: '/favorites' } });
                    return;
                }

                setLoading(true);
                const response = await getFavoriteBooks(page, 15);
                const fetchedBooks = response.data.items || [];
                console.log('Полученные данные о книгах:', fetchedBooks);
                setBooks(fetchedBooks);
                setTotalPages(response.data.totalPages || 1);
                setError(null);
            } catch (error) {
                console.error('Ошибка при загрузке избранных книг:', error);
                setError('Не удалось загрузить избранные книги. Пожалуйста, попробуйте позже.');
            } finally {
                setLoading(false);
            }
        };

        fetchFavoriteBooks();
    }, [page, navigate]);

    // Загрузка изображений книг
    useEffect(() => {
        const loadBookImages = async () => {
            for (const book of books) {
                if (!book || !book.id) continue;
                
                try {
                    // Получаем список изображений для книги
                    const imagesResponse = await getBookImages(book.id);
                    const imageNames = imagesResponse?.data?.images || [];
                    
                    // Если есть хотя бы одно изображение
                    if (imageNames.length > 0) {
                        const firstImageName = imageNames[0];
                        
                        // Загружаем первое изображение
                        const imageResponse = await getBookImageFile(book.id, firstImageName);
                        const imageUrl = URL.createObjectURL(imageResponse.data);
                        
                        // Сохраняем URL изображения в состоянии
                        setBookImages(prev => ({
                            ...prev,
                            [book.id]: imageUrl
                        }));
                    }
                } catch (error) {
                    console.error(`Ошибка при загрузке изображения для книги ${book.id}:`, error);
                }
            }
        };

        if (books.length > 0) {
            loadBookImages();
        }

        // Очистка URL объектов при размонтировании компонента
        return () => {
            Object.values(bookImages).forEach(url => {
                if (url && typeof url === 'string' && url.startsWith('blob:')) {
                    URL.revokeObjectURL(url);
                }
            });
        };
    }, [books]);

    const handlePageChange = (event, value) => {
        setPage(value);
    };

    const handleRemoveFromFavorites = async (bookId, event) => {
        event.preventDefault();
        event.stopPropagation();

        try {
            setRemovingIds(prev => [...prev, bookId]);
            await removeBookFromFavorites(bookId);
            setBooks(books.filter(book => book.id !== bookId));
        } catch (error) {
            console.error('Ошибка при удалении книги из избранного:', error);
        } finally {
            setRemovingIds(prev => prev.filter(id => id !== bookId));
        }
    };

    const formatPrice = (price) => {
        if (price === undefined || price === null) return 'Нет данных';
        try {
            return `${Number(price).toLocaleString()} ₽`;
        } catch (error) {
            return `${price} ₽`;
        }
    };

    // Форматирование даты добавления в избранное
    const formatDate = (dateString) => {
        try {
            if (!dateString) return 'Нет данных';
            
            const date = new Date(dateString);
            
            // Проверка валидности даты
            if (isNaN(date.getTime())) {
                return 'Некорректная дата';
            }
            
            return new Intl.DateTimeFormat('ru-RU', {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            }).format(date);
        } catch (error) {
            console.error('Ошибка при форматировании даты:', error);
            return 'Некорректная дата';
        }
    };

    return (
        <Container maxWidth="md" sx={{ 
            py: { xs: 2, md: 3 },
            px: { xs: 1.5, sm: 2, md: 3 } // Уменьшаем горизонтальные отступы на мобильных
        }}>
            <Box sx={{ 
                display: 'flex', 
                alignItems: 'center', 
                mb: { xs: 2, md: 3 },
                flexWrap: 'wrap'  // Позволяет перенос на мобильных
            }}>
                <FavoriteIcon sx={{ 
                    color: '#d32f2f', 
                    mr: 2, 
                    fontSize: { xs: '1.5rem', md: '2rem' } 
                }} />
                <Typography variant="h5" component="h1" fontWeight="bold" sx={{
                    fontSize: { xs: '1.25rem', md: '1.5rem' }
                }}>
                    Избранные книги
                </Typography>
            </Box>

            {loading ? (
                <Box sx={{ display: 'flex', justifyContent: 'center', my: 5 }}>
                    <CircularProgress sx={{ color: '#d32f2f' }} />
                </Box>
            ) : (
                <>
                    {error && (
                        <Alert severity="error" sx={{ mb: 4 }}>
                            {error}
                        </Alert>
                    )}

                    {books.length === 0 ? (
                        <Alert severity="info" sx={{ mb: 4 }}>
                            У вас пока нет избранных книг.
                        </Alert>
                    ) : (
                        <>
                            <Paper elevation={2} sx={{ mb: 4, borderRadius: '8px', overflow: 'hidden' }}>
                                <List sx={{ width: '100%', bgcolor: 'background.paper', p: 0 }}>
                                    {books.map((book, index) => (
                                        <React.Fragment key={book.id}>
                                            {index > 0 && <Divider component="li" />}
                                            <ListItem 
                                                component={Link} 
                                                to={`/books/${book.id}`}
                                                sx={{ 
                                                    textDecoration: 'none', 
                                                    color: 'inherit',
                                                    '&:hover': {
                                                        bgcolor: 'rgba(211, 47, 47, 0.05)'
                                                    },
                                                    paddingRight: '56px', // Пространство для кнопки удаления
                                                    paddingY: { xs: 2, md: 2.5 } // Увеличиваем высоту элемента для большей картинки
                                                }}
                                            >
                                                {bookImages[book.id] ? (
                                                    // Если есть изображение - отображаем его
                                                    <Box
                                                        sx={{
                                                            position: 'relative',
                                                            width: { xs: 80, sm: 90, md: 110 }, // Увеличиваем размер для лучшей видимости
                                                            height: { xs: 100, sm: 115, md: 140 }, // Делаем высоту больше для лучшего отображения обложек
                                                            mr: { xs: 1.5, sm: 2, md: 3 }, // Уменьшаем отступ справа на мобильных
                                                            overflow: 'visible',
                                                            flexShrink: 0, // Предотвращаем сжатие изображения
                                                            '&:hover .book-image': {
                                                                transform: {
                                                                    xs: 'scale(1.7)', // Меньший масштаб на мобильных для предотвращения выхода за границы экрана
                                                                    sm: 'scale(2)'
                                                                },
                                                                zIndex: 10,
                                                                boxShadow: '0 6px 12px rgba(0,0,0,0.15)'
                                                            }
                                                        }}
                                                    >
                                                        <Avatar 
                                                            className="book-image"
                                                            src={bookImages[book.id]} 
                                                            alt={book.title || 'Обложка книги'}
                                                            variant="rounded"
                                                            sx={{ 
                                                                width: '100%', 
                                                                height: '100%', 
                                                                border: '1px solid #eee',
                                                                borderRadius: '8px',
                                                                boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
                                                                transition: 'transform 0.3s ease, box-shadow 0.3s ease',
                                                                transformOrigin: 'left center',
                                                                objectFit: 'cover' // Улучшаем отображение изображения
                                                            }}
                                                        />
                                                    </Box>
                                                ) : (
                                                    // Если нет изображения - отображаем иконку книги
                                                    <Box
                                                        sx={{
                                                            position: 'relative',
                                                            width: { xs: 80, sm: 90, md: 110 }, // Увеличиваем размер для лучшей видимости
                                                            height: { xs: 100, sm: 115, md: 140 }, // Делаем высоту больше для лучшего отображения обложек
                                                            mr: { xs: 1.5, sm: 2, md: 3 }, // Уменьшаем отступ справа на мобильных
                                                            overflow: 'visible',
                                                            flexShrink: 0, // Предотвращаем сжатие изображения
                                                            '&:hover .book-image': {
                                                                transform: {
                                                                    xs: 'scale(1.7)', // Меньший масштаб на мобильных для предотвращения выхода за границы экрана
                                                                    sm: 'scale(2)'
                                                                },
                                                                zIndex: 10,
                                                                boxShadow: '0 6px 12px rgba(0,0,0,0.15)'
                                                            }
                                                        }}
                                                    >
                                                        <Avatar
                                                            className="book-image"
                                                            variant="rounded"
                                                            sx={{ 
                                                                width: '100%', 
                                                                height: '100%', 
                                                                bgcolor: '#f5f5f5',
                                                                borderRadius: '8px',
                                                                boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
                                                                transition: 'transform 0.3s ease, box-shadow 0.3s ease',
                                                                transformOrigin: 'left center'
                                                            }}
                                                        >
                                                            <BookIcon sx={{ color: '#d32f2f', fontSize: { xs: 36, sm: 40, md: 48 } }} />
                                                        </Avatar>
                                                    </Box>
                                                )}
                                                <ListItemText 
                                                    primary={
                                                        <Typography 
                                                            variant="subtitle1" 
                                                            sx={{ 
                                                                fontWeight: 'bold',
                                                                color: '#333',
                                                                '&:hover': { color: '#d32f2f' },
                                                                fontSize: { xs: '0.9rem', sm: '1rem', md: '1.1rem' },
                                                                lineHeight: 1.3,
                                                                mb: 0.5,
                                                                // Ограничиваем количество строк (для длинных названий)
                                                                display: '-webkit-box',
                                                                WebkitLineClamp: 2,
                                                                WebkitBoxOrient: 'vertical',
                                                                overflow: 'hidden',
                                                                textOverflow: 'ellipsis'
                                                            }}
                                                        >
                                                            {book.title || 'Без названия'}
                                                        </Typography>
                                                    }
                                                    secondary={
                                                        <Box sx={{ 
                                                            display: 'flex', 
                                                            flexDirection: 'column',
                                                            gap: 0.5
                                                        }}>
                                                            <Typography 
                                                                variant="body2" 
                                                                color="text.secondary" 
                                                                component="span"
                                                                sx={{ 
                                                                    fontSize: { xs: '0.75rem', sm: '0.8rem' },
                                                                    lineHeight: 1.2
                                                                }}
                                                            >
                                                                Добавлено: {formatDate(book.addedDate)}
                                                            </Typography>
                                                            {book.finalPrice && (
                                                                <Typography 
                                                                    variant="body2" 
                                                                    component="span" 
                                                                    sx={{ 
                                                                        color: '#d32f2f', 
                                                                        fontWeight: 'bold',
                                                                        fontSize: { xs: '0.85rem', sm: '0.9rem' }
                                                                    }}
                                                                >
                                                                    {formatPrice(book.finalPrice || book.price)}
                                                                </Typography>
                                                            )}
                                                        </Box>
                                                    }
                                                />
                                                <ListItemSecondaryAction>
                                                    <Tooltip title="Удалить из избранного">
                                                        <IconButton
                                                            edge="end"
                                                            onClick={(e) => handleRemoveFromFavorites(book.id, e)}
                                                            disabled={removingIds.includes(book.id)}
                                                            size="small"
                                                            sx={{ color: '#d32f2f' }}
                                                        >
                                                            {removingIds.includes(book.id) ? (
                                                                <CircularProgress size={20} color="inherit" />
                                                            ) : (
                                                                <DeleteIcon />
                                                            )}
                                                        </IconButton>
                                                    </Tooltip>
                                                </ListItemSecondaryAction>
                                            </ListItem>
                                        </React.Fragment>
                                    ))}
                                </List>
                            </Paper>

                            {totalPages > 1 && (
                                <Box sx={{ display: 'flex', justifyContent: 'center', mt: 2 }}>
                                    <Pagination 
                                        count={totalPages} 
                                        page={page} 
                                        onChange={handlePageChange} 
                                        color="primary" 
                                        sx={{
                                            '& .MuiPaginationItem-root.Mui-selected': {
                                                backgroundColor: '#d32f2f',
                                                color: 'white',
                                                '&:hover': {
                                                    backgroundColor: '#b71c1c'
                                                }
                                            }
                                        }}
                                    />
                                </Box>
                            )}
                        </>
                    )}
                </>
            )}
        </Container>
    );
};

export default FavoriteBooks; 