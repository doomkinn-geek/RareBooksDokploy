import React, { useState, useEffect } from 'react';
import {
    Box, Typography, Button, Grid, Card, CardContent, CardMedia,
    CardActionArea, TextField, MenuItem, CircularProgress, Alert,
    Paper, Chip, InputAdornment, Dialog, DialogTitle, DialogContent, DialogActions
} from '@mui/material';
import {
    Add as AddIcon,
    Search as SearchIcon,
    Download as DownloadIcon,
    Description as PdfIcon,
    Archive as ZipIcon,
    Upload as UploadIcon,
    DeleteForever as DeleteAllIcon
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { API_URL } from '../api';
import Cookies from 'js-cookie';
import ImportCollection from './ImportCollection';

const UserCollection = () => {
    const navigate = useNavigate();
    const [books, setBooks] = useState([]);
    const [statistics, setStatistics] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [searchQuery, setSearchQuery] = useState('');
    const [sortBy, setSortBy] = useState('purchaseDate');
    const [sortOrder, setSortOrder] = useState('desc');
    const [imageBlobs, setImageBlobs] = useState({});
    const [importDialogOpen, setImportDialogOpen] = useState(false);
    const [deleteAllDialogOpen, setDeleteAllDialogOpen] = useState(false);
    const [deleting, setDeleting] = useState(false);

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

    const handleDeleteAll = async () => {
        setDeleting(true);
        try {
            const token = Cookies.get('token');
            const response = await axios.delete(`${API_URL}/usercollection/all`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            
            setDeleteAllDialogOpen(false);
            await loadCollection();
            await loadStatistics();
            setError('');
        } catch (err) {
            console.error('Error deleting all books:', err);
            setError('Не удалось удалить коллекцию');
        } finally {
            setDeleting(false);
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
            let comparison = 0;
            
            switch (sortBy) {
                case 'addedDate': {
                    const dateA = new Date(a.addedDate).getTime();
                    const dateB = new Date(b.addedDate).getTime();
                    comparison = dateB - dateA;
                    break;
                }

                case 'purchaseDate': {
                    const dateA = a.purchaseDate ? new Date(a.purchaseDate).getTime() : 0;
                    const dateB = b.purchaseDate ? new Date(b.purchaseDate).getTime() : 0;
                    comparison = dateB - dateA;
                    break;
                }

                case 'title':
                    comparison = (a.title || '').localeCompare(b.title || '');
                    break;

                case 'price':
                    comparison = (b.estimatedPrice || 0) - (a.estimatedPrice || 0);
                    break;

                case 'purchasePrice':
                    comparison = (b.purchasePrice || 0) - (a.purchasePrice || 0);
                    break;

                default:
                    comparison = 0;
            }

            // Применяем направление сортировки
            return sortOrder === 'asc' ? -comparison : comparison;
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
        <Box sx={{ maxWidth: 1400, mx: 'auto', p: { xs: 2, md: 3 }, overflowX: 'hidden' }}>
            <Typography variant="h4" component="h1" gutterBottom sx={{ fontWeight: 'bold', mb: 3, fontSize: { xs: '1.5rem', sm: '2rem' } }}>
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
                    <Grid container spacing={2}>
                        <Grid item xs={6} sm={6} md={2.4}>
                            <Typography variant="h4" sx={{ fontWeight: 'bold', fontSize: { xs: '1.25rem', sm: '1.75rem', md: '2rem' } }}>
                                {statistics.booksInCollection}
                            </Typography>
                            <Typography variant="body2" sx={{ fontSize: { xs: '0.7rem', sm: '0.875rem' } }}>В коллекции</Typography>
                        </Grid>
                        <Grid item xs={6} sm={6} md={2.4}>
                            <Typography variant="h4" sx={{ fontWeight: 'bold', fontSize: { xs: '1.25rem', sm: '1.75rem', md: '2rem' } }}>
                                {statistics.totalPurchaseValue ? `${statistics.totalPurchaseValue.toLocaleString('ru-RU')} ₽` : '0 ₽'}
                            </Typography>
                            <Typography variant="body2" sx={{ fontSize: { xs: '0.7rem', sm: '0.875rem' } }}>Затрачено</Typography>
                        </Grid>
                        <Grid item xs={6} sm={6} md={2.4}>
                            <Typography variant="h4" sx={{ fontWeight: 'bold', fontSize: { xs: '1.25rem', sm: '1.75rem', md: '2rem' } }}>
                                {statistics.totalEstimatedValue.toLocaleString('ru-RU')} ₽
                            </Typography>
                            <Typography variant="body2" sx={{ fontSize: { xs: '0.7rem', sm: '0.875rem' } }}>Оценка</Typography>
                        </Grid>
                        <Grid item xs={6} sm={6} md={2.4}>
                            <Typography variant="h4" sx={{ fontWeight: 'bold', fontSize: { xs: '1.25rem', sm: '1.75rem', md: '2rem' } }}>
                                {statistics.totalSoldValue ? `${statistics.totalSoldValue.toLocaleString('ru-RU')} ₽` : '0 ₽'}
                            </Typography>
                            <Typography variant="body2" sx={{ fontSize: { xs: '0.7rem', sm: '0.875rem' } }}>Продано ({statistics.booksSold || 0})</Typography>
                        </Grid>
                        <Grid item xs={12} sm={12} md={2.4}>
                            <Typography 
                                variant="h4" 
                                sx={{ 
                                    fontWeight: 'bold',
                                    fontSize: { xs: '1.25rem', sm: '1.75rem', md: '2rem' },
                                    color: statistics.totalProfit >= 0 ? '#4caf50' : '#ff5252'
                                }}
                            >
                                {statistics.totalProfit >= 0 ? '+' : ''}{(statistics.totalProfit || 0).toLocaleString('ru-RU')} ₽
                            </Typography>
                            <Typography variant="body2" sx={{ fontSize: { xs: '0.7rem', sm: '0.875rem' } }}>
                                Прибыль
                            </Typography>
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
                        <MenuItem value="purchaseDate">По дате покупки</MenuItem>
                        <MenuItem value="addedDate">По дате добавления</MenuItem>
                        <MenuItem value="title">По названию</MenuItem>
                        <MenuItem value="price">По оценке</MenuItem>
                        <MenuItem value="purchasePrice">По цене покупки</MenuItem>
                    </TextField>

                    <TextField
                        select
                        label="Порядок"
                        value={sortOrder}
                        onChange={(e) => setSortOrder(e.target.value)}
                        size="small"
                        sx={{ minWidth: { xs: '100%', sm: 140 } }}
                    >
                        <MenuItem value="desc">По убыванию</MenuItem>
                        <MenuItem value="asc">По возрастанию</MenuItem>
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

                    <Button
                        variant="contained"
                        color="secondary"
                        startIcon={<UploadIcon />}
                        onClick={() => setImportDialogOpen(true)}
                        fullWidth={true}
                        sx={{ flexGrow: { sm: 1 } }}
                    >
                        Импортировать
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

                        <Button
                            variant="outlined"
                            color="error"
                            startIcon={<DeleteAllIcon />}
                            onClick={() => setDeleteAllDialogOpen(true)}
                            disabled={books.length === 0}
                            fullWidth
                            sx={{ flexGrow: 1 }}
                        >
                            <Box component="span" sx={{ display: { xs: 'none', sm: 'inline' } }}>Удалить </Box>всё
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
                                            height="auto"
                                            imageUrl={book.mainImageUrl}
                                            alt={book.title}
                                            sx={{ 
                                                objectFit: 'contain',
                                                maxHeight: { xs: 160, sm: 180, md: 200 },
                                                minHeight: { xs: 160, sm: 180, md: 200 },
                                                bgcolor: '#f5f5f5'
                                            }}
                                        />
                                    ) : (
                                        <Box
                                            sx={{
                                                height: { xs: 160, sm: 180, md: 200 },
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

                                        {book.purchaseDate && (
                                            <Typography variant="body2" color="text.secondary" gutterBottom>
                                                Куплена: {new Date(book.purchaseDate).toLocaleDateString('ru-RU')}
                                            </Typography>
                                        )}

                                        <Box sx={{ mt: 2, display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                                            {book.estimatedPrice ? (
                                                <Chip
                                                    label={`Оценка: ${book.estimatedPrice.toLocaleString('ru-RU')} ₽`}
                                                    color="primary"
                                                    size="small"
                                                />
                                            ) : (
                                                <Chip label="Нет оценки" size="small" variant="outlined" />
                                            )}

                                            {book.purchasePrice && (
                                                <Chip
                                                    label={`Куплена: ${book.purchasePrice.toLocaleString('ru-RU')} ₽`}
                                                    color="info"
                                                    size="small"
                                                    variant="outlined"
                                                />
                                            )}

                                            {book.isSold && book.soldPrice && (
                                                <Chip
                                                    label={`Продана: ${book.soldPrice.toLocaleString('ru-RU')} ₽`}
                                                    color="success"
                                                    size="small"
                                                />
                                            )}

                                            {book.hasReferenceBook && (
                                                <Chip label="Есть референс" size="small" color="secondary" variant="outlined" />
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

            {/* Диалог импорта */}
            <Dialog 
                open={importDialogOpen} 
                onClose={() => setImportDialogOpen(false)}
                maxWidth="sm"
                fullWidth
            >
                <DialogTitle>Импорт коллекции</DialogTitle>
                <DialogContent>
                    <ImportCollection 
                        onImportComplete={() => {
                            setImportDialogOpen(false);
                            loadCollection();
                            loadStatistics();
                        }}
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setImportDialogOpen(false)}>
                        Закрыть
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Диалог подтверждения удаления всех книг */}
            <Dialog 
                open={deleteAllDialogOpen} 
                onClose={() => !deleting && setDeleteAllDialogOpen(false)}
                maxWidth="sm"
            >
                <DialogTitle>Удалить всю коллекцию?</DialogTitle>
                <DialogContent>
                    <Typography variant="body1" gutterBottom>
                        Вы уверены, что хотите удалить все книги из коллекции?
                    </Typography>
                    <Typography variant="body2" color="error" sx={{ mt: 2 }}>
                        Это действие необратимо! Будут удалены:
                    </Typography>
                    <Typography variant="body2" sx={{ mt: 1 }}>
                        • Все книги ({books.length} шт.)
                    </Typography>
                    <Typography variant="body2">
                        • Все изображения
                    </Typography>
                    <Typography variant="body2">
                        • Все связи с референсными книгами
                    </Typography>
                </DialogContent>
                <DialogActions>
                    <Button 
                        onClick={() => setDeleteAllDialogOpen(false)}
                        disabled={deleting}
                    >
                        Отмена
                    </Button>
                    <Button 
                        onClick={handleDeleteAll}
                        color="error"
                        variant="contained"
                        disabled={deleting}
                        startIcon={deleting ? <CircularProgress size={20} /> : <DeleteAllIcon />}
                    >
                        {deleting ? 'Удаление...' : 'Удалить всё'}
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default UserCollection;

