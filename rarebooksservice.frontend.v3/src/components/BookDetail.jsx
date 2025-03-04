// src/components/BookDetail.jsx
import React, { useEffect, useState, useRef } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import {
    getBookById,
    getBookImages,
    getBookImageFile,
    getPriceHistory,
    API_URL,
    getAuthHeaders
} from '../api';
import { 
    Card, 
    CardContent, 
    Typography, 
    Box, 
    Button, 
    Container, 
    Paper, 
    Grid, 
    Divider, 
    Chip, 
    CircularProgress, 
    Alert,
    useMediaQuery,
    useTheme,
    IconButton
} from '@mui/material';
import Lightbox from 'yet-another-react-lightbox';
import 'yet-another-react-lightbox/styles.css';
import DOMPurify from 'dompurify';
import Cookies from 'js-cookie';

const BookDetail = () => {
    const { id } = useParams();
    const navigate = useNavigate();
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));

    const [book, setBook] = useState(null);
    const [bookImages, setBookImages] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [open, setOpen] = useState(false);
    const [selectedImageIndex, setSelectedImageIndex] = useState(0);
    const [priceHistory, setPriceHistory] = useState([]);

    // Отслеживание загрузки деталей книги
    const [loadingBook, setLoadingBook] = useState(true);
    // Отслеживание загрузки изображений
    const [loadingImages, setLoadingImages] = useState(true);
    // Отслеживание загрузки истории цен
    const [loadingPriceHistory, setLoadingPriceHistory] = useState(true);

    useEffect(() => {
        const fetchBookData = async () => {
            setLoadingBook(true);
            try {
                const response = await getBookById(id);
                setBook(response.data);
                setError(null);
            } catch (err) {
                console.error('Ошибка при загрузке данных книги:', err);
                setError('Не удалось загрузить информацию о книге. Пожалуйста, попробуйте позже.');
            } finally {
                setLoadingBook(false);
                // Инициируем загрузку связанных данных
                fetchBookImages();
                fetchPriceHistory(id);
            }
        };

        const fetchBookImages = async () => {
            setLoadingImages(true);
            try {
                // Запрашиваем список изображений книги
                const imagesResponse = await getBookImages(id);
                const imageNames = imagesResponse?.data?.images || [];
                
                // Если нет изображений - сразу завершаем
                if (imageNames.length === 0) {
                    setLoadingImages(false);
                    return;
                }
                
                // Для каждого имени изображения загружаем его асинхронно
                imageNames.forEach(async (imageName, index) => {
                    try {
                        // Загружаем изображение через API с авторизацией
                        const imageResponse = await getBookImageFile(id, imageName);
                        
                        // Создаем объект URL из blob данных
                        const imageUrl = URL.createObjectURL(imageResponse.data);
                        
                        // Создаем объект изображения
                        const imageData = {
                            imageUrl: imageUrl,
                            thumbnailUrl: imageUrl,
                            name: imageName,
                            index: index // для сохранения порядка
                        };
                        
                        // Добавляем изображение в состояние по мере загрузки
                        setBookImages(prevImages => {
                            const newImages = [...prevImages];
                            // Добавляем новое изображение
                            newImages.push(imageData);
                            // Сортируем по индексу для соблюдения исходного порядка
                            return newImages.sort((a, b) => a.index - b.index);
                        });
                        
                        // Если это последнее изображение, отмечаем загрузку как завершенную
                        if (index === imageNames.length - 1) {
                            setLoadingImages(false);
                        }
                    } catch (imgError) {
                        console.error(`Ошибка при загрузке изображения ${imageName}:`, imgError);
                        // Даже при ошибке отдельного изображения, продолжаем загрузку остальных
                    }
                });
                
                // На случай если ни одно изображение не загрузится, устанавливаем флаг загрузки в false
                setTimeout(() => {
                    setLoadingImages(false);
                }, 5000); // Таймаут 5 секунд
                
            } catch (err) {
                console.error('Ошибка при загрузке списка изображений:', err);
                setLoadingImages(false);
            }
        };

        fetchBookData();
        
        // Очистка URL объектов при размонтировании компонента
        return () => {
            // Очистка URL для основных изображений
            bookImages.forEach(img => {
                if (img.imageUrl && img.imageUrl.startsWith('blob:')) {
                    URL.revokeObjectURL(img.imageUrl);
                }
            });
        };
    }, [id]);

    // Отдельный эффект для обновления общего состояния загрузки
    useEffect(() => {
        // Компонент считается полностью загруженным, только когда загружены
        // основные данные книги (наиболее важные)
        setLoading(loadingBook);
    }, [loadingBook]);

    const fetchPriceHistory = async (bookId) => {
        setLoadingPriceHistory(true);
        try {
            const response = await getPriceHistory(bookId);
            console.log('История цен (полный ответ):', response);
            console.log('История цен (данные):', response?.data);
            
            // Проверяем оба варианта названия свойства (с учетом регистра)
            console.log('PricePoints в истории цен:', response?.data?.PricePoints);
            console.log('pricePoints (нижний регистр) в истории цен:', response?.data?.pricePoints);
            
            const pricePoints = response?.data?.PricePoints || response?.data?.pricePoints;
            console.log('Объединенные точки истории цен:', pricePoints);
            console.log('Количество точек в истории цен:', pricePoints?.length || 0);
            
            // Обработка данных с учетом возможной разницы в регистре имен свойств
            if (response?.data) {
                const processedData = {
                    ...response.data,
                    // Используем свойство независимо от регистра
                    PricePoints: response.data.PricePoints || response.data.pricePoints || [],
                    KeywordsUsed: response.data.KeywordsUsed || response.data.keywordsUsed || []
                };
                
                console.log('Обработанные данные истории цен:', processedData);
                setPriceHistory(processedData);
            } else {
                console.log('История цен пуста или имеет неправильный формат');
                setPriceHistory([]);
            }
        } catch (error) {
            console.error('Ошибка при загрузке истории цен:', error);
            setPriceHistory([]);
        } finally {
            setLoadingPriceHistory(false);
        }
    };

    const handleImageClick = (index) => {
        setSelectedImageIndex(index);
        setOpen(true);
    };

    // Форматирование даты
    const formatDate = (dateString) => {
        try {
            if (!dateString) return 'Не указана';
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
            
            const date = new Date(dateString);
            
            // Проверка валидности даты
            if (isNaN(date.getTime())) {
                return dateString; // Возвращаем исходную строку если дата невалидна
            }
            
            return new Intl.DateTimeFormat('ru-RU', {
                day: 'numeric',
                month: 'long',
                year: 'numeric'
            }).format(date);
        } catch (error) {
            console.error('Ошибка при форматировании даты:', error);
            return dateString;
        }
    };

    // Безопасное отображение цены
    const formatPrice = (price) => {
        if (price === undefined || price === null) return 'Нет данных';
        if (price === 'Только для подписчиков') return price;
        
        try {
            return `${Number(price).toLocaleString()} ₽`;
        } catch (error) {
            return `${price} ₽`;
        }
    };

    // Функция для проверки, является ли строка полным URL-адресом
    const isFullUrl = (str) => {
        console.log('Проверка URL:', str);
        
        if (!str) {
            console.log('URL пустой');
            return false;
        }
        
        try {
            // Точная проверка на http:// и https://
            if (str.toLowerCase().startsWith('http://') || str.toLowerCase().startsWith('https://')) {
                console.log('URL начинается с http:// или https://', str);
                return true;
            }
            
            // Дополнительная проверка для URL с www. или протоколом без //
            const urlPattern = /^((https?:|www\.)[/]{0,2}|[/]{2})([a-zA-Z0-9-]+\.)+[a-zA-Z0-9]{2,}(:[0-9]+)?(\/[^?#]*)?(\?[^#]*)?(#.*)?$/i;
            const isUrl = urlPattern.test(str);
            console.log('Результат проверки регулярным выражением:', isUrl);
            
            return isUrl;
        } catch (e) {
            console.error('Ошибка при проверке URL:', e);
            return false;
        }
    };

    // Для предотвращения зацикливаний запросов и ошибок
    useEffect(() => {
        // Функция для очистки консоли от ошибок, чтобы улучшить отладку
        const clearConsoleErrors = () => {
            console.clear();
            console.log('Консоль очищена для улучшения отладки');
        };

        // Устанавливаем таймер для периодической очистки консоли
        const cleanupInterval = setInterval(clearConsoleErrors, 10000);
        
        return () => {
            clearInterval(cleanupInterval);
        };
    }, []);

    // Метод для безопасного получения URL изображения
    const getSafeImageUrl = (imagePathOrUrl, bookId) => {
        console.log('getSafeImageUrl вызван с параметрами:', { imagePathOrUrl, bookId });
        
        if (!imagePathOrUrl) {
            console.log('Путь к изображению пустой, возвращаю placeholder');
            return '/placeholder-book.png';
        }
        
        if (isFullUrl(imagePathOrUrl)) {
            console.log('Обнаружен полный URL, возвращаю как есть:', imagePathOrUrl);
            return imagePathOrUrl; // Возвращаем полный URL как есть
        } else {
            // Обрабатываем как имя файла
            const url = `${API_URL}/books/${bookId || id}/images/${imagePathOrUrl}`;
            console.log('Сформирован URL для изображения:', url);
            return url;
        }
    };

    // Обновленный рендеринг для десктопной и мобильной версии
    return (
        <Container maxWidth="lg" className={isMobile ? "book-detail-container mobile-container" : "book-detail-container"}>
            {loadingBook ? (
                <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
                    <CircularProgress />
                </Box>
            ) : error ? (
                <Alert severity="error" sx={{ mt: 2 }}>{error}</Alert>
            ) : book ? (
                <>
                    <Button 
                        variant="outlined" 
                        onClick={() => navigate(-1)} 
                        sx={{ mb: 2, mt: 2 }}
                    >
                        Назад
                    </Button>
                    
                    <Card sx={{ mb: 4 }} className="book-detail-card">
                        <CardContent>
                            <Grid container spacing={isMobile ? 2 : 4}>
                                {/* Блок с изображениями */}
                                <Grid item xs={12} md={5}>
                                    {loadingImages ? (
                                        <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '300px' }}>
                                            <CircularProgress />
                                        </Box>
                                    ) : bookImages.length > 0 ? (
                                        <Box className="book-images-container">
                                            <Box 
                                                className="main-image-container"
                                                sx={{ 
                                                    height: isMobile ? '200px' : '300px',
                                                    display: 'flex',
                                                    justifyContent: 'center',
                                                    mb: 2
                                                }}
                                            >
                                                <img 
                                                    src={bookImages[selectedImageIndex]?.imageUrl} 
                                                    alt={`${book.title} - изображение ${selectedImageIndex + 1}`}
                                                    style={{ 
                                                        maxHeight: '100%', 
                                                        maxWidth: '100%',
                                                        objectFit: 'contain',
                                                        cursor: 'pointer'
                                                    }}
                                                    onClick={() => setOpen(true)}
                                                />
                                            </Box>
                                            
                                            <Box className="thumbnail-container">
                                                {bookImages.map((img, index) => (
                                                    <Box 
                                                        key={index}
                                                        className={`thumbnail ${selectedImageIndex === index ? 'active' : ''}`}
                                                        onClick={() => setSelectedImageIndex(index)}
                                                        sx={{
                                                            width: isMobile ? '60px' : '80px',
                                                            height: isMobile ? '60px' : '80px',
                                                            border: selectedImageIndex === index ? '2px solid #E72B3D' : '1px solid #ddd',
                                                            overflow: 'hidden',
                                                            display: 'inline-flex',
                                                            justifyContent: 'center',
                                                            alignItems: 'center',
                                                            marginRight: '8px',
                                                            borderRadius: '4px',
                                                            cursor: 'pointer'
                                                        }}
                                                    >
                                                        <img 
                                                            src={img.imageUrl} 
                                                            alt={`Миниатюра ${index + 1}`}
                                                            style={{ maxHeight: '100%', maxWidth: '100%', objectFit: 'contain' }}
                                                        />
                                                    </Box>
                                                ))}
                                            </Box>
                                        </Box>
                                    ) : (
                                        <Box sx={{ 
                                            height: isMobile ? '200px' : '300px', 
                                            display: 'flex', 
                                            justifyContent: 'center', 
                                            alignItems: 'center',
                                            backgroundColor: '#f5f5f5'
                                        }}>
                                            <Typography variant="body1" color="textSecondary">
                                                Изображения отсутствуют
                                            </Typography>
                                        </Box>
                                    )}
                                </Grid>
                                
                                {/* Информация о книге */}
                                <Grid item xs={12} md={7} className="book-detail-content">
                                    <Typography variant={isMobile ? "h5" : "h4"} component="h1" gutterBottom sx={{ fontWeight: 'bold' }}>
                                        {book.title}
                                    </Typography>
                                    
                                    <Typography variant="h6" color="error" sx={{ mb: 2, fontWeight: 'bold' }}>
                                        {book.price?.toLocaleString('ru-RU')} ₽
                                    </Typography>
                                    
                                    <Box sx={{ mb: 2 }}>
                                        <Grid container spacing={1}>
                                            <Grid item xs={isMobile ? 4 : 3}>
                                                <Typography variant="body2" color="textSecondary">
                                                    Автор:
                                                </Typography>
                                            </Grid>
                                            <Grid item xs={isMobile ? 8 : 9}>
                                                <Typography variant="body2">
                                                    {book.author || 'Не указан'}
                                                </Typography>
                                            </Grid>
                                        </Grid>
                                        
                                        <Grid container spacing={1}>
                                            <Grid item xs={isMobile ? 4 : 3}>
                                                <Typography variant="body2" color="textSecondary">
                                                    Издательство:
                                                </Typography>
                                            </Grid>
                                            <Grid item xs={isMobile ? 8 : 9}>
                                                <Typography variant="body2">
                                                    {book.publisher || 'Не указано'}
                                                </Typography>
                                            </Grid>
                                        </Grid>
                                        
                                        <Grid container spacing={1}>
                                            <Grid item xs={isMobile ? 4 : 3}>
                                                <Typography variant="body2" color="textSecondary">
                                                    Год издания:
                                                </Typography>
                                            </Grid>
                                            <Grid item xs={isMobile ? 8 : 9}>
                                                <Typography variant="body2">
                                                    {book.yearPublished || 'Не указан'}
                                                </Typography>
                                            </Grid>
                                        </Grid>
                                        
                                        <Grid container spacing={1}>
                                            <Grid item xs={isMobile ? 4 : 3}>
                                                <Typography variant="body2" color="textSecondary">
                                                    Категория:
                                                </Typography>
                                            </Grid>
                                            <Grid item xs={isMobile ? 8 : 9}>
                                                <Typography variant="body2">
                                                    {book.category || 'Не указана'}
                                                </Typography>
                                            </Grid>
                                        </Grid>
                                    </Box>
                                    
                                    <Divider sx={{ my: 2 }} />
                                    
                                    <Typography variant="subtitle1" gutterBottom sx={{ fontWeight: 'bold' }}>
                                        Описание
                                    </Typography>
                                    
                                    <Typography 
                                        variant="body2" 
                                        component="div"
                                        sx={{ 
                                            whiteSpace: 'pre-line',
                                            mb: 2,
                                            maxHeight: isMobile ? '150px' : '200px',
                                            overflowY: 'auto'
                                        }}
                                        dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(book.description || 'Описание отсутствует') }}
                                    />
                                    
                                    <Box className="book-detail-actions" sx={{ 
                                        display: 'flex', 
                                        gap: 2, 
                                        mt: 2,
                                        flexDirection: isMobile ? 'column' : 'row'
                                    }}>
                                        <Button 
                                            variant="contained" 
                                            color="primary" 
                                            fullWidth={isMobile}
                                            onClick={() => window.open(`mailto:?subject=Информация о книге: ${book.title}&body=Посмотрите эту книгу: ${window.location.href}`, '_blank')}
                                        >
                                            Поделиться
                                        </Button>
                                        <Button 
                                            variant="outlined" 
                                            fullWidth={isMobile}
                                            onClick={() => navigate(`/seller/${book.sellerId}`)}
                                        >
                                            Продавец
                                        </Button>
                                    </Box>
                                </Grid>
                            </Grid>
                        </CardContent>
                    </Card>
                    
                    {/* История цен */}
                    <Card sx={{ mb: 4 }}>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>
                                История цен
                            </Typography>
                            
                            {loadingPriceHistory ? (
                                <Box sx={{ display: 'flex', justifyContent: 'center', my: 2 }}>
                                    <CircularProgress size={30} />
                                </Box>
                            ) : priceHistory.length > 0 ? (
                                <Box className="table-container">
                                    <table className="responsive-table">
                                        <thead>
                                            <tr>
                                                <th>Дата</th>
                                                <th>Цена</th>
                                                <th>Изменение</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {priceHistory.map((item, index) => {
                                                const prevPrice = index < priceHistory.length - 1 ? priceHistory[index + 1].price : null;
                                                const priceDiff = prevPrice !== null ? item.price - prevPrice : 0;
                                                const percentChange = prevPrice !== null ? (priceDiff / prevPrice) * 100 : 0;
                                                
                                                return (
                                                    <tr key={index}>
                                                        <td>{new Date(item.date).toLocaleDateString('ru-RU')}</td>
                                                        <td>{item.price.toLocaleString('ru-RU')} ₽</td>
                                                        <td>
                                                            {prevPrice !== null && (
                                                                <Box sx={{ 
                                                                    color: priceDiff > 0 ? 'error.main' : priceDiff < 0 ? 'success.main' : 'text.secondary',
                                                                    display: 'flex',
                                                                    alignItems: 'center'
                                                                }}>
                                                                    {priceDiff > 0 ? '+' : ''}{priceDiff.toLocaleString('ru-RU')} ₽
                                                                    <Typography variant="caption" sx={{ ml: 1 }}>
                                                                        ({priceDiff > 0 ? '+' : ''}{percentChange.toFixed(1)}%)
                                                                    </Typography>
                                                                </Box>
                                                            )}
                                                        </td>
                                                    </tr>
                                                );
                                            })}
                                        </tbody>
                                    </table>
                                </Box>
                            ) : (
                                <Typography variant="body2" color="textSecondary">
                                    История цен отсутствует
                                </Typography>
                            )}
                        </CardContent>
                    </Card>
                </>
            ) : null}
            
            {/* Лайтбокс для просмотра изображений */}
            {bookImages.length > 0 && (
                <Lightbox
                    open={open}
                    close={() => setOpen(false)}
                    slides={bookImages.map(img => ({ src: img.imageUrl }))}
                    index={selectedImageIndex}
                />
            )}
        </Container>
    );
};

export default BookDetail;
