import React, { useState, useEffect } from 'react';
import {
    Box, Typography, Button, Paper, Alert, CircularProgress, Grid,
    TextField, Dialog, DialogTitle, DialogContent, DialogActions,
    IconButton, Chip, Divider, Card, CardContent
} from '@mui/material';
import {
    ArrowBack as BackIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    Save as SaveIcon,
    Cancel as CancelIcon,
    AttachMoney as MoneyIcon,
    Search as SearchIcon,
    ChevronLeft, ChevronRight
} from '@mui/icons-material';
import { useNavigate, useParams } from 'react-router-dom';
import axios from 'axios';
import { API_URL } from '../api';
import Cookies from 'js-cookie';
import CollectionImageUploader from './CollectionImageUploader';
import CollectionBookMatches from './CollectionBookMatches';

const CollectionBookDetail = () => {
    const { id } = useParams();
    const navigate = useNavigate();

    const [book, setBook] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [editMode, setEditMode] = useState(false);
    const [uploading, setUploading] = useState(false);
    const [imageBlobs, setImageBlobs] = useState({});

    // Форма редактирования
    const [formData, setFormData] = useState({
        title: '',
        author: '',
        yearPublished: '',
        description: '',
        notes: '',
        estimatedPrice: '',
        isManuallyPriced: false
    });

    // Диалог ручной установки цены
    const [priceDialogOpen, setPriceDialogOpen] = useState(false);
    const [manualPrice, setManualPrice] = useState('');

    // Галерея
    const [currentImageIndex, setCurrentImageIndex] = useState(0);

    // Поиск аналогов
    const [searchingMatches, setSearchingMatches] = useState(false);

    useEffect(() => {
        loadBook();
    }, [id]);

    // Функция для загрузки изображения с авторизацией
    const loadImage = async (imageUrl) => {
        if (imageBlobs[imageUrl]) {
            console.log('CollectionBookDetail - Используем кэшированное изображение:', imageUrl);
            return imageBlobs[imageUrl];
        }

        try {
            const token = Cookies.get('token');
            const fullUrl = `${API_URL.replace('/api', '')}${imageUrl}`;
            console.log('CollectionBookDetail - Загружаем изображение с URL:', fullUrl);
            console.log('CollectionBookDetail - Token:', token ? 'присутствует' : 'отсутствует');
            
            const response = await axios.get(fullUrl, {
                headers: { Authorization: `Bearer ${token}` },
                responseType: 'blob'
            });
            
            console.log('CollectionBookDetail - Получен blob размером:', response.data.size, 'байт');
            const blobUrl = URL.createObjectURL(response.data);
            console.log('CollectionBookDetail - Создан blob URL:', blobUrl);
            
            setImageBlobs(prev => ({ ...prev, [imageUrl]: blobUrl }));
            return blobUrl;
        } catch (error) {
            console.error('CollectionBookDetail - Ошибка загрузки изображения:', error);
            console.error('CollectionBookDetail - URL:', imageUrl);
            console.error('CollectionBookDetail - Детали ошибки:', error.response?.status, error.response?.statusText);
            throw error; // Пробрасываем ошибку для обработки в компоненте
        }
    };

    // Компонент для отображения авторизованного изображения
    const AuthorizedImage = ({ imageUrl, alt, sx, ...props }) => {
        const [src, setSrc] = useState('/placeholder-book.svg');
        const [imageError, setImageError] = useState(false);
        
        useEffect(() => {
            if (imageUrl) {
                console.log('CollectionBookDetail - Загружаем изображение:', imageUrl);
                setImageError(false);
                loadImage(imageUrl)
                    .then((blobUrl) => {
                        console.log('CollectionBookDetail - Изображение загружено:', blobUrl);
                        setSrc(blobUrl);
                    })
                    .catch((err) => {
                        console.error('CollectionBookDetail - Ошибка загрузки изображения:', err);
                        setImageError(true);
                        setSrc('/placeholder-book.svg');
                    });
            }
        }, [imageUrl]);
        
        if (imageError) {
            return (
                <Box 
                    sx={{ 
                        ...sx, 
                        display: 'flex', 
                        alignItems: 'center', 
                        justifyContent: 'center',
                        bgcolor: 'grey.200',
                        color: 'text.secondary'
                    }}
                >
                    <Typography variant="body2">Не удалось загрузить</Typography>
                </Box>
            );
        }
        
        return (
            <Box 
                component="img" 
                src={src} 
                alt={alt} 
                sx={sx} 
                onError={(e) => {
                    console.error('CollectionBookDetail - Ошибка отображения изображения');
                    setImageError(true);
                }}
                {...props} 
            />
        );
    };

    const loadBook = async () => {
        try {
            setLoading(true);
            const token = Cookies.get('token');
            const response = await axios.get(`${API_URL}/usercollection/${id}`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            
            const bookData = response.data;
            setBook(bookData);
            setFormData({
                title: bookData.title || '',
                author: bookData.author || '',
                yearPublished: bookData.yearPublished || '',
                description: bookData.description || '',
                notes: bookData.notes || '',
                estimatedPrice: bookData.estimatedPrice || '',
                isManuallyPriced: bookData.isManuallyPriced || false
            });
            setError('');
        } catch (err) {
            console.error('Error loading book:', err);
            setError('Не удалось загрузить информацию о книге');
        } finally {
            setLoading(false);
        }
    };

    const handleUpdate = async () => {
        try {
            const token = Cookies.get('token');
            const updateData = {
                id: parseInt(id),
                title: formData.title,
                author: formData.author || null,
                yearPublished: formData.yearPublished ? parseInt(formData.yearPublished) : null,
                description: formData.description || null,
                notes: formData.notes || null,
                estimatedPrice: formData.estimatedPrice ? parseFloat(formData.estimatedPrice) : null,
                referenceBookId: book.referenceBookId || null
            };

            await axios.put(`${API_URL}/usercollection/${id}`, updateData, {
                headers: { Authorization: `Bearer ${token}` }
            });

            await loadBook();
            setEditMode(false);
            setError('');
        } catch (err) {
            console.error('Error updating book:', err);
            setError('Не удалось обновить информацию о книге');
        }
    };

    const handleDelete = async () => {
        if (!window.confirm('Вы уверены, что хотите удалить эту книгу из коллекции?')) {
            return;
        }

        try {
            const token = Cookies.get('token');
            await axios.delete(`${API_URL}/usercollection/${id}`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            navigate('/collection');
        } catch (err) {
            console.error('Error deleting book:', err);
            setError('Не удалось удалить книгу');
        }
    };

    const handleImageUpload = async (file) => {
        setUploading(true);
        try {
            const token = Cookies.get('token');
            const formData = new FormData();
            formData.append('file', file);

            await axios.post(`${API_URL}/usercollection/${id}/images`, formData, {
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'multipart/form-data'
                }
            });

            await loadBook();
        } catch (err) {
            console.error('Error uploading image:', err);
            throw new Error('Не удалось загрузить изображение');
        } finally {
            setUploading(false);
        }
    };

    const handleImageDelete = async (imageId) => {
        if (!window.confirm('Удалить это изображение?')) {
            return;
        }

        try {
            const token = Cookies.get('token');
            await axios.delete(`${API_URL}/usercollection/${id}/images/${imageId}`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            await loadBook();
        } catch (err) {
            console.error('Error deleting image:', err);
            setError('Не удалось удалить изображение');
        }
    };

    const handleSetMainImage = async (imageId) => {
        try {
            const token = Cookies.get('token');
            await axios.put(`${API_URL}/usercollection/${id}/images/${imageId}/setmain`, {}, {
                headers: { Authorization: `Bearer ${token}` }
            });
            await loadBook();
        } catch (err) {
            console.error('Error setting main image:', err);
            setError('Не удалось установить главное изображение');
        }
    };

    const handleFindMatches = async () => {
        try {
            setSearchingMatches(true);
            const token = Cookies.get('token');
            const response = await axios.get(`${API_URL}/usercollection/${id}/matches`, {
                headers: { Authorization: `Bearer ${token}` }
            });

            // Обновляем книгу с новыми аналогами
            setBook({
                ...book,
                suggestedMatches: response.data
            });
        } catch (err) {
            console.error('Error finding matches:', err);
            setError('Не удалось найти аналоги');
        } finally {
            setSearchingMatches(false);
        }
    };

    const handleSelectReference = async (referenceBookId) => {
        try {
            const token = Cookies.get('token');
            await axios.post(`${API_URL}/usercollection/${id}/reference`, 
                { referenceBookId: referenceBookId },
                { headers: { Authorization: `Bearer ${token}` } }
            );
            await loadBook();
            setError('');
        } catch (err) {
            console.error('Error selecting reference:', err);
            setError('Не удалось выбрать референсную книгу');
        }
    };

    const handleSetManualPrice = async () => {
        if (!manualPrice || isNaN(parseFloat(manualPrice))) {
            setError('Введите корректную цену');
            return;
        }

        try {
            const token = Cookies.get('token');
            const updateData = {
                id: parseInt(id),
                title: formData.title,
                author: formData.author || null,
                yearPublished: formData.yearPublished ? parseInt(formData.yearPublished) : null,
                description: formData.description || null,
                notes: formData.notes || null,
                estimatedPrice: parseFloat(manualPrice),
                referenceBookId: book.referenceBookId || null
            };

            await axios.put(`${API_URL}/usercollection/${id}`, updateData, {
                headers: { Authorization: `Bearer ${token}` }
            });

            await loadBook();
            setPriceDialogOpen(false);
            setManualPrice('');
        } catch (err) {
            console.error('Error setting manual price:', err);
            setError('Не удалось установить цену');
        }
    };

    if (loading) {
        return (
            <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '60vh' }}>
                <CircularProgress />
            </Box>
        );
    }

    if (!book) {
        return (
            <Box sx={{ maxWidth: 900, mx: 'auto', p: 3 }}>
                <Alert severity="error">Книга не найдена</Alert>
                <Button onClick={() => navigate('/collection')} sx={{ mt: 2 }}>
                    Вернуться к коллекции
                </Button>
            </Box>
        );
    }

    const images = book.images || [];
    const currentImage = images[currentImageIndex];

    return (
        <Box sx={{ maxWidth: 1200, mx: 'auto', p: { xs: 2, md: 3 }, overflowX: 'hidden' }}>
            {/* Шапка */}
            <Box sx={{ mb: 3 }}>
                {/* Кнопка "Назад" и заголовок */}
                <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 2, mb: 2 }}>
                    <Button
                        startIcon={<BackIcon />}
                        onClick={() => navigate('/collection')}
                        variant="outlined"
                        size="small"
                        sx={{ flexShrink: 0 }}
                    >
                        <Box component="span" sx={{ display: { xs: 'none', sm: 'inline' } }}>К коллекции</Box>
                        <Box component="span" sx={{ display: { xs: 'inline', sm: 'none' } }}>Назад</Box>
                    </Button>

                    <Typography 
                        variant="h5" 
                        component="h1" 
                        sx={{ 
                            fontWeight: 'bold', 
                            flexGrow: 1,
                            fontSize: { xs: '1.25rem', sm: '1.5rem' }
                        }}
                    >
                        {book.title}
                    </Typography>
                </Box>

                {/* Кнопки действий */}
                <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                    {!editMode ? (
                        <>
                            <Button
                                startIcon={<EditIcon />}
                                onClick={() => setEditMode(true)}
                                variant="outlined"
                                size="small"
                                fullWidth={false}
                                sx={{ flexGrow: { xs: 1, sm: 0 } }}
                            >
                                <Box component="span" sx={{ display: { xs: 'none', sm: 'inline' } }}>Редактировать</Box>
                                <Box component="span" sx={{ display: { xs: 'inline', sm: 'none' } }}>Ред.</Box>
                            </Button>
                            <Button
                                startIcon={<DeleteIcon />}
                                onClick={handleDelete}
                                color="error"
                                variant="outlined"
                                size="small"
                                fullWidth={false}
                                sx={{ flexGrow: { xs: 1, sm: 0 } }}
                            >
                                <Box component="span" sx={{ display: { xs: 'none', sm: 'inline' } }}>Удалить</Box>
                                <Box component="span" sx={{ display: { xs: 'inline', sm: 'none' } }}>Удал.</Box>
                            </Button>
                        </>
                    ) : (
                        <>
                            <Button
                                startIcon={<SaveIcon />}
                                onClick={handleUpdate}
                                variant="contained"
                                size="small"
                                fullWidth={false}
                                sx={{ flexGrow: { xs: 1, sm: 0 } }}
                            >
                                Сохранить
                            </Button>
                            <Button
                                startIcon={<CancelIcon />}
                                onClick={() => {
                                    setEditMode(false);
                                    setFormData({
                                        title: book.title || '',
                                        author: book.author || '',
                                        yearPublished: book.yearPublished || '',
                                        description: book.description || '',
                                        notes: book.notes || '',
                                        estimatedPrice: book.estimatedPrice || '',
                                        isManuallyPriced: book.isManuallyPriced || false
                                    });
                                }}
                                variant="outlined"
                                size="small"
                                fullWidth={false}
                                sx={{ flexGrow: { xs: 1, sm: 0 } }}
                            >
                                Отмена
                            </Button>
                        </>
                    )}
                </Box>
            </Box>

            {error && (
                <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError('')}>
                    {error}
                </Alert>
            )}

            <Grid container spacing={{ xs: 2, md: 3 }}>
                {/* Верхняя секция - информация о книге с фотографиями */}
                <Grid item xs={12}>
                    <Grid container spacing={{ xs: 2, md: 3 }}>
                        {/* Левая колонка - галерея и изображения */}
                        <Grid item xs={12} md={5}>
                    <Paper elevation={2} sx={{ p: { xs: 1.5, md: 2 }, mb: { xs: 1.5, md: 2 } }}>
                        {images.length > 0 ? (
                            <>
                                {/* Главное изображение */}
                                <Box
                                    sx={{
                                        position: 'relative',
                                        paddingTop: '100%',
                                        bgcolor: 'grey.100',
                                        borderRadius: 1,
                                        overflow: 'hidden',
                                        mb: 2
                                    }}
                                >
                                    <AuthorizedImage
                                        imageUrl={currentImage.imageUrl}
                                        alt={book.title}
                                        sx={{
                                            position: 'absolute',
                                            top: 0,
                                            left: 0,
                                            width: '100%',
                                            height: '100%',
                                            objectFit: 'contain'
                                        }}
                                    />

                                    {/* Навигация по изображениям */}
                                    {images.length > 1 && (
                                        <>
                                            <IconButton
                                                onClick={() => setCurrentImageIndex(Math.max(0, currentImageIndex - 1))}
                                                disabled={currentImageIndex === 0}
                                                size="small"
                                                sx={{
                                                    position: 'absolute',
                                                    left: { xs: 4, sm: 8 },
                                                    top: '50%',
                                                    transform: 'translateY(-50%)',
                                                    bgcolor: 'rgba(255,255,255,0.8)',
                                                    '&:hover': { bgcolor: 'white' }
                                                }}
                                            >
                                                <ChevronLeft fontSize="small" />
                                            </IconButton>

                                            <IconButton
                                                onClick={() => setCurrentImageIndex(Math.min(images.length - 1, currentImageIndex + 1))}
                                                disabled={currentImageIndex === images.length - 1}
                                                size="small"
                                                sx={{
                                                    position: 'absolute',
                                                    right: { xs: 4, sm: 8 },
                                                    top: '50%',
                                                    transform: 'translateY(-50%)',
                                                    bgcolor: 'rgba(255,255,255,0.8)',
                                                    '&:hover': { bgcolor: 'white' }
                                                }}
                                            >
                                                <ChevronRight fontSize="small" />
                                            </IconButton>

                                            <Box
                                                sx={{
                                                    position: 'absolute',
                                                    bottom: 8,
                                                    left: '50%',
                                                    transform: 'translateX(-50%)',
                                                    bgcolor: 'rgba(0,0,0,0.6)',
                                                    color: 'white',
                                                    px: 2,
                                                    py: 0.5,
                                                    borderRadius: 1
                                                }}
                                            >
                                                <Typography variant="caption">
                                                    {currentImageIndex + 1} / {images.length}
                                                </Typography>
                                            </Box>
                                        </>
                                    )}
                                </Box>

                                {/* Миниатюры */}
                                {images.length > 1 && (
                                    <Grid container spacing={1}>
                                        {images.map((img, idx) => (
                                            <Grid item xs={4} sm={3} key={img.id}>
                                                <Box
                                                    onClick={() => setCurrentImageIndex(idx)}
                                                    sx={{
                                                        paddingTop: '100%',
                                                        position: 'relative',
                                                        cursor: 'pointer',
                                                        border: '2px solid',
                                                        borderColor: idx === currentImageIndex ? 'primary.main' : 'transparent',
                                                        borderRadius: 1,
                                                        overflow: 'hidden',
                                                        '&:hover': {
                                                            borderColor: 'primary.light'
                                                        }
                                                    }}
                                                >
                                                    <AuthorizedImage
                                                        imageUrl={img.imageUrl}
                                                        alt=""
                                                        sx={{
                                                            position: 'absolute',
                                                            top: 0,
                                                            left: 0,
                                                            width: '100%',
                                                            height: '100%',
                                                            objectFit: 'cover'
                                                        }}
                                                    />
                                                </Box>
                                            </Grid>
                                        ))}
                                    </Grid>
                                )}
                            </>
                        ) : (
                            <Box
                                sx={{
                                    paddingTop: '100%',
                                    bgcolor: 'grey.100',
                                    borderRadius: 1,
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                    position: 'relative'
                                }}
                            >
                                <Typography
                                    variant="body2"
                                    color="text.secondary"
                                    sx={{ position: 'absolute', top: '50%', transform: 'translateY(-50%)' }}
                                >
                                    Нет изображений
                                </Typography>
                            </Box>
                        )}
                    </Paper>

                    {/* Загрузка изображений */}
                    {editMode && (
                        <Paper elevation={2} sx={{ p: { xs: 1.5, md: 2 } }}>
                            <Typography variant="h6" gutterBottom sx={{ fontSize: { xs: '1rem', sm: '1.25rem' } }}>
                                Управление изображениями
                            </Typography>
                            <CollectionImageUploader
                                images={images.map(img => ({
                                    ...img,
                                    imageUrl: `${API_URL}${img.imageUrl}`
                                }))}
                                onUpload={handleImageUpload}
                                onDelete={handleImageDelete}
                                onSetMain={handleSetMainImage}
                                uploading={uploading}
                                maxFiles={10}
                            />
                        </Paper>
                    )}
                        </Grid>

                        {/* Правая колонка - информация */}
                        <Grid item xs={12} md={7}>
                    {/* Основная информация */}
                    <Paper elevation={2} sx={{ p: { xs: 2, md: 3 }, mb: { xs: 2, md: 3 } }}>
                        {editMode ? (
                            <Grid container spacing={2}>
                                <Grid item xs={12}>
                                    <TextField
                                        label="Название"
                                        value={formData.title}
                                        onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                                        fullWidth
                                        required
                                    />
                                </Grid>
                                <Grid item xs={12} sm={6}>
                                    <TextField
                                        label="Автор"
                                        value={formData.author}
                                        onChange={(e) => setFormData({ ...formData, author: e.target.value })}
                                        fullWidth
                                    />
                                </Grid>
                                <Grid item xs={12} sm={6}>
                                    <TextField
                                        label="Год издания"
                                        type="number"
                                        value={formData.yearPublished}
                                        onChange={(e) => setFormData({ ...formData, yearPublished: e.target.value })}
                                        fullWidth
                                    />
                                </Grid>
                                <Grid item xs={12}>
                                    <TextField
                                        label="Описание и состояние"
                                        value={formData.description}
                                        onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                                        fullWidth
                                        multiline
                                        rows={4}
                                    />
                                </Grid>
                                <Grid item xs={12}>
                                    <TextField
                                        label="Личные заметки"
                                        value={formData.notes}
                                        onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                                        fullWidth
                                        multiline
                                        rows={3}
                                    />
                                </Grid>
                            </Grid>
                        ) : (
                            <>
                                <Typography 
                                    variant="h4" 
                                    gutterBottom 
                                    sx={{ 
                                        fontWeight: 'bold',
                                        fontSize: { xs: '1.5rem', sm: '2rem' }
                                    }}
                                >
                                    {book.title}
                                </Typography>

                                {book.author && (
                                    <Typography 
                                        variant="h6" 
                                        color="text.secondary" 
                                        gutterBottom
                                        sx={{ fontSize: { xs: '1rem', sm: '1.25rem' } }}
                                    >
                                        {book.author}
                                    </Typography>
                                )}

                                {book.yearPublished && (
                                    <Typography variant="body1" gutterBottom>
                                        Год издания: <strong>{book.yearPublished}</strong>
                                    </Typography>
                                )}

                                {book.description && (
                                    <>
                                        <Divider sx={{ my: 2 }} />
                                        <Typography variant="subtitle2" gutterBottom>
                                            Описание и состояние:
                                        </Typography>
                                        <Typography variant="body2" paragraph>
                                            {book.description}
                                        </Typography>
                                    </>
                                )}

                                {book.notes && (
                                    <>
                                        <Divider sx={{ my: 2 }} />
                                        <Typography variant="subtitle2" gutterBottom>
                                            Личные заметки:
                                        </Typography>
                                        <Typography variant="body2" paragraph sx={{ fontStyle: 'italic' }}>
                                            {book.notes}
                                        </Typography>
                                    </>
                                )}

                                <Divider sx={{ my: 2 }} />

                                <Typography variant="caption" color="text.secondary" display="block">
                                    Добавлено: {new Date(book.addedDate).toLocaleDateString('ru-RU')}
                                </Typography>
                                <Typography variant="caption" color="text.secondary" display="block">
                                    Обновлено: {new Date(book.updatedDate).toLocaleDateString('ru-RU')}
                                </Typography>
                            </>
                        )}
                    </Paper>

                    {/* Оценка стоимости */}
                    <Card elevation={2} sx={{ mb: 3, background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)', color: 'white' }}>
                        <CardContent>
                            <Typography variant="h6" gutterBottom sx={{ fontSize: { xs: '1rem', sm: '1.25rem' } }}>
                                Оценка стоимости
                            </Typography>

                            {book.estimatedPrice ? (
                                <>
                                    <Typography 
                                        variant="h3" 
                                        sx={{ 
                                            fontWeight: 'bold', 
                                            mb: 1,
                                            fontSize: { xs: '2rem', sm: '3rem' }
                                        }}
                                    >
                                        {book.estimatedPrice.toLocaleString('ru-RU')} ₽
                                    </Typography>
                                    <Chip
                                        label={book.isManuallyPriced ? 'Установлено вручную' : 'Автоматическая оценка'}
                                        size="small"
                                        sx={{ bgcolor: 'rgba(255,255,255,0.3)', color: 'white', mb: 2 }}
                                    />

                                    {book.referenceBook && !book.isManuallyPriced && (
                                        <Typography variant="body2" sx={{ opacity: 0.9, fontSize: { xs: '0.75rem', sm: '0.875rem' } }}>
                                            На основе книги: {book.referenceBook.title}
                                            {book.referenceBookId && (
                                                <span> (ID: {book.referenceBookId})</span>
                                            )}
                                        </Typography>
                                    )}
                                </>
                            ) : (
                                <Typography variant="body1" sx={{ mb: 2 }}>
                                    Оценка еще не установлена
                                </Typography>
                            )}

                            <Button
                                variant="contained"
                                startIcon={<MoneyIcon />}
                                onClick={() => {
                                    setManualPrice(book.estimatedPrice || '');
                                    setPriceDialogOpen(true);
                                }}
                                size="small"
                                sx={{ bgcolor: 'white', color: 'primary.main', '&:hover': { bgcolor: 'grey.100' } }}
                                fullWidth
                            >
                                <Box component="span" sx={{ display: { xs: 'none', sm: 'inline' } }}>Установить цену вручную</Box>
                                <Box component="span" sx={{ display: { xs: 'inline', sm: 'none' } }}>Установить цену</Box>
                            </Button>
                        </CardContent>
                    </Card>

                        </Grid>
                    </Grid>
                </Grid>

                {/* Нижняя секция - найденные аналоги на всю ширину */}
                <Grid item xs={12}>
                    <Paper elevation={2} sx={{ p: { xs: 2, md: 3 } }}>
                        <Box sx={{ 
                            display: 'flex', 
                            flexDirection: { xs: 'column', sm: 'row' },
                            justifyContent: 'space-between', 
                            alignItems: { xs: 'flex-start', sm: 'center' }, 
                            mb: 2,
                            gap: { xs: 1, sm: 0 }
                        }}>
                            <Typography variant="h6" sx={{ fontSize: { xs: '1rem', sm: '1.25rem' } }}>
                                Найденные аналоги
                            </Typography>
                            <Button
                                variant="outlined"
                                size="small"
                                startIcon={searchingMatches ? <CircularProgress size={16} /> : <SearchIcon />}
                                onClick={handleFindMatches}
                                disabled={searchingMatches}
                                fullWidth={false}
                                sx={{ width: { xs: '100%', sm: 'auto' } }}
                            >
                                {searchingMatches ? 'Поиск...' : 'Обновить'}
                            </Button>
                        </Box>

                        <CollectionBookMatches
                            matches={book.suggestedMatches || []}
                            onSelectReference={handleSelectReference}
                            selectedReferenceId={book.referenceBookId}
                            loading={searchingMatches}
                            bookId={book.id}
                            bookTitle={book.title}
                        />
                    </Paper>
                </Grid>
            </Grid>

            {/* Диалог установки цены вручную */}
            <Dialog open={priceDialogOpen} onClose={() => setPriceDialogOpen(false)} maxWidth="xs" fullWidth>
                <DialogTitle>Установить цену вручную</DialogTitle>
                <DialogContent>
                    <TextField
                        label="Цена (руб.)"
                        type="number"
                        value={manualPrice}
                        onChange={(e) => setManualPrice(e.target.value)}
                        fullWidth
                        autoFocus
                        sx={{ mt: 2 }}
                        inputProps={{ min: 0, step: 0.01 }}
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setPriceDialogOpen(false)}>Отмена</Button>
                    <Button onClick={handleSetManualPrice} variant="contained">Сохранить</Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default CollectionBookDetail;

