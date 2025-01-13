// src/components/BookList.jsx
import React, { useEffect, useState, useContext } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
    Card,
    CardContent,
    Typography,
    Box,
    Button,
    Pagination
} from '@mui/material';
import { getBookImages, getBookThumbnail } from '../api';
import { UserContext } from '../context/UserContext';

const BookList = ({ books, totalPages, currentPage, setCurrentPage }) => {
    const [thumbnails, setThumbnails] = useState({});
    const [error, setError] = useState(null);
    const navigate = useNavigate();
    const { user } = useContext(UserContext);

    useEffect(() => {
        const fetchThumbnails = async () => {
            if (!books || books.length === 0) return;

            const newThumbnails = {};
            for (const book of books) {
                try {
                    // Вызываем эндпоинт, который отдаёт ТОЛЬКО thumbnails
                    const response = await getBookThumbnailsInfo(book.id);
                    // Берём первую миниатюру
                    const thumbnailName = response.data.thumbnails?.[0];

                    if (thumbnailName) {
                        const thumbnailResponse = await getBookThumbnail(book.id, thumbnailName);
                        const thumbnailUrl = URL.createObjectURL(thumbnailResponse.data);
                        newThumbnails[book.id] = thumbnailUrl;
                    }
                } catch (err) {
                    console.error(
                        `Error fetching thumbnail for book ${book.id}:`,
                        err.response || err.message
                    );
                    setError('Failed to load thumbnails. Please try again later.');
                }
            }
            setThumbnails(newThumbnails);
        };

        fetchThumbnails();
    }, [books]);

    // Логика пагинации
    const handleNextPage = () => {
        if (currentPage < totalPages) {
            setCurrentPage(currentPage + 1);
        }
    };
    const handlePreviousPage = () => {
        if (currentPage > 1) {
            setCurrentPage(currentPage - 1);
        }
    };
    const handlePageChange = (event, value) => {
        setCurrentPage(value);
    };

    // Переход на страницу деталей книги
    const handleBookClick = (bookId) => {
        navigate(`/books/${bookId}`, { state: { fromPage: currentPage } });
    };

    return (
        <Box sx={{ my: 2 }}>
            {error && <Typography color="error">{error}</Typography>}

            {/* Список книг */}
            <Box className="book-list" sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                {books.map((book) => (
                    <Card
                        key={book.id}
                        className="book-item"
                        sx={{
                            // Небольшие отступы и адаптивная ширина
                            my: 1,
                            borderRadius: '5px'
                        }}
                    >
                        <CardContent
                            sx={{
                                // На смартфоне (xs) делаем колонку, на больших экранах — в строку
                                display: 'flex',
                                flexDirection: { xs: 'column', sm: 'row' },
                                gap: 2
                            }}
                        >
                            {thumbnails[book.id] && (
                                <Box
                                    sx={{
                                        width: { xs: '100%', sm: '150px' },
                                        marginBottom: { xs: 2, sm: 0 }
                                    }}
                                >
                                    <img
                                        src={thumbnails[book.id]}
                                        alt="Book Thumbnail"
                                        style={{
                                            width: '100%',
                                            height: 'auto',
                                            objectFit: 'contain',
                                            display: 'block'
                                        }}
                                    />
                                </Box>
                            )}

                            {/* Данные о книге */}
                            <Box sx={{ flex: 1 }}>
                                <Typography
                                    variant="h6"
                                    onClick={() => handleBookClick(book.id)}
                                    sx={{
                                        cursor: 'pointer',
                                        textDecoration: 'none',
                                        color: 'inherit',
                                        overflowWrap: 'break-word'
                                    }}
                                >
                                    {book.title}
                                </Typography>
                                <Typography variant="body1">
                                    Цена: {book.price}
                                </Typography>
                                <Typography variant="body1">
                                    Дата: {book.date}
                                </Typography>
                                <Typography
                                    variant="body2"
                                    component={Link}
                                    to={`/searchBySeller/${book.sellerName}`}
                                    style={{
                                        textDecoration: 'none',
                                        color: 'inherit'
                                    }}
                                >
                                    Продавец: {book.sellerName}
                                </Typography>
                                <Typography variant="body1">
                                    Тип: {book.type}
                                </Typography>
                            </Box>
                        </CardContent>
                    </Card>
                ))}
            </Box>

            {/* Блок пагинации (если есть книги) */}
            {books.length > 0 && (
                <Box
                    sx={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        mt: 2,
                        flexWrap: 'wrap',
                        gap: 1
                    }}
                >
                    <Button
                        variant="contained"
                        onClick={handlePreviousPage}
                        disabled={currentPage === 1}
                        sx={{ flex: '1 1 auto' }}
                    >
                        Предыдущая страница
                    </Button>
                    <Pagination
                        count={totalPages}
                        page={currentPage}
                        onChange={handlePageChange}
                        color="primary"
                        siblingCount={0}
                        boundaryCount={1}
                        sx={{
                            margin: '0 auto'
                        }}
                    />
                    <Button
                        variant="contained"
                        onClick={handleNextPage}
                        disabled={currentPage === totalPages}
                        sx={{ flex: '1 1 auto' }}
                    >
                        Следующая страница
                    </Button>
                </Box>
            )}
        </Box>
    );
};

export default BookList;
