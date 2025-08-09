// src/components/BookDetail.jsx
import React, { useEffect, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import {
    getBookById,
    getBookImages,
    getBookImageFile,
    getPriceHistory,
    checkIfBookIsFavorite,
    addBookToFavorites,
    removeBookFromFavorites,
    API_URL,
    getAuthHeaders
} from '../api';
import { Card, CardContent, Typography, Box, Button, Container, Paper, Grid, Divider, Chip, CircularProgress, Alert, IconButton, Tooltip } from '@mui/material';
import Lightbox from 'yet-another-react-lightbox';
import 'yet-another-react-lightbox/styles.css';
import Zoom from 'yet-another-react-lightbox/plugins/zoom';
import DOMPurify from 'dompurify';
import Cookies from 'js-cookie';
import { Helmet } from 'react-helmet';
import FavoriteIcon from '@mui/icons-material/Favorite';
import FavoriteBorderIcon from '@mui/icons-material/FavoriteBorder';
import InfoIcon from '@mui/icons-material/Info';

const BookDetail = () => {
    const { id } = useParams();
    const navigate = useNavigate();

    const [book, setBook] = useState(null);
    const [bookImages, setBookImages] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [open, setOpen] = useState(false);
    const [selectedImageIndex, setSelectedImageIndex] = useState(0);
    const [isFavorite, setIsFavorite] = useState(false);
    const [favoritesLoading, setFavoritesLoading] = useState(false);
    const [showSubscriptionCTA, setShowSubscriptionCTA] = useState(false);

    // Отслеживание загрузки деталей книги
    const [loadingBook, setLoadingBook] = useState(true);
    // Отслеживание загрузки изображений
    const [loadingImages, setLoadingImages] = useState(true);

    // Эффект для прокрутки страницы в начало после загрузки данных
    useEffect(() => {
        // Прокручиваем страницу в начало при монтировании компонента
        window.scrollTo(0, 0);
    }, []);
    
    // Дополнительный эффект для прокрутки страницы в начало после загрузки данных
    useEffect(() => {
        // Если данные загружены (книга или ошибка), прокручиваем страницу в начало
        if (!loadingBook) {
            window.scrollTo({
                top: 0,
                behavior: 'smooth' // добавляем плавную прокрутку
            });
        }
    }, [loadingBook]);

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
        
        // Функция очистки для освобождения URL объектов при размонтировании
        return () => {
            bookImages.forEach(img => {
                if (img.imageUrl && typeof img.imageUrl === 'string' && img.imageUrl.startsWith('blob:')) {
                    URL.revokeObjectURL(img.imageUrl);
                }
                if (img.thumbnailUrl && typeof img.thumbnailUrl === 'string' && img.thumbnailUrl.startsWith('blob:')) {
                    URL.revokeObjectURL(img.thumbnailUrl);
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

    // Определяем, нужно ли показывать CTA подписки
    useEffect(() => {
        if (!book) {
            setShowSubscriptionCTA(false);
            return;
        }
        const paidOnly = (
            book.finalPrice === 'Только для подписчиков' ||
            book.price === 'Только для подписчиков' ||
            book.endDate === 'Только для подписчиков' ||
            book.date === 'Только для подписчиков'
        );
        setShowSubscriptionCTA(Boolean(paidOnly));
    }, [book]);

    // Эффект для проверки, находится ли книга в избранном
    useEffect(() => {
        const checkFavoriteStatus = async () => {
            try {
                // Проверяем, авторизован ли пользователь
                const token = Cookies.get('token');
                if (!token) return;

                setFavoritesLoading(true);
                const response = await checkIfBookIsFavorite(id);
                setIsFavorite(response.data);
            } catch (error) {
                console.error('Ошибка при проверке статуса избранного:', error);
            } finally {
                setFavoritesLoading(false);
            }
        };

        if (id) {
            checkFavoriteStatus();
        }
    }, [id]);

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

    // Обработчик добавления/удаления книги из избранного
    const handleToggleFavorite = async () => {
        try {
            setFavoritesLoading(true);
            
            // Проверяем, авторизован ли пользователь
            const token = Cookies.get('token');
            if (!token) {
                // Если не авторизован, перенаправляем на страницу входа
                navigate('/login', { state: { from: `/books/${id}` } });
                return;
            }

            if (isFavorite) {
                // Удаляем из избранного
                await removeBookFromFavorites(id);
                setIsFavorite(false);
            } else {
                // Добавляем в избранное
                await addBookToFavorites(id);
                setIsFavorite(true);
            }
        } catch (error) {
            console.error('Ошибка при изменении статуса избранного:', error);
        } finally {
            setFavoritesLoading(false);
        }
    };

    const handleSubscribeClick = () => {
        try {
            if (id) {
                localStorage.setItem('returnTo', `/books/${id}`);
            }
        } catch (_e) {}
        navigate('/subscription');
    };

    // Рендеринг содержимого компонента
    return (
        <Container maxWidth="lg" sx={{ py: 5 }}>
            {/* Helmet для добавления метаданных страницы и структурированных данных */}
            {book && (
                <Helmet>
                    <title>{book.title || 'Антикварная книга'} | Rare Books Service</title>
                    <meta name="description" content={`${book.title || 'Антикварная книга'} - ${book.author || 'Неизвестный автор'}. Год издания: ${book.year || 'Не указан'}. Детальная информация и оценка стоимости.`} />
                    <meta name="keywords" content={`${book.title}, ${book.author}, антикварная книга, редкое издание, оценка стоимости, ${book.year}, ${book.type}`} />
                    
                    {/* Schema.org микроразметка для Product */}
                    <script type="application/ld+json">
                        {JSON.stringify({
                            "@context": "https://schema.org",
                            "@type": "Product",
                            "name": book.title || 'Антикварная книга',
                            "description": book.description ? DOMPurify.sanitize(book.description, { ALLOWED_TAGS: [] }) : 'Антикварная книга',
                            "image": bookImages.length > 0 ? bookImages[0].imageUrl : '',
                            "offers": {
                                "@type": "Offer",
                                "priceCurrency": "RUB",
                                "price": book.finalPrice || book.price || 0,
                                "availability": "https://schema.org/InStock",
                                "seller": {
                                    "@type": "Organization",
                                    "name": book.sellerName || "Антикварный салон"
                                }
                            },
                            "brand": {
                                "@type": "Brand",
                                "name": book.author || "Неизвестный автор"
                            },
                            "category": book.type || "Антикварная книга",
                            "productionDate": book.year || ""
                        })}
                    </script>
                    
                    {/* Schema.org микроразметка для Book */}
                    <script type="application/ld+json">
                        {JSON.stringify({
                            "@context": "https://schema.org",
                            "@type": "Book",
                            "name": book.title || 'Антикварная книга',
                            "author": {
                                "@type": "Person",
                                "name": book.author || "Неизвестный автор"
                            },
                            "datePublished": book.year || "",
                            "publisher": book.publisher || "Неизвестное издательство",
                            "inLanguage": book.language || "ru",
                            "image": bookImages.length > 0 ? bookImages[0].imageUrl : '',
                            "description": book.description ? DOMPurify.sanitize(book.description, { ALLOWED_TAGS: [] }) : 'Антикварная книга'
                        })}
                    </script>
                </Helmet>
            )}
            
            {/* Остальной код компонента */}
            {showSubscriptionCTA && (
                <Paper 
                    elevation={3} 
                    sx={{ 
                        p: 3, 
                        mb: 4, 
                        borderRadius: '12px', 
                        bgcolor: 'rgba(255, 171, 0, 0.1)', 
                        border: '1px solid rgba(255, 171, 0, 0.3)'
                    }}
                >
                    <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                        <InfoIcon sx={{ mr: 1, color: '#f57c00' }} />
                        <Typography variant="h6" sx={{ fontWeight: 'bold', color: '#8d6e63' }}>
                            Данные о ценах, датах и изображения доступны только по подписке
                        </Typography>
                    </Box>
                    <Typography variant="body1" sx={{ mb: 2 }}>
                        Чтобы увидеть полную информацию по этой книге и получить доступ к инструментам оценки стоимости, оформите подписку.
                    </Typography>
                    <Button
                        variant="contained"
                        color="secondary"
                        onClick={handleSubscribeClick}
                        sx={{ borderRadius: '8px', textTransform: 'none', fontWeight: 'bold', px: 3, py: 1 }}
                    >
                        Оформить подписку
                    </Button>
                </Paper>
            )}
            {loading ? (
                <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '60vh' }}>
                    <CircularProgress />
                </Box>
            ) : (
                <>
                    {error && (
                        <Alert severity="error" sx={{ mb: 4 }}>
                            {error}
                        </Alert>
                    )}
                    
                    {book ? (
                        <>
                            <Paper elevation={3} sx={{ p: { xs: 2, md: 4 }, borderRadius: '12px', mb: 4 }}>
                                <Grid container spacing={4}>
                                    {/* Галерея изображений */}
                                    <Grid item xs={12} md={6}>
                                        <Box sx={{ mb: { xs: 2, md: 0 } }}>
                                            {loadingImages ? (
                                                <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '300px' }}>
                                                    <CircularProgress />
                                                </Box>
                                            ) : bookImages.length > 0 ? (
                                                <Box>
                                                    {/* Основное изображение */}
                                                    <Box 
                                                        sx={{ 
                                                            width: '100%', 
                                                            height: '300px',
                                                            display: 'flex',
                                                            justifyContent: 'center',
                                                            alignItems: 'center',
                                                            backgroundColor: '#f5f5f5',
                                                            borderRadius: '8px',
                                                            mb: 2,
                                                            overflow: 'hidden',
                                                            cursor: 'pointer'
                                                        }}
                                                        onClick={() => handleImageClick(0)}
                                                    >
                                                        <img 
                                                            src={bookImages[0].imageUrl} 
                                                            alt={book.title || 'Изображение книги'} 
                                                            style={{ 
                                                                maxWidth: '100%', 
                                                                maxHeight: '100%', 
                                                                objectFit: 'contain'
                                                            }}
                                                        />
                                                    </Box>
                                                    
                                                    {/* Миниатюры */}
                                                    {bookImages.length > 1 && (
                                                        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                                                            {bookImages.map((img, index) => (
                                                                <Box 
                                                                    key={index}
                                                                    sx={{ 
                                                                        width: '60px', 
                                                                        height: '60px',
                                                                        display: 'flex',
                                                                        justifyContent: 'center',
                                                                        alignItems: 'center',
                                                                        backgroundColor: '#f5f5f5',
                                                                        borderRadius: '4px',
                                                                        cursor: 'pointer',
                                                                        border: index === selectedImageIndex ? '2px solid #1976d2' : '2px solid transparent'
                                                                    }}
                                                                    onClick={() => handleImageClick(index)}
                                                                >
                                                                    <img 
                                                                        src={img.thumbnailUrl} 
                                                                        alt={`Миниатюра ${index + 1}`} 
                                                                        style={{ 
                                                                            maxWidth: '100%', 
                                                                            maxHeight: '100%', 
                                                                            objectFit: 'contain'
                                                                        }}
                                                                    />
                                                                </Box>
                                                            ))}
                                                        </Box>
                                                    )}
                                                </Box>
                                            ) : (
                                                <Box 
                                                    sx={{ 
                                                        width: '100%', 
                                                        height: '300px',
                                                        display: 'flex',
                                                        justifyContent: 'center',
                                                        alignItems: 'center',
                                                        backgroundColor: '#f5f5f5',
                                                        borderRadius: '8px'
                                                    }}
                                                >
                                                    <Typography variant="body1" color="text.secondary">
                                                        Изображения отсутствуют
                                                    </Typography>
                                                </Box>
                                            )}
                                        </Box>
                                    </Grid>
                                    
                                    {/* Информация о книге */}
                                    <Grid item xs={12} md={6}>
                                        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                                            <Typography variant="h4" gutterBottom fontWeight="bold">
                                                {book.title || 'Без названия'}
                                            </Typography>
                                            
                                            {/* Кнопка добавления в избранное */}
                                            <Tooltip title={isFavorite ? "Удалить из избранного" : "Добавить в избранное"}>
                                                <IconButton 
                                                    color="primary" 
                                                    onClick={handleToggleFavorite}
                                                    disabled={favoritesLoading}
                                                    sx={{ 
                                                        '&:hover': { 
                                                            backgroundColor: 'rgba(25, 118, 210, 0.04)'
                                                        }
                                                    }}
                                                >
                                                    {favoritesLoading ? (
                                                        <CircularProgress size={24} />
                                                    ) : isFavorite ? (
                                                        <FavoriteIcon sx={{ color: 'red' }} />
                                                    ) : (
                                                        <FavoriteBorderIcon />
                                                    )}
                                                </IconButton>
                                            </Tooltip>
                                        </Box>
                                        
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
                    plugins={[Zoom]}
                    zoom={{
                        maxZoomPixelRatio: 3,
                        zoomInMultiplier: 1.2,
                        doubleTapDelay: 300,
                        doubleClickDelay: 300,
                        keyboardMoveDistance: 50,
                        wheelZoomDistanceFactor: 100,
                    }}
                />
            )}
        </Container>
    );
};

export default BookDetail;
