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
    Divider
} from '@mui/material';
import { getFavoriteBooks, removeBookFromFavorites } from '../api';
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

        fetchFavoriteBooks();
    }, [page, navigate]);

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
        <Container maxWidth="md" sx={{ py: { xs: 2, md: 3 } }}>
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
                                                    paddingRight: '56px' // Пространство для кнопки удаления
                                                }}
                                            >
                                                <BookIcon sx={{ color: '#d32f2f', mr: 2, fontSize: 20 }} />
                                                <ListItemText 
                                                    primary={
                                                        <Typography 
                                                            variant="subtitle1" 
                                                            sx={{ 
                                                                fontWeight: 'medium',
                                                                color: '#333',
                                                                '&:hover': { color: '#d32f2f' }
                                                            }}
                                                        >
                                                            {book.title || 'Без названия'}
                                                        </Typography>
                                                    }
                                                    secondary={
                                                        <Box>
                                                            <Typography variant="body2" color="text.secondary" component="span">
                                                                Добавлено: {formatDate(book.addedDate)}
                                                            </Typography>
                                                            {book.finalPrice && (
                                                                <Typography 
                                                                    variant="body2" 
                                                                    component="span" 
                                                                    sx={{ 
                                                                        ml: 2, 
                                                                        color: '#d32f2f', 
                                                                        fontWeight: 'medium' 
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