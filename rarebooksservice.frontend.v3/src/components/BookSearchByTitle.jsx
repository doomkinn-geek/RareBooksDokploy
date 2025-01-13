// src/components/BookSearchByTitle.jsx
import React, { useState, useEffect } from 'react';
import { useParams, Link, useLocation, useNavigate } from 'react-router-dom';
import { searchBooksByTitle } from '../api';
import BookList from './BookList.jsx';
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

    useEffect(() => {
        const fetchBooks = async (page = 1) => {
            setLoading(true);
            setErrorMessage('');
            try {
                const response = await searchBooksByTitle(title, exactPhrase, page);
                setBooks(response.data.items);
                setTotalPages(response.data.totalPages);
                setCurrentPage(page);

                if (response.data.items.length === 0) {
                    setErrorMessage('Ничего не найдено.');
                }
            } catch (error) {
                console.error('Ошибка поиска книг по названию:', error);
                setErrorMessage(
                    'Произошла ошибка при поиске книг. Пожалуйста, попробуйте позже.'
                );
            } finally {
                setLoading(false);
            }
        };

        fetchBooks(currentPage);
    }, [title, exactPhrase, currentPage]);

    // При изменении страницы или exactPhrase меняем URL
    useEffect(() => {
        const newQuery = new URLSearchParams();
        newQuery.set('exactPhrase', exactPhrase);
        newQuery.set('page', currentPage);
        navigate(`?${newQuery.toString()}`, { replace: true });
    }, [exactPhrase, currentPage, navigate]);

    return (
        <div className="container">
            {/* 
               Убираем второй большой header, 
               т.к. в App.jsx (или Home.jsx) уже есть основной (если вы не хотите его дублировать).
               Если нужен логотип/название, делайте его меньше, 
               например <div style={{ fontSize: '1.2rem', marginBottom: '10px' }}>Rare Books Service</div>
            */}
            <Box sx={{ mb: 2 }}>
                <Typography
                    variant="h5" /* чуть меньше, чем h4 */
                    sx={{
                        fontWeight: 'bold',
                        marginTop: '10px'
                    }}
                >
                    Книги по названию: {title}
                </Typography>
            </Box>
            <ErrorMessage message={errorMessage} />
            {loading && <Typography variant="h6">Загрузка...</Typography>}
            {!loading && books.length > 0 && (
                <BookList
                    books={books}
                    totalPages={totalPages}
                    currentPage={currentPage}
                    setCurrentPage={setCurrentPage}
                />
            )}

            {/* Футер тоже можно сделать компактнее на мобилке */}
            <footer className="footer" style={{ marginTop: '20px' }}>
                <p>&copy; 2024 Rare Books Service. All rights reserved.</p>
            </footer>
        </div>
    );
};

export default BookSearchByTitle;
