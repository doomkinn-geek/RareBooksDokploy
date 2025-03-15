import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { 
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
    Divider,
    Avatar
} from '@mui/material';
import { getFavoriteBooks, removeBookFromFavorites, getBookImages, getBookImageFile } from '../api';
import DeleteIcon from '@mui/icons-material/Delete';
import BookIcon from '@mui/icons-material/Book';

// Адаптированная версия компонента FavoriteBooks для использования во вкладках профиля пользователя
const UserFavoriteBooks = ({ userId, isCurrentUser, height }) => {
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
                setLoading(true);
                const response = await getFavoriteBooks(page, 10);
                setBooks(response.data.items || []);
                setTotalPages(response.data.totalPages || 1);
                setError(null);
            } catch (error) {
                console.error('Ошибка при загрузке избранных книг:', error);
                setError('Не удалось загрузить избранные книги. Пожалуйста, попробуйте позже.');
            } finally {
                setLoading(false);
            }
        };

        if (userId) {
            fetchFavoriteBooks();
        }
    }, [page, userId]);

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

        if (!isCurrentUser) return;

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

    // Форматирование цены
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
        <Box sx={{ 
            height: height || 'auto', 
            display: 'flex', 
            flexDirection: 'column',
            px: { xs: 1, sm: 2 } // Добавляем небольшие отступы по горизонтали для мобильных
        }}>
            {loading ? (
                <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', flex: 1 }}>
                    <CircularProgress sx={{ color: '#d32f2f' }} />
                </Box>
            ) : (
                <>
                    {error && (
                        <Alert severity="error" sx={{ 
                            mb: 3, 
                            borderRadius: '8px',
                            bgcolor: '#fde9e9',
                            border: '1px solid #f9c6c6',
                            color: '#7f1f1f'
                        }}>
                            {error}
                        </Alert>
                    )}

                    {books.length === 0 ? (
                        <Alert severity="info" sx={{ 
                            borderRadius: '8px',
                            bgcolor: '#e8f4fd',
                            border: '1px solid #c5e1fb',
                            color: '#0d5289'
                        }}>
                            {isCurrentUser ? 'У вас пока нет избранных книг' : 'У пользователя нет избранных книг'}
                        </Alert>
                    ) : (
                        <>
                            <Box sx={{ 
                                flex: 1, 
                                overflowY: 'auto',
                                // Улучшенные настройки для мобильных устройств
                                maxHeight: {
                                    xs: height ? `calc(${height} - 50px)` : '300px', 
                                    sm: height ? `calc(${height} - 60px)` : '400px',
                                    md: height ? `calc(${height} - 70px)` : 'calc(100vh - 300px)'
                                },
                                // Добавляем правильную прокрутку
                                WebkitOverflowScrolling: 'touch', // для плавной прокрутки на iOS
                                scrollbarWidth: 'thin',
                                '&::-webkit-scrollbar': {
                                    width: '6px',
                                },
                                '&::-webkit-scrollbar-thumb': {
                                    backgroundColor: 'rgba(0,0,0,0.2)',
                                    borderRadius: '3px',
                                },
                            }}>
                                <List sx={{ 
                                    width: '100%', 
                                    bgcolor: 'background.paper', 
                                    p: 0,
                                    borderRadius: '8px', // Скругляем углы списка
                                    border: '1px solid rgba(0,0,0,0.08)' // Добавляем тонкую рамку
                                }}>
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
                                                    // Уменьшаем отступы для мобильных устройств
                                                    paddingRight: { xs: '42px', sm: '56px' },
                                                    py: { xs: 1.5, sm: 2, md: 2.5 }
                                                }}
                                            >
                                                {bookImages[book.id] ? (
                                                    // Если есть изображение - отображаем его
                                                    <Box
                                                        sx={{
                                                            position: 'relative',
                                                            width: { xs: 80, sm: 90, md: 110 }, // Увеличиваем размер для лучшей видимости
                                                            height: { xs: 100, sm: 115, md: 140 }, // Делаем высоту больше для лучшего отображения обложек
                                                            mr: { xs: 1, sm: 2, md: 3 }, // Уменьшаем отступ справа на мобильных
                                                            overflow: 'visible',
                                                            flexShrink: 0, // Предотвращаем сжатие изображения
                                                            '&:hover .book-image': {
                                                                transform: {
                                                                    xs: 'scale(1.5)', // Меньший масштаб на мобильных для предотвращения выхода за границы экрана
                                                                    sm: 'scale(1.8)',
                                                                    md: 'scale(2)'
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
                                                            mr: { xs: 1, sm: 2, md: 3 }, // Уменьшаем отступ справа на мобильных
                                                            overflow: 'visible',
                                                            flexShrink: 0, // Предотвращаем сжатие изображения
                                                            '&:hover .book-image': {
                                                                transform: {
                                                                    xs: 'scale(1.5)', // Меньший масштаб на мобильных
                                                                    sm: 'scale(1.8)',
                                                                    md: 'scale(2)'
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
                                                                // Улучшаем размер шрифта на мобильных
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
                                                            // Улучшаем отображение вторичной информации
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
                                                {isCurrentUser && (
                                                    <ListItemSecondaryAction>
                                                        <Tooltip title="Удалить из избранного">
                                                            <IconButton
                                                                edge="end"
                                                                onClick={(e) => handleRemoveFromFavorites(book.id, e)}
                                                                disabled={removingIds.includes(book.id)}
                                                                size="small"
                                                                sx={{ 
                                                                    color: '#d32f2f',
                                                                    // Уменьшаем размер кнопки на мобильных
                                                                    '& svg': {
                                                                        fontSize: { xs: 18, sm: 20 }
                                                                    }
                                                                }}
                                                            >
                                                                {removingIds.includes(book.id) ? (
                                                                    <CircularProgress size={18} color="inherit" />
                                                                ) : (
                                                                    <DeleteIcon />
                                                                )}
                                                            </IconButton>
                                                        </Tooltip>
                                                    </ListItemSecondaryAction>
                                                )}
                                            </ListItem>
                                        </React.Fragment>
                                    ))}
                                </List>
                            </Box>

                            {totalPages > 1 && (
                                <Box sx={{ 
                                    display: 'flex', 
                                    justifyContent: 'center', 
                                    mt: 2,
                                    pt: 1,
                                    borderTop: '1px solid rgba(0, 0, 0, 0.12)' 
                                }}>
                                    <Pagination 
                                        count={totalPages} 
                                        page={page} 
                                        onChange={handlePageChange} 
                                        size="small"
                                        sx={{
                                            '& .MuiPaginationItem-root.Mui-selected': {
                                                backgroundColor: '#d32f2f',
                                                color: 'white',
                                                '&:hover': {
                                                    backgroundColor: '#b71c1c'
                                                }
                                            },
                                            // Адаптируем пагинацию для мобильных
                                            '& .MuiPaginationItem-root': {
                                                minWidth: { xs: '28px', sm: '32px' },
                                                height: { xs: '28px', sm: '32px' },
                                                fontSize: { xs: '0.75rem', sm: '0.875rem' }
                                            }
                                        }}
                                    />
                                </Box>
                            )}
                        </>
                    )}
                </>
            )}
        </Box>
    );
};

export default UserFavoriteBooks; 