// src/components/BookDetail.jsx
import React, { useEffect, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import {
    getBookById,
    getBookImages,
    getBookImageFile
} from '../api';
import { Card, CardContent, Typography, Box, Button } from '@mui/material';
import { SlideshowLightbox, initLightboxJS } from 'lightbox.js-react';
import 'lightbox.js-react/dist/index.css';
import DOMPurify from 'dompurify';

const BookDetail = () => {
    const { id } = useParams();
    const navigate = useNavigate();

    const [book, setBook] = useState(null);
    const [imageUrls, setImageUrls] = useState([]);
    const [error, setError] = useState(null);
    const [errorDetails, setErrorDetails] = useState(null);

    // 1) Вызовем initLightboxJS один раз при монтировании (чтобы включить плагины)
    useEffect(() => {
        initLightboxJS("YOUR_LICENSE_KEY", "individual");
    }, []);

    // 2) Когда imageUrls изменяется, повторно инициализируем лайтбокс
    //    (иначе он «не увидит» новые <img>)
    useEffect(() => {
        if (imageUrls.length > 0) {
            initLightboxJS("YOUR_LICENSE_KEY", "individual");
        }
    }, [imageUrls]);

    useEffect(() => {
        const fetchBookDetails = async () => {
            try {
                const response = await getBookById(id);
                setBook(response.data);
            } catch (err) {
                console.error('Ошибка при получении данных книги:', err);
                setError('Failed to load book details.');
                setErrorDetails(
                    err.response?.data?.errorDetails || err.message || 'Неизвестная ошибка'
                );
            }
        };

        const fetchBookImages = async () => {
            try {
                const response = await getBookImages(id);
                const { images = [], thumbnails = [] } = response.data;

                if (!images || images.length === 0) {
                    setImageUrls([]);
                    return;
                }

                // Проверяем, являются ли это внешние ссылки
                const firstItem = images[0];
                const isExternalLink = firstItem.startsWith('http://') || firstItem.startsWith('https://');

                // Здесь мы собираем finalArray (а не вызываем setImageUrls в цикле)
                const finalArray = [];

                if (isExternalLink) {
                    // Малоценная книга: все URL — внешние ссылки
                    for (const url of images) {
                        finalArray.push(url);
                    }
                } else {
                    // Обычная книга: имена файлов => скачиваем BLOB
                    for (const fileName of images) {
                        try {
                            const resp = await getBookImageFile(id, fileName);
                            const blobUrl = URL.createObjectURL(resp.data);
                            finalArray.push(blobUrl);
                        } catch (err) {
                            console.error('Ошибка при загрузке', fileName, err);
                        }
                    }
                }

                // После того как мы собрали все ссылки/blob, одним махом добавляем в state
                setImageUrls(finalArray);

            } catch (err) {
                console.error("Ошибка при получении изображений:", err);
                setError("Failed to load book images.");
                setErrorDetails(err.response?.data?.message || err.message || "Unknown error");
            }
        };

        fetchBookDetails();
        fetchBookImages();
    }, [id]);

    if (error) {
        return (
            <div className="container">
                <Typography color="error">{error}</Typography>
                {errorDetails && (
                    <Typography color="textSecondary">{errorDetails}</Typography>
                )}
                <Button variant="contained" onClick={() => navigate(-1)}>
                    Назад
                </Button>
            </div>
        );
    }

    if (!book) {
        return <div>Загрузка...</div>;
    }

    return (
        <div className="container">
            <Card sx={{ marginTop: 2 }}>
                <CardContent>
                    <Typography variant="h5" sx={{ fontWeight: 'bold' }}>
                        {book.title}
                    </Typography>
                    <Typography variant="body1" sx={{ marginTop: 1 }}>
                        <span
                            dangerouslySetInnerHTML={{
                                __html: DOMPurify.sanitize(book.description)
                            }}
                        />
                    </Typography>
                    <Typography variant="subtitle1" sx={{ marginTop: 1 }}>
                        Цена: {book.price}
                    </Typography>
                    <Typography variant="subtitle1">
                        Продавец:{" "}
                        <Link
                            to={`/searchBySeller/${book.sellerName}`}
                            style={{ textDecoration: 'none' }}
                        >
                            {book.sellerName}
                        </Link>
                    </Typography>
                    <Typography variant="subtitle1">Тип: {book.type}</Typography>
                    <Typography variant="subtitle1">Дата: {book.endDate}</Typography>

                    <Box sx={{ my: 2 }}>
                        <Typography variant="h6">Изображения</Typography>
                        {imageUrls.length > 0 ? (
                            <SlideshowLightbox
                                theme="day"
                                showThumbnails={true}
                                className="images"
                                roundedImages={true}
                            >
                                {imageUrls.map((url, index) => (
                                    <img
                                        key={index}
                                        src={url}
                                        alt={`Book Image ${index}`}
                                        style={{
                                            width: '100%',
                                            maxWidth: '700px',
                                            height: 'auto',
                                            objectFit: 'contain',
                                        }}
                                    />
                                ))}
                            </SlideshowLightbox>
                        ) : (
                            <Typography>Изображения отсутствуют.</Typography>
                        )}
                    </Box>

                    <Button variant="contained" onClick={() => navigate(-1)}>
                        Назад
                    </Button>
                </CardContent>
            </Card>

            <footer className="footer" style={{ marginTop: '20px' }}>
                <p>&copy; 2025 Rare Books Service. All rights reserved.</p>
            </footer>
        </div>
    );
};

export default BookDetail;
