// src/components/SearchByCategory.jsx
import React, { useState, useEffect } from 'react';
import { useParams, Link, useLocation, useNavigate } from 'react-router-dom';
import { searchBooksByCategory } from '../api';
import BookList from './BookList';
import { Typography, Box } from '@mui/material';
import ErrorMessage from './ErrorMessage';

const SearchByCategory = () => {
    const { categoryId } = useParams();
    const location = useLocation();
    const navigate = useNavigate();

    // Извлекаем ?page=... из URL, если он есть, иначе берём 1
    const query = new URLSearchParams(location.search);
    const initialPage = parseInt(query.get('page'), 10) || 1;

    // Состояния для книг, текущей/общей страниц
    const [books, setBooks] = useState([]);
    const [currentPage, setCurrentPage] = useState(initialPage);
    const [totalPages, setTotalPages] = useState(1);
    const [errorMessage, setErrorMessage] = useState('');
    const [loading, setLoading] = useState(false);

    // Загружаем книги по категории при изменении categoryId или currentPage
    useEffect(() => {
        const fetchBooks = async (page = 1) => {
            setLoading(true);
            setErrorMessage('');
            try {
                const response = await searchBooksByCategory(categoryId, page);
                setBooks(response.data.items);
                setTotalPages(response.data.totalPages);
                setCurrentPage(page);

                if (response.data.items.length === 0) {
                    setErrorMessage('Ничего не найдено.');
                }
            } catch (error) {
                console.error('Ошибка поиска книг по категориям:', error);
                setErrorMessage('Произошла ошибка при поиске книг. Пожалуйста, попробуйте позже.');
            } finally {
                setLoading(false);
            }
        };

        fetchBooks(currentPage);
    }, [categoryId, currentPage]);

    // Синхронизируем ?page=... в URL при изменении currentPage
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
                <Typography variant="h4" sx={{ mb: 2 }}>
                    Книги по категории: {categoryId}
                </Typography>

                {/* Сообщение об ошибке, если есть */}
                <ErrorMessage message={errorMessage} />

                {/* Состояние загрузки */}
                {loading && (
                    <Typography variant="h5" sx={{ mb: 2 }}>
                        Загрузка...
                    </Typography>
                )}

                {/* Если не загружается и есть книги — показываем список */}
                {!loading && books.length > 0 && (
                    <BookList
                        books={books}
                        totalPages={totalPages}
                        currentPage={currentPage}
                        setCurrentPage={setCurrentPage}
                    />
                )}
            </Box>
        </div>
    );
};

export default SearchByCategory;
