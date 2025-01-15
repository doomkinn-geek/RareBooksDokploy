// src/components/BookList.jsx
import React, { useEffect, useState } from 'react';
import { Card, CardContent, Typography, Box, Button, Pagination } from '@mui/material';
import { useNavigate } from 'react-router-dom';
import { getBookImageFile } from '../api';

const BookList = ({ books, totalPages, currentPage, setCurrentPage }) => {
    const navigate = useNavigate();

    // храним URL'ы миниатюр по ключу bookId
    const [thumbnails, setThumbnails] = useState({});
    const [error, setError] = useState('');

    // При изменении books загружаем миниатюры
    useEffect(() => {
        // Если нет книг — сбрасываем миниатюры
        if (!books || books.length === 0) {
            setThumbnails({});
            return;
        }

        // Очищаем, чтобы при обновлении списка "старые" миниатюры не мешались
        setThumbnails({});
        setError('');

        // Для каждой книги, если есть firstImageName, запрашиваем миниатюру
        books.forEach((book) => {
            if (book.firstImageName) {
                getBookImageFile(book.id, book.firstImageName)
                    .then((response) => {
                        const blobUrl = URL.createObjectURL(response.data);
                        // Записываем миниатюру для конкретной книги
                        setThumbnails((prev) => ({
                            ...prev,
                            [book.id]: blobUrl,
                        }));
                    })
                    .catch((err) => {
                        console.error(
                            'Ошибка при загрузке миниатюры для книги',
                            book.id,
                            err
                        );
                        setError('Не удалось загрузить некоторые миниатюры.');
                    });
            }
        });
    }, [books]);

    // Переход к предыдущей / следующей странице
    const handlePreviousPage = () => {
        if (currentPage > 1) {
            setCurrentPage(currentPage - 1);
        }
    };
    const handleNextPage = () => {
        if (currentPage < totalPages) {
            setCurrentPage(currentPage + 1);
        }
    };
    const handlePageChange = (event, value) => {
        setCurrentPage(value);
    };

    // Переход на страницу деталей
    const handleBookClick = (bookId) => {
        navigate(`/books/${bookId}`, { state: { fromPage: currentPage } });
    };

    return (
        <Box sx={{ my: 2 }}>
            {error && (
                <Typography color="error" sx={{ mb: 2 }}>
                    {error}
                </Typography>
            )}

            <Box
                className="book-list"
                sx={{
                    display: 'flex',
                    flexDirection: 'column',
                    gap: 2,
                }}
            >
                {books.map((book) => (
                    <Card
                        key={book.id}
                        sx={{
                            my: 1,
                            borderRadius: '5px',
                        }}
                    >
                        <CardContent
                            sx={{
                                display: 'flex',
                                flexDirection: { xs: 'column', sm: 'row' },
                                gap: 2,
                            }}
                        >
                            {book.firstImageName && thumbnails[book.id] && (
                                <Box
                                    sx={{
                                        width: { xs: '100%', sm: '150px' },
                                        marginBottom: { xs: 2, sm: 0 },
                                    }}
                                >
                                    <img
                                        src={thumbnails[book.id]}
                                        alt="Book Thumbnail"
                                        style={{
                                            width: '100%',
                                            height: 'auto',
                                            objectFit: 'contain',
                                            display: 'block',
                                        }}
                                    />
                                </Box>
                            )}

                            <Box sx={{ flex: 1 }}>
                                <Typography
                                    variant="h6"
                                    onClick={() => handleBookClick(book.id)}
                                    sx={{
                                        cursor: 'pointer',
                                        textDecoration: 'none',
                                        color: 'inherit',
                                        overflowWrap: 'break-word',
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
                                <Typography variant="body1">
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

            {books.length > 0 && (
                <Box
                    sx={{
                        display: 'flex',
                        justifyContent: 'center',
                        mt: 2,
                        flexWrap: 'wrap',
                        gap: 2,
                    }}
                >
                    <Button
                        variant="contained"
                        onClick={handlePreviousPage}
                        disabled={currentPage === 1}
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
                    />
                    <Button
                        variant="contained"
                        onClick={handleNextPage}
                        disabled={currentPage === totalPages}
                    >
                        Следующая страница
                    </Button>
                </Box>
            )}
        </Box>
    );
};

export default BookList;
