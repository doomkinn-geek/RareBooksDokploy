import React, { useState, useEffect } from 'react';
import { useParams, Link, useLocation, useNavigate } from 'react-router-dom';
import { searchBooksByDescription } from '../api';
import BookList from './BookList.jsx';
import { Typography, Box } from '@mui/material';
import ErrorMessage from './ErrorMessage';

const BookSearchByDescription = () => {
    const { description } = useParams();
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

    // Новое:
    const [remainingRequests, setRemainingRequests] = useState(null);

    useEffect(() => {
        const fetchBooks = async (page = 1) => {
            setLoading(true);
            setErrorMessage('');
            try {
                const response = await searchBooksByDescription(description, exactPhrase, page);
                // response.data => { items, totalPages, remainingRequests }

                setBooks(response.data.items);
                setTotalPages(response.data.totalPages);

                if (typeof response.data.remainingRequests !== 'undefined') {
                    setRemainingRequests(response.data.remainingRequests);
                }

                if (response.data.items.length === 0) {
                    setErrorMessage('Ничего не найдено.');
                }
            } catch (error) {
                console.error('Ошибка поиска книг по описанию:', error);
                setErrorMessage('Произошла ошибка при поиске книг. Пожалуйста, попробуйте позже.');
            } finally {
                setLoading(false);
            }
        };

        fetchBooks(currentPage);
    }, [description, exactPhrase, currentPage]);

    useEffect(() => {
        const newQuery = new URLSearchParams();
        newQuery.set('exactPhrase', exactPhrase);
        newQuery.set('page', currentPage);
        navigate(`?${newQuery.toString()}`, { replace: true });
    }, [exactPhrase, currentPage, navigate]);

    return (
        <div className="container">
            <Typography variant="h4">
                Книги с описанием: {description}
            </Typography>

            <ErrorMessage message={errorMessage} />

            {loading && <Typography variant="h6">Загрузка...</Typography>}

            {/* Выводим остаток запросов */}
            {!loading && (remainingRequests !== null) && (
                <Typography variant="body1" sx={{ color: '#666', marginBottom: '8px' }}>
                    Осталось запросов: {remainingRequests === null ? 'безлимит' : remainingRequests}
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

export default BookSearchByDescription;
