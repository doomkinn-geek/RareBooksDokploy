// src/components/SearchBooksByPriceRange.jsx
import React, { useState, useEffect } from 'react';
import { useParams, Link, useLocation, useNavigate } from 'react-router-dom';
import { searchBooksByPriceRange } from '../api';
import BookList from './BookList.jsx';
import { Typography, Box } from '@mui/material';
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

    // Добавляем состояние, чтобы хранить остаток доступных запросов
    const [remainingRequests, setRemainingRequests] = useState(null);

    useEffect(() => {
        // Функция загрузки книг
        const fetchBooks = async (page = 1) => {
            setLoading(true);
            setErrorMessage('');
            try {
                // Вызываем API — возвращает { items, totalPages, remainingRequests }
                const response = await searchBooksByPriceRange(minPrice, maxPrice, page);

                setBooks(response.data.items);
                setTotalPages(response.data.totalPages);

                // Если бэкенд прислал remainingRequests, сохраняем его
                if (typeof response.data.remainingRequests !== 'undefined') {
                    setRemainingRequests(response.data.remainingRequests);
                }

                if (response.data.items.length === 0) {
                    setErrorMessage('Ничего не найдено.');
                }
            } catch (error) {
                console.error('Ошибка поиска книг по диапазону цен:', error);
                setErrorMessage('Произошла ошибка при поиске книг. Пожалуйста, попробуйте позже.');
            } finally {
                setLoading(false);
            }
        };

        // Загружаем книги на тек. странице
        fetchBooks(currentPage);
    }, [minPrice, maxPrice, currentPage]);

    // При изменении currentPage обновляем query-параметр "page"
    useEffect(() => {
        const newQuery = new URLSearchParams();
        newQuery.set('page', currentPage);
        navigate(`?${newQuery.toString()}`, { replace: true });
    }, [currentPage, navigate]);

    return (
        <div className="container">
            <header className="header">
                <h1>
                    <Link to="/" style={{ color: '#fff', textDecoration: 'none' }}>
                        Rare Books Service
                    </Link>
                </h1>
            </header>

            <Box>
                <Typography variant="h4">
                    Книги в диапазоне цен: {minPrice} - {maxPrice}
                </Typography>

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

                {/* Список книг, если есть */}
                {!loading && books.length > 0 && (
                    <BookList
                        books={books}
                        totalPages={totalPages}
                        currentPage={currentPage}
                        setCurrentPage={setCurrentPage}
                    />
                )}
            </Box>

            <footer className="footer">
                <p>&copy; 2024 Rare Books Service. All rights reserved.</p>
            </footer>
        </div>
    );
};

export default SearchBooksByPriceRange;
