// src/components/SearchBySeller.jsx
import React, { useEffect, useState } from 'react';
import { useParams, Link, useLocation, useNavigate } from 'react-router-dom';
import { searchBooksBySeller } from '../api';
import BookList from './BookList.jsx';
import { Typography, Box } from '@mui/material';
import ErrorMessage from './ErrorMessage';

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

    useEffect(() => {
        const fetchBooks = async (page = 1) => {
            setLoading(true);
            setErrorMessage('');
            try {
                const response = await searchBooksBySeller(sellerName, page);
                setBooks(response.data.items);
                setTotalPages(response.data.totalPages);
                setCurrentPage(page);

                if (response.data.items.length === 0) {
                    setErrorMessage('Ничего не найдено.');
                }
            } catch (error) {
                console.error('Ошибка поиска книг по продавцу:', error);
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
        <div className="container">
            <header className="header">
                <h1><Link to="/" style={{ color: '#fff', textDecoration: 'none' }}>Rare Books Service</Link></h1>
            </header>
            <Box>
                <Typography variant="h4">Книги продавца: {sellerName}</Typography>
                <ErrorMessage message={errorMessage} />
                {loading && <Typography variant="h5">Загрузка...</Typography>}
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

export default SearchBySeller;
