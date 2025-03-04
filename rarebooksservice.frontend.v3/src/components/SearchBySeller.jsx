// src/components/SearchBySeller.jsx
import React, { useState, useEffect } from 'react';
import { useParams, Link, useLocation, useNavigate } from 'react-router-dom';
import { searchBooksBySeller } from '../api';
import BookList from './BookList.jsx';
import { Typography, Box, Container, Paper, Breadcrumbs } from '@mui/material';
import ErrorMessage from './ErrorMessage';

// Импорт иконок для breadcrumbs
import HomeIcon from '@mui/icons-material/Home';
import StoreIcon from '@mui/icons-material/Store';
import NavigateNextIcon from '@mui/icons-material/NavigateNext';

const SearchBySeller = () => {
    const { sellerName } = useParams();
    const location = useLocation();
    const navigate = useNavigate();

    const query = new URLSearchParams(location.search);
    const initialPage = parseInt(query.get('page'), 10) || 1;

    const [books, setBooks] = useState([]);
    const [currentPage, setCurrentPage] = useState(initialPage);
    const [totalPages, setTotalPages] = useState(1);
    const [errorMessage, setErrorMessage] = useState('');
    const [loading, setLoading] = useState(false);
    const [remainingRequests, setRemainingRequests] = useState(null);

    useEffect(() => {
        const fetchBooks = async (page = 1) => {
            setLoading(true);
            setErrorMessage('');
            try {
                const response = await searchBooksBySeller(sellerName, page);
                
                const { data } = response;
                if (!data || !Array.isArray(data.items)) {
                    setBooks([]);
                    setErrorMessage('Сервер вернул неожиданные данные.');
                } else {
                    setBooks(data.items);
                    setTotalPages(data.totalPages);
                    setRemainingRequests(data.remainingRequests);

                    if (data.items.length === 0) {
                        setErrorMessage('Ничего не найдено.');
                    }
                }
            } catch (error) {
                console.error('Ошибка поиска книг по продавцу:', error);
                setBooks([]);
                setErrorMessage('Произошла ошибка при поиске книг. Пожалуйста, попробуйте позже.');
            } finally {
                setLoading(false);
            }
        };

        fetchBooks(currentPage);
    }, [sellerName, currentPage]);

    useEffect(() => {
        const newQuery = new URLSearchParams();
        newQuery.set('page', currentPage);
        navigate(`?${newQuery.toString()}`, { replace: true });
    }, [currentPage, navigate]);

    return (
        <Container maxWidth="lg" sx={{ py: 4 }}>
            {/* Хлебные крошки */}
            <Breadcrumbs 
                separator={<NavigateNextIcon fontSize="small" />} 
                aria-label="breadcrumb" 
                sx={{ mb: 3 }}
            >
                <Link to="/" style={{ display: 'flex', alignItems: 'center', textDecoration: 'none', color: 'inherit' }}>
                    <HomeIcon sx={{ mr: 0.5 }} fontSize="inherit" />
                    Главная
                </Link>
                <Typography color="text.primary" sx={{ display: 'flex', alignItems: 'center' }}>
                    <StoreIcon sx={{ mr: 0.5 }} fontSize="inherit" />
                    Книги продавца
                </Typography>
            </Breadcrumbs>

            <Paper elevation={0} sx={{ p: 3, mb: 4, borderRadius: '10px', bgcolor: '#f5f8ff' }}>
                <Typography variant="h4" component="h1" gutterBottom fontWeight="bold">
                    Книги продавца: {sellerName}
                </Typography>
                <Typography variant="body1" color="text.secondary">
                    Все книги, выставленные продавцом на продажу.
                </Typography>
            </Paper>

            <ErrorMessage message={errorMessage} />
            {loading && <Typography variant="h6">Загрузка...</Typography>}

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
        </Container>
    );
};

export default SearchBySeller;
