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
    Divider
} from '@mui/material';
import { getFavoriteBooks, removeBookFromFavorites } from '../api';
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
        <Box sx={{ height: height || 'auto', display: 'flex', flexDirection: 'column' }}>
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
                                    xs: height ? `calc(${height} - 40px)` : '300px', 
                                    sm: height ? `calc(${height} - 50px)` : '400px',
                                    md: height ? `calc(${height} - 60px)` : 'calc(100vh - 300px)'
                                }
                            }}>
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
                                                    // Уменьшаем отступы для мобильных устройств
                                                    paddingRight: { xs: '48px', sm: '56px' },
                                                    py: { xs: 1.5, md: 2 }
                                                }}
                                            >
                                                <BookIcon sx={{ 
                                                    color: '#d32f2f', 
                                                    mr: { xs: 1, sm: 2 }, 
                                                    fontSize: { xs: 18, sm: 20 } 
                                                }} />
                                                <ListItemText 
                                                    primary={
                                                        <Typography 
                                                            variant="subtitle1" 
                                                            sx={{ 
                                                                fontWeight: 'medium',
                                                                color: '#333',
                                                                '&:hover': { color: '#d32f2f' },
                                                                // Уменьшаем размер шрифта на мобильных
                                                                fontSize: { xs: '0.875rem', sm: '1rem' }
                                                            }}
                                                        >
                                                            {book.title || 'Без названия'}
                                                        </Typography>
                                                    }
                                                    secondary={
                                                        <Box sx={{ 
                                                            // Улучшаем отображение вторичной информации
                                                            display: 'flex', 
                                                            flexDirection: { xs: 'column', sm: 'row' },
                                                            alignItems: { xs: 'flex-start', sm: 'center' },
                                                            gap: { xs: 0.5, sm: 0 }
                                                        }}>
                                                            <Typography 
                                                                variant="body2" 
                                                                color="text.secondary" 
                                                                component="span"
                                                                sx={{ fontSize: { xs: '0.75rem', sm: '0.875rem' } }}
                                                            >
                                                                Добавлено: {formatDate(book.addedDate)}
                                                            </Typography>
                                                            {book.finalPrice && (
                                                                <Typography 
                                                                    variant="body2" 
                                                                    component="span" 
                                                                    sx={{ 
                                                                        ml: { xs: 0, sm: 2 }, 
                                                                        color: '#d32f2f', 
                                                                        fontWeight: 'medium',
                                                                        fontSize: { xs: '0.75rem', sm: '0.875rem' }
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