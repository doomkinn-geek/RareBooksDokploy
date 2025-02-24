// src/components/SearchBooksByPriceRange.jsx
import React, { useState, useEffect } from 'react';
import { useParams, Link, useLocation, useNavigate } from 'react-router-dom';
import { searchBooksByPriceRange } from '../api';
import BookList from './BookList.jsx';
import { Typography, Box, Button } from '@mui/material';
import ErrorMessage from './ErrorMessage';

const SearchBooksByPriceRange = () => {
    const { minPrice, maxPrice } = useParams();
    const location = useLocation();
    const navigate = useNavigate();

    // Извлекаем page из query-параметров URL
    const query = new URLSearchParams(location.search);
    const initialPage = parseInt(query.get('page'), 10) || 1;

    // Состояния
    const [books, setBooks] = useState([]);
    const [currentPage, setCurrentPage] = useState(initialPage);
    const [totalPages, setTotalPages] = useState(1);

    const [errorMessage, setErrorMessage] = useState('');
    const [loading, setLoading] = useState(false);

    const [remainingRequests, setRemainingRequests] = useState(null);

    // -- НОВОЕ --
    // Если backend вернёт partialResults=true, мы сюда запишем данные
    const [partialResults, setPartialResults] = useState(false);
    const [totalFoundPartial, setTotalFoundPartial] = useState(0);
    const [firstTwoTitles, setFirstTwoTitles] = useState([]);

    // Функция загрузки книг
    const fetchBooks = async (page = 1) => {
        setLoading(true);
        setErrorMessage('');
        setPartialResults(false); // сбрасываем каждый раз

        try {
            // Вызываем API — оно может вернуть partialResults==true
            const response = await searchBooksByPriceRange(minPrice, maxPrice, page);

            // Проверяем, что вернул сервер
            const data = response.data;
            if (!data) {
                setErrorMessage('Сервер вернул пустые данные');
                return;
            }

            // Если это частичные результаты (нет подписки)
            if (data.partialResults) {
                setPartialResults(true);
                setTotalFoundPartial(data.totalFound || 0);
                setFirstTwoTitles(data.firstBookTitles || []);

                // Показываем, сколько осталось
                if (typeof data.remainingRequests !== 'undefined') {
                    setRemainingRequests(data.remainingRequests);
                }
            } else {
                // Полноценный ответ (Items)
                setBooks(data.items || []);
                setTotalPages(data.totalPages || 1);

                if (typeof data.remainingRequests !== 'undefined') {
                    setRemainingRequests(data.remainingRequests);
                }

                if (!data.items || data.items.length === 0) {
                    setErrorMessage('Ничего не найдено.');
                }
            }
        } catch (error) {
            console.error('Ошибка поиска книг по диапазону цен:', error);
            setErrorMessage('Произошла ошибка при поиске книг. Пожалуйста, попробуйте позже.');
        } finally {
            setLoading(false);
        }
    };

    // Загружаем книги на тек. странице
    useEffect(() => {
        fetchBooks(currentPage);
    }, [minPrice, maxPrice, currentPage]);

    // При изменении currentPage - синхронизируем с URL
    useEffect(() => {
        const newQuery = new URLSearchParams();
        newQuery.set('page', currentPage);
        navigate(`?${newQuery.toString()}`, { replace: true });
    }, [currentPage, navigate]);

    return (
        <div className="container">
            <Box sx={{ mb: 2 }}>
                <Typography variant="h4" sx={{ fontWeight: 'bold', marginTop: '10px' }}>
                    Книги в диапазоне цен: {minPrice} - {maxPrice}
                </Typography>
            </Box>

            <ErrorMessage message={errorMessage} />

            {loading && (
                <Typography variant="h5">
                    Загрузка...
                </Typography>
            )}

            {/* Если сервер вернул remainingRequests, отображаем пользователю */}
            {!loading && (remainingRequests !== null) && (
                <Typography variant="body1" sx={{ color: '#666', marginBottom: '8px' }}>
                    Осталось запросов в этом месяце:{' '}
                    {remainingRequests === null ? 'безлимит' : remainingRequests}
                </Typography>
            )}

            {/* НОВОЕ: если partialResults=true, показываем урезанный результат */}
            {!loading && partialResults && (
                <Box
                    sx={{
                        p: 2,
                        border: '1px solid #ccc',
                        borderRadius: '5px',
                        backgroundColor: '#faf5e6',
                        marginTop: 2
                    }}
                >
                    <Typography variant="h6" sx={{ mb: 2 }}>
                        У вас нет подписки для детального поиска по ценам
                    </Typography>
                    <Typography variant="body1" sx={{ mb: 2 }}>
                        Всего найдено книг: {totalFoundPartial}
                    </Typography>

                    {firstTwoTitles.length > 0 && (
                        <>
                            <Typography variant="body2" sx={{ mb: 1 }}>
                                Некоторые названия (2 из них):
                            </Typography>
                            <ul>
                                {firstTwoTitles.map((title, idx) => (
                                    <li key={idx}>{title}</li>
                                ))}
                            </ul>
                        </>
                    )}

                    <Typography variant="body1" sx={{ mt: 2, mb: 2 }}>
                        Чтобы увидеть полный список и подробную информацию по этим книгам,
                        пожалуйста, <strong>оформите подписку</strong>.
                    </Typography>

                    <Button
                        variant="contained"
                        color="secondary"
                        onClick={() => navigate('/subscription')}
                    >
                        Оформить подписку
                    </Button>
                </Box>
            )}

            {/* Если partialResults=false, рендерим обычный список */}
            {!loading && !partialResults && books.length > 0 && (
                <BookList
                    books={books}
                    totalPages={totalPages}
                    currentPage={currentPage}
                    setCurrentPage={setCurrentPage}
                />
            )}
        </div>
    );
};

export default SearchBooksByPriceRange;
