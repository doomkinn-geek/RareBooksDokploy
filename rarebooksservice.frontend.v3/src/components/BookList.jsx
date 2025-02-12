// src/components/BookList.jsx
import React, { useEffect, useState } from 'react';
import { Card, CardContent, Typography, Box, Button, Pagination } from '@mui/material';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { API_URL, getAuthHeaders } from '../api';

// Функция-заглушка для получения одного файла (миниатюры)
// из бэкенда: GET /books/{id}/images/{imageName}
function getBookImageFile(id, imageName) {
    return axios.get(`${API_URL}/books/${id}/images/${imageName}`, {
        headers: getAuthHeaders(),
        responseType: 'blob',
    });
}

const BookList = ({ books, totalPages, currentPage, setCurrentPage }) => {
    const navigate = useNavigate();

    // Объект, где ключ = book.id, значение = blob-URL
    const [thumbnails, setThumbnails] = useState({});
    const [error, setError] = useState('');

    useEffect(() => {
        // Если books пуст — очищаем старые данные и выходим
        if (!books || books.length === 0) {
            setThumbnails({});
            setError('');
            return;
        }

        // Сбрасываем
        setThumbnails({});
        setError('');

        // Флаг, который прерывает обновление, если компонент размонтирован
        let cancelled = false;

        // Асинхронная функция, которая загрузит все миниатюры "пакетом"
        const fetchThumbnails = async () => {
            try {
                // Массив промисов (каждый запросит миниатюру)
                const requests = books.map((book) => {
                    if (!book.firstImageName) {
                        // У книги нет миниатюры
                        return null;
                    }
                    // Возвращаем промис:
                    return getBookImageFile(book.id, book.firstImageName)
                        .then((resp) => {
                            const blobUrl = URL.createObjectURL(resp.data);
                            return { bookId: book.id, blobUrl };
                        })
                        .catch((err) => {
                            console.error('Ошибка при загрузке миниатюры', book.id, err);
                            return null; // Не прерываем весь Promise.all, просто вернём null
                        });
                }).filter(Boolean); // Уберём null'ы (где firstImageName отсутствует)

                // Ждём, пока все запросы завершатся
                const results = await Promise.all(requests);
                if (cancelled) return;

                // Собираем объект вида { bookId: blobUrl }
                const newThumbs = {};
                for (const r of results) {
                    if (r) {
                        newThumbs[r.bookId] = r.blobUrl;
                    }
                }

                // Выставляем все миниатюры одним махом
                setThumbnails(newThumbs);
            } catch (err) {
                console.error('Ошибка при параллельной загрузке миниатюр:', err);
                if (!cancelled) {
                    setError('Возникли проблемы с загрузкой миниатюр (возможно, нет подписки).');
                }
            }
        };

        // Запускаем загрузку
        fetchThumbnails();

        // Если компонент размонируется — выставим cancelled=true
        return () => {
            cancelled = true;
        };
    }, [books]);

    // Обработка смены страницы
    const handlePageChange = (event, value) => {
        setCurrentPage(value);
    };

    // Переход на детальную страницу книги
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
                            {/* показываем миниатюру, если она загрузилась */}
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
                                <Typography variant="body1">Цена: {book.price}</Typography>
                                <Typography variant="body1">Дата: {book.date}</Typography>
                                <Typography variant="body1">Продавец: {book.sellerName}</Typography>
                                <Typography variant="body1">Тип: {book.type}</Typography>
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
                        onClick={() => setCurrentPage(currentPage - 1)}
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
                        onClick={() => setCurrentPage(currentPage + 1)}
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
