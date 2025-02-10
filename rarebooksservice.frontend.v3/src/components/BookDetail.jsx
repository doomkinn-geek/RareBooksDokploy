// src/components/BookDetail.jsx
import React, { useEffect, useState } from 'react';
import { useParams, useLocation, useNavigate, Link } from 'react-router-dom';
import { getBookById, getBookImages, getBookImageFile } from '../api';
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

    useEffect(() => {
        initLightboxJS("YOUR_LICENSE_KEY", "individual");

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
                // 1) Получаем список имён/ссылок на изображения
                const response = await getBookImages(id);
                const images = response.data.images; // массив строк
                if (!images || images.length === 0) {
                    setImageUrls([]);
                    return;
                }

                // Проверяем, являются ли ссылки внешними (http/https)
                if (images[0].startsWith("http://") || images[0].startsWith("https://")) {
                    // Малоценный лот (сервер вернул "живые" ссылки).
                    // Браузер сам будет грузить их параллельно, и отображать постепенно,
                    // но мы сразу добавим их в стейт (по одной), чтобы React сразу создал <img>.
                    setImageUrls([]); // очищаем перед началом
                    for (let i = 0; i < images.length; i++) {
                        // Можно сделать небольшую задержку await, если хотим строго «по одной».
                        // Но в большинстве случаев достаточно просто
                        setImageUrls(prev => [...prev, images[i]]);
                        // Браузер начнет их грузить, отображение произойдет по мере загрузки <img src=...>.
                    }
                } else {
                    // "Обычный" режим: имена файлов -> нужно вызвать /books/{id}/images/{imageName}
                    setImageUrls([]); // сначала очищаем
                    for (let i = 0; i < images.length; i++) {
                        const imageName = images[i];
                        try {
                            // 2) Запрашиваем конкретный файл (blob)
                            const imageResponse = await getBookImageFile(id, imageName);
                            // 3) Превращаем blob в "blob URL", который можно поставить в <img src=...>
                            const blobUrl = URL.createObjectURL(imageResponse.data);

                            // 4) Добавляем в стейт. Т.к. мы делаем это в цикле, React
                            //    будет обновлять компонент и добавлять <img> по мере готовности каждого файла.
                            setImageUrls(prevArray => [...prevArray, blobUrl]);
                        } catch (err) {
                            console.error("Ошибка при загрузке изображения:", imageName, err);
                            // Можно просто пропускать ошибочные изображения,
                            // либо выводить уведомление, в зависимости от вашей логики.
                        }
                    }
                }
            } catch (err) {
                console.error("Ошибка при получении изображений:", err);
                setError("Failed to load book images.");
                setErrorDetails(err.response?.data?.message || err.message || "Unknown error");
            }
        };

        // Запрашиваем данные о книге и список/загрузку изображений
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
                <Button variant="contained" onClick={() => navigate(-1)}>Назад</Button>
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
                                        alt="Book"
                                        style={{
                                            width: '100%',
                                            maxWidth: '700px',
                                            height: 'auto',
                                            objectFit: 'contain'
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
