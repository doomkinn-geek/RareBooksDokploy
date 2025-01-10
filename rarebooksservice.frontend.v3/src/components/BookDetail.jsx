//src/components/BookDetail.jsx
import React, { useEffect, useState } from 'react';
import { useParams, useLocation, useNavigate, Link } from 'react-router-dom';
import { getBookById, getBookImages, getBookImageFile } from '../api';
import { Card, CardContent, Typography, Box, Button } from '@mui/material';
import { SlideshowLightbox, initLightboxJS } from 'lightbox.js-react';
import 'lightbox.js-react/dist/index.css';
import DOMPurify from 'dompurify';

const BookDetail = () => {
    const { id } = useParams();
    const location = useLocation(); // Получаем информацию о предыдущем состоянии
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
            } catch (error) {
                console.error('Ошибка при получении данных книги:', error);
                setError('Failed to load book details.');
                setErrorDetails(error.response?.data?.errorDetails || error.message || 'Неизвестная ошибка');
            }
        };

        const fetchBookImages = async () => {
            try {
                const response = await getBookImages(id);
                const images = response.data.images;

                const imageUrls = await Promise.all(images.map(async (image) => {
                    const imageResponse = await getBookImageFile(id, image);
                    return URL.createObjectURL(imageResponse.data);
                }));

                setImageUrls(imageUrls);
            } catch (error) {
                console.error('Ошибка при получении изображений книги:', error);
                setError('Failed to load book images.');
                setErrorDetails(error.response?.data?.message || error.message || 'Unknown error');
            }
        };

        fetchBookDetails();
        fetchBookImages();
    }, [id]);

    if (error) {
        return (
            <div className="container">
                <Typography color="error">{error}</Typography>
                {errorDetails && <Typography color="textSecondary">{errorDetails}</Typography>}
                <Button variant="contained" onClick={() => navigate(-1)}>Назад</Button>
            </div>
        );
    }

    if (!book) {
        return <div>Загрузка...</div>;
    }

    return (
        <div className="container">
            <header className="header">
                <h1><Link to="/" style={{ color: '#fff', textDecoration: 'none' }}>Rare Books Service</Link></h1>
            </header>
            <Card>
                <CardContent>
                    <Typography variant="h4">{book.title}</Typography>
                    <Typography variant="body1">
                        <span dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(book.description) }} />
                    </Typography>
                    <Typography variant="h6">Цена: {book.price}</Typography>
                    <Typography variant="h6">
                        <Link to={`/searchBySeller/${book.sellerName}`} style={{ textDecoration: 'none', color: 'inherit' }}>
                            Продавец: {book.sellerName}
                        </Link>
                    </Typography>
                    <Typography variant="h6">Тип: {book.type}</Typography>
                    <Typography variant="h6">Дата: {book.endDate}</Typography>
                    <Box sx={{ my: 2 }}>
                        <Typography variant="h5">Изображения</Typography>
                        {imageUrls.length > 0 ? (
                            <SlideshowLightbox theme="day" showThumbnails={true} className="images" roundedImages={true}>
                                {imageUrls.map((url, index) => (
                                    <img key={index} src={url} alt="Book" style={{ width: '100%', maxWidth: '700px', maxHeight: '700px', height: 'auto', objectFit: 'contain' }} />
                                ))}
                            </SlideshowLightbox>
                        ) : (
                            <Typography>Изображения отсутствуют.</Typography>
                        )}
                    </Box>
                    <Button variant="contained" onClick={() => navigate(-1)}>Назад</Button>
                </CardContent>
            </Card>
            <footer className="footer">
                <p>&copy; 2024 Rare Books Service. All rights reserved.</p>
            </footer>
        </div>
    );
};

export default BookDetail;