import React, { useState, useEffect } from 'react';
import {
    Box, Typography, Grid, Card, CardContent, CardMedia,
    Button, Chip, CircularProgress, Alert, CardActionArea, Paper,
    Pagination, Container, useTheme, IconButton, Tooltip,
    TextField, InputAdornment, Collapse
} from '@mui/material';
import {
    CheckCircle as CheckIcon,
    TrendingUp as TrendingIcon,
    OpenInNew as OpenIcon,
    AttachMoney as AttachMoneyIcon,
    DateRange as DateRangeIcon,
    Category as CategoryIcon,
    Store as StoreIcon,
    Favorite as FavoriteIcon,
    FavoriteBorder as FavoriteBorderIcon,
    Search as SearchIcon,
    FilterList as FilterListIcon,
    Clear as ClearIcon
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { API_URL, getAuthHeaders, checkIfBookIsFavorite, addBookToFavorites, removeBookFromFavorites } from '../api';
import axios from 'axios';
import Cookies from 'js-cookie';

const CollectionBookMatches = ({ 
    matches = [], 
    onSelectReference, 
    selectedReferenceId, 
    loading = false,
    bookId,
    bookTitle 
}) => {
    const navigate = useNavigate();
    const theme = useTheme();
    
    const [thumbnails, setThumbnails] = useState({});
    const [favoriteBooks, setFavoriteBooks] = useState({});
    const [favoritesLoading, setFavoritesLoading] = useState({});
    
    // Ручной поиск
    const [customSearchQuery, setCustomSearchQuery] = useState('');
    const [showCustomSearch, setShowCustomSearch] = useState(false);
    const [customMatches, setCustomMatches] = useState([]);
    const [isCustomSearching, setIsCustomSearching] = useState(false);
    const [customSearchError, setCustomSearchError] = useState('');

    const getMatchColor = (score) => {
        if (score >= 0.8) return 'success';
        if (score >= 0.5) return 'warning';
        return 'default';
    };

    const getMatchPercentage = (score) => {
        return Math.round(score * 100);
    };

    // Инициализация пользовательского поиска названием книги
    useEffect(() => {
        if (bookTitle && !customSearchQuery) {
            setCustomSearchQuery(bookTitle);
        }
    }, [bookTitle]);

    // Функция для ручного поиска
    const handleCustomSearch = async () => {
        if (!customSearchQuery.trim()) {
            setCustomSearchError('Введите название для поиска');
            return;
        }

        setIsCustomSearching(true);
        setCustomSearchError('');

        try {
            const token = Cookies.get('token');
            const response = await axios.get(
                `${API_URL}/usercollection/${bookId}/matches/search`,
                {
                    params: { query: customSearchQuery },
                    headers: { Authorization: `Bearer ${token}` }
                }
            );
            
            setCustomMatches(response.data);
            
            if (response.data.length === 0) {
                setCustomSearchError('Аналоги не найдены. Попробуйте изменить запрос.');
            }
        } catch (err) {
            console.error('Error in custom search:', err);
            setCustomSearchError('Ошибка при поиске аналогов');
        } finally {
            setIsCustomSearching(false);
        }
    };

    const handleResetCustomSearch = () => {
        setCustomSearchQuery(bookTitle || '');
        setCustomMatches([]);
        setCustomSearchError('');
    };

    // Функция для извлечения имени файла из URL (если передан полный URL)
    const extractImageName = (imageNameOrUrl) => {
        if (!imageNameOrUrl) return null;
        
        // Если это уже имя файла (не содержит / или http), возвращаем как есть
        if (!imageNameOrUrl.includes('/') && !imageNameOrUrl.startsWith('http')) {
            return imageNameOrUrl;
        }
        
        // Если это URL, извлекаем имя файла
        try {
            const url = new URL(imageNameOrUrl, window.location.origin);
            const pathParts = url.pathname.split('/');
            return pathParts[pathParts.length - 1];
        } catch {
            // Если не удалось распарсить как URL, пробуем извлечь имя из пути
            const pathParts = imageNameOrUrl.split('/');
            return pathParts[pathParts.length - 1];
        }
    };

    // Функция загрузки изображений
    const getBookImageFile = (id, imageName) => {
        // Извлекаем имя файла, если передан полный URL
        const fileName = extractImageName(imageName);
        if (!fileName) {
            throw new Error('Имя файла изображения не найдено');
        }
        
        return axios.get(`${API_URL}/books/${id}/images/${fileName}`, {
            headers: getAuthHeaders(),
            responseType: 'blob',
        });
    };

    // Форматирование даты
    const formatDate = (dateString) => {
        if (!dateString) return 'Нет данных';
        if (dateString === 'Только для подписчиков') return dateString;
        
        try {
            const date = new Date(dateString);
            if (isNaN(date.getTime())) {
                return dateString;
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

    // Функция для обрезки HTML текста с сохранением тегов
    const truncateHtml = (html, maxLength = 150) => {
        if (!html) return '';
        
        // Удаляем HTML теги для подсчета длины текста
        const textContent = html.replace(/<[^>]*>/g, '');
        
        if (textContent.length <= maxLength) {
            return html;
        }
        
        // Находим позицию, где нужно обрезать
        let truncated = '';
        let textLength = 0;
        let inTag = false;
        let tagBuffer = '';
        
        for (let i = 0; i < html.length; i++) {
            const char = html[i];
            
            if (char === '<') {
                inTag = true;
                tagBuffer = char;
            } else if (char === '>') {
                inTag = false;
                tagBuffer += char;
                truncated += tagBuffer;
                tagBuffer = '';
            } else if (inTag) {
                tagBuffer += char;
            } else {
                if (textLength < maxLength) {
                    truncated += char;
                    textLength++;
                } else {
                    break;
                }
            }
        }
        
        // Закрываем незакрытые теги (упрощенная версия)
        return truncated + '...';
    };

    // Загрузка изображений при изменении matches или customMatches
    useEffect(() => {
        const allMatches = customMatches.length > 0 ? customMatches : matches;
        if (!allMatches || allMatches.length === 0) {
            setThumbnails({});
            return;
        }

        // Очищаем предыдущие миниатюры
        setThumbnails({});

        // Параллельная загрузка изображений (как в BookList.jsx)
        allMatches.forEach(async (match) => {
            const book = match.matchedBook;
            if (book && book.firstImageName && book.firstImageName.trim() !== '') {
                try {
                    console.log(`Загружаем изображение для книги ${book.id}: ${book.firstImageName}`);
                    const response = await getBookImageFile(book.id, book.firstImageName);
                    const imageUrl = URL.createObjectURL(response.data);
                    
                    // Обновляем thumbnails для каждой книги сразу после загрузки
                    setThumbnails(prev => ({
                        ...prev,
                        [book.id]: imageUrl
                    }));
                } catch (error) {
                    console.error(`Ошибка при загрузке изображения для книги ${book.id}:`, error);
                    // В случае ошибки продолжаем работу (не устанавливаем null, как в BookList.jsx)
                }
            } else {
                console.log(`Книга ${book?.id} не имеет firstImageName или оно пустое`);
            }
        });

        // Очистка URL объектов при размонтировании
        return () => {
            setThumbnails(prev => {
                Object.values(prev).forEach(url => {
                    if (url && typeof url === 'string' && url.startsWith('blob:')) {
                        URL.revokeObjectURL(url);
                    }
                });
                return {};
            });
        };
    }, [matches, customMatches]);

    // Загрузка статуса избранного
    useEffect(() => {
        const allMatches = customMatches.length > 0 ? customMatches : matches;
        if (!allMatches || allMatches.length === 0) return;

        const checkFavorites = async () => {
            const token = Cookies.get('token');
            if (!token) return;

            try {
                allMatches.forEach(async (match) => {
                    const book = match.matchedBook;
                    if (book) {
                        try {
                            const response = await checkIfBookIsFavorite(book.id);
                            setFavoriteBooks(prev => ({
                                ...prev,
                                [book.id]: response.data
                            }));
                        } catch (error) {
                            console.error(`Ошибка при проверке статуса избранного для книги ${book.id}:`, error);
                        }
                    }
                });
            } catch (error) {
                console.error('Ошибка при проверке статуса избранных книг:', error);
            }
        };

        checkFavorites();
    }, [matches, customMatches]);

    // Обработка добавления/удаления из избранного
    const handleToggleFavorite = async (bookId, event) => {
        event.stopPropagation();
        
        const token = Cookies.get('token');
        if (!token) {
            navigate('/login');
            return;
        }

        try {
            setFavoritesLoading(prev => ({ ...prev, [bookId]: true }));

            const isFavorite = favoriteBooks[bookId];

            if (isFavorite) {
                await removeBookFromFavorites(bookId);
                setFavoriteBooks(prev => ({ ...prev, [bookId]: false }));
            } else {
                await addBookToFavorites(bookId);
                setFavoriteBooks(prev => ({ ...prev, [bookId]: true }));
            }
        } catch (error) {
            console.error('Ошибка при изменении статуса избранного:', error);
        } finally {
            setFavoritesLoading(prev => ({ ...prev, [bookId]: false }));
        }
    };

    if (loading) {
        return (
            <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
                <CircularProgress />
            </Box>
        );
    }

    // Используем кастомные результаты, если они есть, иначе стандартные
    const displayMatches = customMatches.length > 0 ? customMatches : matches;

    return (
        <Container maxWidth="xl">
            <Box sx={{ my: 3 }}>
                {/* Панель ручного поиска */}
                <Paper elevation={2} sx={{ p: 2, mb: 3, bgcolor: 'background.default' }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                        <Button
                            variant={showCustomSearch ? "contained" : "outlined"}
                            startIcon={<FilterListIcon />}
                            onClick={() => setShowCustomSearch(!showCustomSearch)}
                            size="small"
                        >
                            {showCustomSearch ? 'Скрыть поиск' : 'Уточнить поиск'}
                        </Button>
                        <Typography variant="body2" color="text.secondary" sx={{ ml: 2 }}>
                            {customMatches.length > 0 
                                ? `Результаты ручного поиска: ${customMatches.length}` 
                                : `Автоматически найдено: ${matches.length}`}
                        </Typography>
                    </Box>

                    <Collapse in={showCustomSearch}>
                        <Box sx={{ display: 'flex', gap: 2, alignItems: 'flex-start' }}>
                            <TextField
                                fullWidth
                                label="Название книги для поиска"
                                value={customSearchQuery}
                                onChange={(e) => setCustomSearchQuery(e.target.value)}
                                onKeyPress={(e) => {
                                    if (e.key === 'Enter') {
                                        handleCustomSearch();
                                    }
                                }}
                                placeholder="Введите название книги..."
                                error={!!customSearchError}
                                helperText={customSearchError}
                                InputProps={{
                                    startAdornment: (
                                        <InputAdornment position="start">
                                            <SearchIcon />
                                        </InputAdornment>
                                    ),
                                    endAdornment: customSearchQuery && (
                                        <InputAdornment position="end">
                                            <IconButton
                                                size="small"
                                                onClick={() => setCustomSearchQuery('')}
                                            >
                                                <ClearIcon />
                                            </IconButton>
                                        </InputAdornment>
                                    )
                                }}
                            />
                            <Button
                                variant="contained"
                                onClick={handleCustomSearch}
                                disabled={isCustomSearching || !customSearchQuery.trim()}
                                sx={{ minWidth: 120 }}
                            >
                                {isCustomSearching ? <CircularProgress size={24} /> : 'Найти'}
                            </Button>
                            {customMatches.length > 0 && (
                                <Button
                                    variant="outlined"
                                    onClick={handleResetCustomSearch}
                                    startIcon={<ClearIcon />}
                                >
                                    Сбросить
                                </Button>
                            )}
                        </Box>
                        
                        <Alert severity="info" sx={{ mt: 2 }}>
                            💡 Введите название книги вручную для более точного поиска аналогов. 
                            Например, можете убрать лишние слова или добавить дополнительные детали.
                        </Alert>
                    </Collapse>
                </Paper>

                {/* Заголовок результатов */}
                {!loading && displayMatches.length === 0 && (
                    <Paper elevation={1} sx={{ p: 3, textAlign: 'center', bgcolor: 'grey.50', mb: 3 }}>
                        <Typography variant="body1" color="text.secondary">
                            Аналоги не найдены
                        </Typography>
                        <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                            {customMatches.length === 0 
                                ? 'Попробуйте уточнить поиск вручную, изменив название книги' 
                                : 'Попробуйте другой поисковый запрос'}
                        </Typography>
                    </Paper>
                )}

                {displayMatches.length > 0 && (
                    <Typography 
                        variant="h6" 
                        component="h2" 
                        sx={{ 
                            mb: 3, 
                            fontWeight: 'bold',
                            color: theme.palette.primary.dark,
                            borderLeft: `4px solid ${theme.palette.primary.main}`,
                            pl: 2
                        }}
                    >
                        Найдено аналогов: {displayMatches.length}
                        {customMatches.length > 0 && (
                            <Chip 
                                label="Ручной поиск" 
                                color="primary" 
                                size="small" 
                                sx={{ ml: 2 }}
                            />
                        )}
                    </Typography>
                )}

                <Grid container spacing={3}>
                    {displayMatches.map((match) => {
                        const book = match.matchedBook;
                        const isSelected = match.matchedBookId === selectedReferenceId;

                        return (
                            <Grid item xs={12} key={match.matchedBookId}>
                                <Card 
                                    sx={{
                                        borderRadius: '12px',
                                        overflow: 'hidden',
                                        transition: 'transform 0.2s ease, box-shadow 0.2s ease',
                                        boxShadow: isSelected 
                                            ? '0 8px 24px rgba(76, 175, 80, 0.3)' 
                                            : '0 4px 12px rgba(0,0,0,0.08)',
                                        border: isSelected ? '2px solid' : 'none',
                                        borderColor: 'success.main',
                                        '&:hover': {
                                            transform: 'translateY(-4px)',
                                            boxShadow: '0 8px 24px rgba(0,0,0,0.12)'
                                        },
                                        position: 'relative'
                                    }}
                                >
                                    {/* Индикатор совпадения */}
                                    <Box sx={{ position: 'absolute', top: 12, left: 12, zIndex: 10 }}>
                                        <Chip
                                            label={`Совпадение: ${getMatchPercentage(match.matchScore)}%`}
                                            size="small"
                                            color={getMatchColor(match.matchScore)}
                                            sx={{ fontWeight: 'bold' }}
                                        />
                                    </Box>

                                    {/* Кнопка избранного */}
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

                                    {/* Индикатор выбранного референса */}
                                    {isSelected && (
                                        <Box
                                            sx={{
                                                position: 'absolute',
                                                top: 8,
                                                right: 60,
                                                bgcolor: 'success.main',
                                                color: 'white',
                                                borderRadius: '50%',
                                                p: 0.5,
                                                zIndex: 10,
                                                boxShadow: 2
                                            }}
                                        >
                                            <CheckIcon />
                                        </Box>
                                    )}

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
                                                onClick={() => navigate(`/books/${book.id}`)}
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
                                                        {book.firstImageName && book.firstImageName.trim() !== '' ? (
                                                            <>
                                                                <CircularProgress size={50} sx={{ color: theme.palette.primary.main, mb: 1 }} />
                                                                <Typography variant="body2" color="text.secondary" align="center">
                                                                    Загрузка изображения...
                                                                </Typography>
                                                            </>
                                                        ) : (
                                                            <>
                                                                <Typography variant="h3" sx={{ fontSize: 60, color: 'rgba(69, 39, 160, 0.2)', mb: 1 }}>
                                                                    📚
                                                                </Typography>
                                                                <Typography variant="body2" color="text.secondary" align="center">
                                                                    Изображение отсутствует
                                                                </Typography>
                                                            </>
                                                        )}
                                                    </Box>
                                                )}
                                            </Grid>
                                            
                                            {/* Информация о книге */}
                                            <Grid item xs={12} sm={9} md={10}>
                                                <Box sx={{ p: 3 }}>
                                                    <Typography 
                                                        variant="h5" 
                                                        component="h3"
                                                        fontWeight="bold"
                                                        sx={{ 
                                                            mb: 1,
                                                            cursor: 'pointer',
                                                            color: theme.palette.primary.dark,
                                                            '&:hover': { color: theme.palette.primary.main },
                                                            transition: 'color 0.2s'
                                                        }}
                                                        onClick={() => navigate(`/books/${book.id}`)}
                                                    >
                                                        {book.title}
                                                    </Typography>
                                                    
                                                    <Grid container spacing={2} sx={{ mb: 2 }}>
                                                        <Grid item xs={12} md={8}>
                                                            {book.description && (
                                                                <Box
                                                                    sx={{ 
                                                                        mb: 2,
                                                                        lineHeight: 1.6,
                                                                        color: 'text.secondary',
                                                                        '& p': { margin: 0, marginBottom: 1 },
                                                                        '& p:last-child': { marginBottom: 0 },
                                                                        '& span': { fontSize: 'inherit' }
                                                                    }}
                                                                    dangerouslySetInnerHTML={{
                                                                        __html: truncateHtml(book.description, 150)
                                                                    }}
                                                                />
                                                            )}
                                                            
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

                                                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mt: 2 }}>
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

                                                        <Box sx={{ display: 'flex', gap: 1 }}>
                                                            {!isSelected && onSelectReference && (
                                                                <Button
                                                                    variant="contained"
                                                                    startIcon={<TrendingIcon />}
                                                                    onClick={() => onSelectReference(match.matchedBookId)}
                                                                    sx={{ 
                                                                        borderRadius: '8px', 
                                                                        textTransform: 'none',
                                                                        fontWeight: 'bold'
                                                                    }}
                                                                >
                                                                    Использовать для оценки
                                                                </Button>
                                                            )}

                                                            {isSelected && (
                                                                <Chip
                                                                    label="Выбран как референс"
                                                                    color="success"
                                                                    icon={<CheckIcon />}
                                                                    sx={{ fontWeight: 'bold' }}
                                                                />
                                                            )}

                                                            <Button
                                                                variant="outlined"
                                                                endIcon={<OpenIcon />}
                                                                onClick={() => navigate(`/books/${book.id}`)}
                                                                sx={{ 
                                                                    borderRadius: '8px', 
                                                                    textTransform: 'none',
                                                                    fontWeight: 'bold'
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
                        );
                    })}
                </Grid>

                {displayMatches.length > 0 && (
                    <Paper elevation={0} sx={{ p: 2, mt: 3, bgcolor: 'info.light' }}>
                        <Typography variant="body2" color="info.dark">
                            💡 <strong>Подсказка:</strong> Выберите наиболее похожую книгу, чтобы автоматически установить оценку стоимости на основе цены продажи аналога.
                            {customMatches.length === 0 && ' Если результаты не точные, попробуйте уточнить поиск вручную.'}
                        </Typography>
                    </Paper>
                )}
            </Box>
        </Container>
    );
};

export default CollectionBookMatches;


