// src/components/BookDetail.jsx
import React, { useEffect, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import {
    getBookById,
    getBookImages,
    getBookImageFile,
    getPriceHistory,
    API_URL,
    getAuthHeaders
} from '../api';
import { Card, CardContent, Typography, Box, Button, Container, Paper, Grid, Divider, Chip, CircularProgress, Alert } from '@mui/material';
import Lightbox from 'yet-another-react-lightbox';
import 'yet-another-react-lightbox/styles.css';
import DOMPurify from 'dompurify';
import Cookies from 'js-cookie';

const BookDetail = () => {
    const { id } = useParams();
    const navigate = useNavigate();

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

    // Рендеринг содержимого компонента
    return (
        <Container maxWidth="lg" sx={{ py: 4 }}>
            {error ? (
                <Alert severity="error" sx={{ mb: 3 }}>
                    {error}
                </Alert>
            ) : (
                <>
                    {/* Основная информация о книге */}
                    {loadingBook ? (
                        <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
                            <CircularProgress />
                        </Box>
                    ) : book ? (
                        <>
                            <Box sx={{ mb: 4, display: 'flex', alignItems: 'center' }}>
                                <Button 
                                    onClick={() => navigate(-1)} 
                                    variant="outlined" 
                                    sx={{ mr: 2, borderRadius: '8px' }}
                                >
                                    Назад
                                </Button>
                                <Typography variant="h4" component="h1" fontWeight="bold">
                                    Информация о книге
                                </Typography>
                            </Box>

                            <Paper elevation={2} sx={{ p: 3, borderRadius: '12px', mb: 4 }}>
                                <Grid container spacing={4}>
                                    {/* Галерея изображений */}
                                    <Grid item xs={12} md={6}>
                                        {/* Основное изображение */}
                                        <Box
                                            sx={{ 
                                                height: 400, 
                                                display: 'flex',
                                                alignItems: 'center',
                                                justifyContent: 'center',
                                                bgcolor: '#f5f5f5',
                                                borderRadius: '8px',
                                                mb: 2,
                                                overflow: 'hidden',
                                                position: 'relative'
                                            }}
                                        >
                                            {loadingImages && bookImages.length === 0 ? (
                                                <CircularProgress />
                                            ) : bookImages.length > 0 && bookImages[selectedImageIndex] ? (
                                                <img
                                                    src={bookImages[selectedImageIndex].imageUrl}
                                                    alt={book.title || 'Изображение книги'}
                                                    style={{ 
                                                        maxWidth: '100%', 
                                                        maxHeight: '100%', 
                                                        objectFit: 'contain',
                                                        cursor: 'pointer'
                                                    }}
                                                    onClick={() => setOpen(true)}
                                                />
                                            ) : (
                                                <Typography variant="body1" color="text.secondary">
                                                    Изображение отсутствует
                                                </Typography>
                                            )}
                                        </Box>
                                        
                                        {/* Миниатюры - отображаем по мере загрузки */}
                                        <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', minHeight: 70 }}>
                                            {bookImages.length > 1 && bookImages.map((image, index) => (
                                                <Box
                                                    key={index}
                                                    sx={{
                                                        width: 70,
                                                        height: 70,
                                                        borderRadius: '8px',
                                                        overflow: 'hidden',
                                                        cursor: 'pointer',
                                                        border: index === selectedImageIndex ? '2px solid var(--primary-color)' : '2px solid transparent',
                                                        transition: 'all 0.2s'
                                                    }}
                                                    onClick={() => setSelectedImageIndex(index)}
                                                >
                                                    <img
                                                        src={image.thumbnailUrl || image.imageUrl}
                                                        alt={`${book.title || 'Книга'} - миниатюра ${index + 1}`}
                                                        style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                                                    />
                                                </Box>
                                            ))}
                                            {loadingImages && bookImages.length > 0 && (
                                                <Box
                                                    sx={{
                                                        width: 70,
                                                        height: 70,
                                                        borderRadius: '8px',
                                                        display: 'flex',
                                                        alignItems: 'center',
                                                        justifyContent: 'center',
                                                        backgroundColor: '#f5f5f5'
                                                    }}
                                                >
                                                    <CircularProgress size={30} />
                                                </Box>
                                            )}
                                        </Box>
                                    </Grid>
                                    
                                    {/* Информация о книге */}
                                    <Grid item xs={12} md={6}>
                                        <Typography variant="h4" gutterBottom fontWeight="bold">
                                            {book.title || 'Без названия'}
                                        </Typography>
                                        
                                        {book.author && (
                                            <Typography variant="subtitle1" color="text.secondary" gutterBottom>
                                                {book.author}
                                            </Typography>
                                        )}
                                        
                                        <Box sx={{ mb: 3, mt: 2 }}>
                                            {book.year && (
                                                <Chip 
                                                    label={`${book.year || 'Н/Д'} год`} 
                                                    sx={{ mr: 1, mb: 1 }} 
                                                    variant="outlined"
                                                />
                                            )}
                                            {book.sellerName && (
                                                <Chip 
                                                    label={`Продавец: ${book.sellerName}`} 
                                                    color="primary" 
                                                    sx={{ mr: 1, mb: 1 }} 
                                                    component={Link}
                                                    to={`/searchBySeller/${book.sellerName}`}
                                                    clickable
                                                />
                                            )}
                                            {book.type && (
                                                <Chip 
                                                    label={book.type} 
                                                    color="secondary" 
                                                    sx={{ mr: 1, mb: 1 }}
                                                />
                                            )}
                                        </Box>
                                        
                                        <Divider sx={{ my: 2 }} />
                                        
                                        <Box sx={{ mb: 3 }}>
                                            <Typography variant="h6" gutterBottom>
                                                Цена
                                            </Typography>
                                            <Typography variant="h3" color="primary" fontWeight="bold">
                                                {formatPrice(book.finalPrice)}
                                            </Typography>
                                            <Typography variant="body2" color="text.secondary">
                                                Дата продажи: {formatDate(book.endDate)}
                                            </Typography>
                                        </Box>
                                        
                                        {book.description && (
                                            <Box sx={{ mb: 3 }}>
                                                <Typography variant="h6" gutterBottom>
                                                    Описание
                                                </Typography>
                                                <Typography variant="body1" 
                                                    dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(book.description) }} 
                                                />
                                            </Box>
                                        )}
                                    </Grid>
                                </Grid>
                            </Paper>
                            
                            {/* Блок для истории цен и графика */}
                            <Grid container spacing={4}>
                                <Grid item xs={12} md={12}>
                                    <Paper elevation={2} sx={{ p: 3, borderRadius: '12px', mb: 4 }}>
                                        <Typography variant="h5" gutterBottom fontWeight="bold">
                                            История цен
                                        </Typography>
                                        
                                        {loadingPriceHistory ? (
                                            <Box sx={{ display: 'flex', justifyContent: 'center', py: 3 }}>
                                                <CircularProgress />
                                            </Box>
                                        ) : priceHistory && (priceHistory.PricePoints || priceHistory.pricePoints) && 
                                           ((priceHistory.PricePoints && priceHistory.PricePoints.length > 0) || 
                                            (priceHistory.pricePoints && priceHistory.pricePoints.length > 0)) ? (
                                            <div>
                                                <Typography variant="body2" color="text.secondary" gutterBottom>
                                                    Средняя цена: {formatPrice(priceHistory.AveragePrice || priceHistory.averagePrice)}
                                                </Typography>
                                                
                                                {(priceHistory.KeywordsUsed || priceHistory.keywordsUsed) && 
                                                 ((priceHistory.KeywordsUsed && priceHistory.KeywordsUsed.length > 0) || 
                                                  (priceHistory.keywordsUsed && priceHistory.keywordsUsed.length > 0)) && (
                                                    <Box sx={{ mb: 2 }}>
                                                        <Typography variant="body2" color="text.secondary">
                                                            Ключевые слова для поиска: 
                                                        </Typography>
                                                        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1, mt: 1 }}>
                                                            {(priceHistory.KeywordsUsed || priceHistory.keywordsUsed || []).map((keyword, idx) => (
                                                                <Chip 
                                                                    key={idx} 
                                                                    label={keyword} 
                                                                    size="small" 
                                                                    color="primary" 
                                                                    variant="outlined"
                                                                />
                                                            ))}
                                                        </Box>
                                                    </Box>
                                                )}
                                                
                                                <Grid container spacing={2} sx={{ mt: 2 }}>
                                                    {(priceHistory.PricePoints || priceHistory.pricePoints || []).map((point, index) => (
                                                        <Grid item xs={12} sm={6} md={4} key={index}>
                                                            <Card 
                                                                elevation={1} 
                                                                sx={{ 
                                                                    height: '100%', 
                                                                    borderRadius: '8px',
                                                                    transition: 'transform 0.2s ease, box-shadow 0.2s ease',
                                                                    '&:hover': {
                                                                        transform: 'translateY(-4px)',
                                                                        boxShadow: '0 8px 24px rgba(0,0,0,0.12)'
                                                                    },
                                                                    cursor: (point.BookId || point.bookId) ? 'pointer' : 'default'
                                                                }}
                                                                onClick={() => {
                                                                    const pointId = point.BookId || point.bookId;
                                                                    const bookId = book?.id || book?.Id;
                                                                    if (pointId && pointId !== bookId) {
                                                                        navigate(`/books/${pointId}`);
                                                                    }
                                                                }}
                                                            >
                                                                <Box 
                                                                    sx={{ 
                                                                        height: 180, 
                                                                        bgcolor: '#f5f5f5',
                                                                        display: 'flex',
                                                                        alignItems: 'center',
                                                                        justifyContent: 'center',
                                                                        overflow: 'hidden'
                                                                    }}
                                                                >
                                                                    {(point.FirstImageName || point.firstImageName) ? (
                                                                        <img
                                                                            src={getSafeImageUrl(point.FirstImageName || point.firstImageName, point.BookId || point.bookId)}
                                                                            alt={(point.Title || point.title) || (priceHistory.Title || priceHistory.title) || 'Книга'}
                                                                            style={{ maxHeight: '100%', maxWidth: '100%', objectFit: 'contain' }}
                                                                            onError={(e) => {
                                                                                // При ошибке загрузки отключаем повторные попытки
                                                                                e.target.onerror = null;
                                                                                e.target.src = '/placeholder-book.png';
                                                                            }}
                                                                        />
                                                                    ) : (
                                                                        <Typography variant="body2" color="text.secondary">
                                                                            Изображение недоступно
                                                                        </Typography>
                                                                    )}
                                                                </Box>
                                                                <CardContent>
                                                                    <Typography variant="h6" component="h3" gutterBottom>
                                                                        {(point.Title || point.title) || (priceHistory.Title || priceHistory.title) || 'Книга'}
                                                                    </Typography>
                                                                    <Typography variant="body2" color="text.secondary" gutterBottom>
                                                                        Дата продажи: {formatDate(point.Date || point.date)}
                                                                    </Typography>
                                                                    <Typography variant="h5" color="primary" fontWeight="bold">
                                                                        {formatPrice(point.Price || point.price)}
                                                                    </Typography>
                                                                    <Typography variant="body2" color="text.secondary">
                                                                        {point.Source || point.source}
                                                                    </Typography>
                                                                </CardContent>
                                                            </Card>
                                                        </Grid>
                                                    ))}
                                                </Grid>
                                            </div>
                                        ) : (
                                            <div>
                                                <Typography variant="body1" color="text.secondary" sx={{ mb: 2 }}>
                                                    История цен недоступна для этой книги
                                                </Typography>
                                                
                                                <Box sx={{ 
                                                    p: 3, 
                                                    bgcolor: '#f5f5f5', 
                                                    borderRadius: '8px',
                                                    textAlign: 'center'
                                                }}>
                                                    <Typography variant="h6" color="text.secondary" gutterBottom>
                                                        Отладочная информация
                                                    </Typography>
                                                    <Typography variant="body2" color="text.secondary">
                                                        priceHistory доступен: {priceHistory ? 'Да' : 'Нет'}
                                                    </Typography>
                                                    <Typography variant="body2" color="text.secondary">
                                                        PricePoints доступны: {priceHistory?.PricePoints ? 'Да' : 'Нет'} 
                                                        (размер: {priceHistory?.PricePoints?.length || 0})
                                                    </Typography>
                                                    <Typography variant="body2" color="text.secondary">
                                                        pricePoints доступны: {priceHistory?.pricePoints ? 'Да' : 'Нет'} 
                                                        (размер: {priceHistory?.pricePoints?.length || 0})
                                                    </Typography>
                                                </Box>
                                            </div>
                                        )}
                                    </Paper>
                                </Grid>
                            </Grid>
                        </>
                    ) : (
                        <Typography variant="h6" color="text.secondary" sx={{ textAlign: 'center', py: 5 }}>
                            Книга не найдена
                        </Typography>
                    )}
                </>
            )}
            
            {/* Lightbox для просмотра изображений */}
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
