import React, { useState, useEffect } from 'react';
import {
    Box, Typography, Button, Grid, Card, CardContent, CardMedia,
    CardActionArea, TextField, MenuItem, CircularProgress, Alert,
    Paper, Chip, InputAdornment
} from '@mui/material';
import {
    Add as AddIcon,
    Search as SearchIcon,
    Download as DownloadIcon,
    Description as PdfIcon,
    Archive as ZipIcon
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { API_URL } from '../api';
import Cookies from 'js-cookie';

const UserCollection = () => {
    const navigate = useNavigate();
    const [books, setBooks] = useState([]);
    const [statistics, setStatistics] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [searchQuery, setSearchQuery] = useState('');
    const [sortBy, setSortBy] = useState('addedDate');
    const [imageBlobs, setImageBlobs] = useState({});

    useEffect(() => {
        loadCollection();
        loadStatistics();
    }, []);

    // Функция для загрузки изображения с авторизацией
    const loadImage = async (imageUrl) => {
        if (!imageUrl || imageBlobs[imageUrl]) {
            return imageBlobs[imageUrl] || '/placeholder-book.svg';
        }

        try {
            const token = Cookies.get('token');
            const response = await axios.get(`${API_URL.replace('/api', '')}${imageUrl}`, {
                headers: { Authorization: `Bearer ${token}` },
                responseType: 'blob'
            });
            
            const blobUrl = URL.createObjectURL(response.data);
            setImageBlobs(prev => ({ ...prev, [imageUrl]: blobUrl }));
            return blobUrl;
        } catch (error) {
            console.error('Ошибка загрузки изображения:', error);
            return '/placeholder-book.svg';
        }
    };

    // Компонент для отображения авторизованного изображения
    const AuthorizedCardMedia = ({ imageUrl, ...props }) => {
        const [src, setSrc] = useState('/placeholder-book.svg');
        
        useEffect(() => {
            if (imageUrl) {
                loadImage(imageUrl).then(setSrc);
            }
        }, [imageUrl]);
        
        return <CardMedia image={src} {...props} />;
    };

    const loadCollection = async () => {
        try {
            setLoading(true);
            const token = Cookies.get('token');
            const response = await axios.get(`${API_URL}/usercollection`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setBooks(response.data);
            setError('');
        } catch (err) {
            console.error('Error loading collection:', err);
            if (err.response?.status === 403) {
                setError('Доступ к коллекции недоступен. Пожалуйста, оформите подходящую подписку.');
            } else {
                setError('Не удалось загрузить коллекцию');
            }
        } finally {
            setLoading(false);
        }
    };

    const loadStatistics = async () => {
        try {
            const token = Cookies.get('token');
            const response = await axios.get(`${API_URL}/usercollection/statistics`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setStatistics(response.data);
        } catch (err) {
            console.error('Error loading statistics:', err);
        }
    };

    const handleExportPdf = async () => {
        try {
            const token = Cookies.get('token');
            const response = await axios.get(`${API_URL}/usercollection/export/pdf`, {
                headers: { Authorization: `Bearer ${token}` },
                responseType: 'blob'
            });
            
            const url = window.URL.createObjectURL(new Blob([response.data]));
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', `collection_${new Date().toISOString().split('T')[0]}.pdf`);
            document.body.appendChild(link);
            link.click();
            link.remove();
        } catch (err) {
            console.error('Error exporting PDF:', err);
            setError('Не удалось экспортировать в PDF');
        }
    };

    const handleExportJson = async () => {
        try {
            const token = Cookies.get('token');
            const response = await axios.get(`${API_URL}/usercollection/export/json`, {
                headers: { Authorization: `Bearer ${token}` },
                responseType: 'blob'
            });
            
            const url = window.URL.createObjectURL(new Blob([response.data]));
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', `collection_${new Date().toISOString().split('T')[0]}.zip`);
            document.body.appendChild(link);
            link.click();
            link.remove();
        } catch (err) {
            console.error('Error exporting JSON:', err);
            setError('Не удалось экспортировать в JSON');
        }
    };

    const filteredAndSortedBooks = () => {
        let filtered = books;

        // Фильтрация по поиску
        if (searchQuery) {
            const query = searchQuery.toLowerCase();
            filtered = filtered.filter(book =>
                book.title?.toLowerCase().includes(query) ||
                book.author?.toLowerCase().includes(query)
            );
        }

        // Сортировка
        filtered = [...filtered].sort((a, b) => {
            switch (sortBy) {
                case 'addedDate':
                    return new Date(b.addedDate) - new Date(a.addedDate);
                case 'title':
                    return (a.title || '').localeCompare(b.title || '');
                case 'price':
                    return (b.estimatedPrice || 0) - (a.estimatedPrice || 0);
                default:
                    return 0;
            }
        });

        return filtered;
    };

    if (loading) {
        return (
            <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '60vh' }}>
                <CircularProgress />
            </Box>
        );
    }

    return (
        <Box sx={{ maxWidth: 1400, mx: 'auto', p: { xs: 2, md: 3 } }}>
            <Typography variant="h4" component="h1" gutterBottom sx={{ fontWeight: 'bold', mb: 3 }}>
                Моя коллекция редких книг
            </Typography>

            {error && (
                <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError('')}>
                    {error}
                </Alert>
            )}

            {/* Статистика */}
            {statistics && (
                <Paper elevation={2} sx={{ p: 3, mb: 3, background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)', color: 'white' }}>
                    <Grid container spacing={3}>
                        <Grid item xs={6} sm={3}>
                            <Typography variant="h4" sx={{ fontWeight: 'bold' }}>
                                {statistics.totalBooks}
                            </Typography>
                            <Typography variant="body2">Всего книг</Typography>
                        </Grid>
                        <Grid item xs={6} sm={3}>
                            <Typography variant="h4" sx={{ fontWeight: 'bold' }}>
                                {statistics.totalEstimatedValue.toLocaleString('ru-RU')} ₽
                            </Typography>
                            <Typography variant="body2">Общая оценка</Typography>
                        </Grid>
                        <Grid item xs={6} sm={3}>
                            <Typography variant="h4" sx={{ fontWeight: 'bold' }}>
                                {statistics.booksWithReference}
                            </Typography>
                            <Typography variant="body2">С референсом</Typography>
                        </Grid>
                        <Grid item xs={6} sm={3}>
                            <Typography variant="h4" sx={{ fontWeight: 'bold' }}>
                                {statistics.booksWithoutReference}
                            </Typography>
                            <Typography variant="body2">Без референса</Typography>
                        </Grid>
                    </Grid>
                </Paper>
            )}

            {/* Панель управления */}
            <Box sx={{ mb: 3 }}>
                {/* Поиск и сортировка */}
                <Box sx={{ display: 'flex', flexDirection: { xs: 'column', sm: 'row' }, gap: 2, mb: 2 }}>
                    <TextField
                        placeholder="Поиск по названию или автору..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        size="small"
                        sx={{ flexGrow: 1 }}
                        InputProps={{
                            startAdornment: (
                                <InputAdornment position="start">
                                    <SearchIcon />
                                </InputAdornment>
                            )
                        }}
                    />

                    <TextField
                        select
                        label="Сортировка"
                        value={sortBy}
                        onChange={(e) => setSortBy(e.target.value)}
                        size="small"
                        sx={{ minWidth: { xs: '100%', sm: 200 } }}
                    >
                        <MenuItem value="addedDate">По дате добавления</MenuItem>
                        <MenuItem value="title">По названию</MenuItem>
                        <MenuItem value="price">По оценке</MenuItem>
                    </TextField>
                </Box>

                {/* Кнопки действий */}
                <Box sx={{ display: 'flex', flexDirection: { xs: 'column', sm: 'row' }, gap: 2 }}>
                    <Button
                        variant="contained"
                        startIcon={<AddIcon />}
                        onClick={() => navigate('/collection/add')}
                        fullWidth={true}
                        sx={{ flexGrow: { sm: 1 } }}
                    >
                        Добавить книгу
                    </Button>

                    <Box sx={{ display: 'flex', gap: 2 }}>
                        <Button
                            variant="outlined"
                            startIcon={<PdfIcon />}
                            onClick={handleExportPdf}
                            disabled={books.length === 0}
                            fullWidth
                            sx={{ flexGrow: 1 }}
                        >
                            <Box component="span" sx={{ display: { xs: 'none', sm: 'inline' } }}>Экспорт </Box>PDF
                        </Button>

                        <Button
                            variant="outlined"
                            startIcon={<ZipIcon />}
                            onClick={handleExportJson}
                            disabled={books.length === 0}
                            fullWidth
                            sx={{ flexGrow: 1 }}
                        >
                            <Box component="span" sx={{ display: { xs: 'none', sm: 'inline' } }}>Экспорт </Box>ZIP
                        </Button>
                    </Box>
                </Box>
            </Box>

            {/* Список книг */}
            {books.length === 0 ? (
                <Paper elevation={1} sx={{ p: 6, textAlign: 'center' }}>
                    <Typography variant="h6" color="text.secondary" gutterBottom>
                        Ваша коллекция пока пуста
                    </Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                        Начните добавлять книги, чтобы отслеживать свою коллекцию и получать оценки стоимости
                    </Typography>
                    <Button
                        variant="contained"
                        startIcon={<AddIcon />}
                        onClick={() => navigate('/collection/add')}
                        size="large"
                    >
                        Добавить первую книгу
                    </Button>
                </Paper>
            ) : (
                <Grid container spacing={3}>
                    {filteredAndSortedBooks().map((book) => (
                        <Grid item xs={12} sm={6} md={4} lg={3} key={book.id}>
                            <Card 
                                elevation={2}
                                sx={{ 
                                    height: '100%', 
                                    display: 'flex', 
                                    flexDirection: 'column',
                                    transition: 'transform 0.2s, box-shadow 0.2s',
                                    '&:hover': {
                                        transform: 'translateY(-4px)',
                                        boxShadow: 6
                                    }
                                }}
                            >
                                <CardActionArea onClick={() => navigate(`/collection/${book.id}`)}>
                                    {book.mainImageUrl ? (
                                        <AuthorizedCardMedia
                                            component="img"
                                            height="200"
                                            imageUrl={book.mainImageUrl}
                                            alt={book.title}
                                            sx={{ objectFit: 'cover' }}
                                        />
                                    ) : (
                                        <Box
                                            sx={{
                                                height: 200,
                                                bgcolor: 'grey.200',
                                                display: 'flex',
                                                alignItems: 'center',
                                                justifyContent: 'center'
                                            }}
                                        >
                                            <Typography variant="body2" color="text.secondary">
                                                Нет изображения
                                            </Typography>
                                        </Box>
                                    )}

                                    <CardContent sx={{ flexGrow: 1 }}>
                                        <Typography variant="h6" component="div" gutterBottom noWrap>
                                            {book.title}
                                        </Typography>

                                        {book.author && (
                                            <Typography variant="body2" color="text.secondary" gutterBottom noWrap>
                                                {book.author}
                                            </Typography>
                                        )}

                                        {book.yearPublished && (
                                            <Typography variant="body2" color="text.secondary" gutterBottom>
                                                {book.yearPublished} г.
                                            </Typography>
                                        )}

                                        <Box sx={{ mt: 2, display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                                            {book.estimatedPrice ? (
                                                <Chip
                                                    label={`${book.estimatedPrice.toLocaleString('ru-RU')} ₽`}
                                                    color="primary"
                                                    size="small"
                                                />
                                            ) : (
                                                <Chip label="Нет оценки" size="small" variant="outlined" />
                                            )}

                                            {book.hasReferenceBook && (
                                                <Chip label="Есть референс" size="small" color="success" variant="outlined" />
                                            )}

                                            {book.imagesCount > 0 && (
                                                <Chip label={`${book.imagesCount} фото`} size="small" variant="outlined" />
                                            )}
                                        </Box>
                                    </CardContent>
                                </CardActionArea>
                            </Card>
                        </Grid>
                    ))}
                </Grid>
            )}
        </Box>
    );
};

export default UserCollection;

