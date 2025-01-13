// src/components/BookList.jsx
import React from 'react';
import { Card, CardContent, Typography, Box, Button, Pagination } from '@mui/material';
import { useNavigate } from 'react-router-dom';

const BookList = ({ books, totalPages, currentPage, setCurrentPage }) => {
    const navigate = useNavigate();

    // Обработка перехода к предыдущей/следующей странице (если нужны кнопки), 
    // либо можно ограничиться только компонентом <Pagination>.
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

    // При нажатии на книгу переходим на страницу "детали книги"
    const handleBookClick = (bookId) => {
        navigate(`/books/${bookId}`, { state: { fromPage: currentPage } });
    };

    return (
        <Box sx={{ my: 2 }}>
            {/* Отображаем список книг */}
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
                            {/* Если у книги есть firstThumbnailName, показываем миниатюру: */}
                            {book.firstThumbnailName && (
                                <Box
                                    sx={{
                                        width: { xs: '100%', sm: '150px' },
                                        marginBottom: { xs: 2, sm: 0 },
                                    }}
                                >
                                    {/* 
                                         Запрос миниатюры идёт по адресу:
                                         GET /api/books/{book.id}/thumbnails/{book.firstThumbnailName}.
                                         Сервер уже умеет проверять подписку (или локальные файлы).
                                      */}
                                    <img
                                        src={`/api/books/${book.id}/thumbnails/${book.firstThumbnailName}`}
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

                            {/* Основная информация о книге */}
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
                                <Typography variant="body1">Цена: {book.price}</Typography>
                                <Typography variant="body1">Дата: {book.date}</Typography>
                                <Typography variant="body1">Продавец: {book.sellerName}</Typography>
                                <Typography variant="body1">Тип: {book.type}</Typography>
                            </Box>
                        </CardContent>
                    </Card>
                ))}
            </Box>

            {/* Пагинация (если есть хотя бы одна книга) */}
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
