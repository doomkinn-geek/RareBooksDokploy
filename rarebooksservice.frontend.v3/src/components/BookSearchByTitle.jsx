// src/components/BookSearchByTitle.jsx

import React, { useState, useEffect } from 'react';
import { useParams, Link, useLocation, useNavigate } from 'react-router-dom';
import { searchBooksByTitle } from '../api';
import BookList from './BookList';
import { Typography, Box } from '@mui/material';
import ErrorMessage from './ErrorMessage';

const BookSearchByTitle = () => {
    const { title } = useParams();
    const location = useLocation();
    const navigate = useNavigate();

    const query = new URLSearchParams(location.search);
    const exactPhrase = query.get('exactPhrase') === 'true';
    const initialPage = parseInt(query.get('page'), 10) || 1;

    const [books, setBooks] = useState([]);
    const [currentPage, setCurrentPage] = useState(initialPage);
    const [totalPages, setTotalPages] = useState(1);

    const [errorMessage, setErrorMessage] = useState('');
    const [loading, setLoading] = useState(false);

    // Новое: храним, сколько осталось запросов
    const [remainingRequests, setRemainingRequests] = useState(null);

    useEffect(() => {
        const fetchBooks = async (page = 1) => {
            setLoading(true);
            setErrorMessage('');
            try {
                const response = await searchBooksByTitle(title, exactPhrase, page);

                const { data } = response;
                if (!data || !Array.isArray(data.items)) {
                    setBooks([]);
                    setErrorMessage('Сервер вернул неожиданные данные.');
                } else {
                    setBooks(data.items);
                    setTotalPages(data.totalPages);

                    // Добавьте эту строчку:
                    setRemainingRequests(data.remainingRequests);

                    if (data.items.length === 0) {
                        setErrorMessage('Ничего не найдено.');
                    }
                }
            } catch (error) {
                console.error('Ошибка поиска книг:', error);
                setBooks([]);
                setErrorMessage('Произошла ошибка при поиске книг. Попробуйте позже.');
            } finally {
                // Ставим loading=false в любом случае (успех или ошибка)
                setLoading(false);
            }
        };

        fetchBooks(currentPage);
    }, [title, exactPhrase, currentPage]);


    useEffect(() => {
        const newQuery = new URLSearchParams();
        newQuery.set('exactPhrase', exactPhrase);
        newQuery.set('page', currentPage);
        navigate(`?${newQuery.toString()}`, { replace: true });
    }, [exactPhrase, currentPage, navigate]);

    return (
        <div className="container">
            <Box sx={{ mb: 2 }}>
                <Typography variant="h5" sx={{ fontWeight: 'bold', marginTop: '10px' }}>
                    Книги по названию: {title}
                </Typography>
            </Box>

            <ErrorMessage message={errorMessage} />
            {loading && <Typography variant="h6">Загрузка...</Typography>}

            {/* Отображаем, сколько осталось запросов, если сервер прислал remainingRequests */}
            {!loading && (remainingRequests !== null) && (
                <Typography variant="body1" sx={{ color: '#666', marginBottom: '8px' }}>
                    Осталось запросов в этом месяце: {remainingRequests === null ? 'безлимит' : remainingRequests}
                </Typography>
            )}

            {!loading && books.length > 0 && (
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

export default BookSearchByTitle;
