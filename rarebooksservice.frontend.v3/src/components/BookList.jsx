//src/components/BookList.jsx
import React, { useEffect, useState, useContext } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Card, CardContent, Typography, Box, Button, Pagination } from '@mui/material';
import { getBookImages, getBookThumbnail } from '../api';
import { UserContext } from '../context/UserContext';

const BookList = ({ books, totalPages, currentPage, setCurrentPage }) => {
    const [thumbnails, setThumbnails] = useState({});
    const [error, setError] = useState(null);
    const navigate = useNavigate();
    const { user } = useContext(UserContext);

    useEffect(() => {
        const fetchThumbnails = async () => {
            if (!books || books.length === 0) return; // Нет книг - нет запросов

            const newThumbnails = {};
            for (const book of books) {
                try {
                    const response = await getBookImages(book.id);
                    const thumbnailName = response.data.thumbnails[0];

                    if (thumbnailName) {
                        const thumbnailResponse = await getBookThumbnail(book.id, thumbnailName);
                        const thumbnailUrl = URL.createObjectURL(thumbnailResponse.data);
                        newThumbnails[book.id] = thumbnailUrl;
                    }
                } catch (error) {
                    console.error(`Error fetching thumbnails for book ${book.id}:`, error.response || error.message);
                    setError('Failed to load thumbnails. Please try again later.');
                }
            }
            setThumbnails(newThumbnails);
        };

        fetchThumbnails();
    }, [books]);

    const handleNextPage = () => {
        if (currentPage < totalPages) {
            setCurrentPage(currentPage + 1);
        }
    };

    const handlePreviousPage = () => {
        if (currentPage > 1) {
            setCurrentPage(currentPage - 1);
        }
    };

    const handlePageChange = (event, value) => {
        setCurrentPage(value);
    };

    const handleBookClick = (bookId) => {
        navigate(`/books/${bookId}`, { state: { fromPage: currentPage } });
    };

    return (
        <Box sx={{ my: 2 }}>
            {error && <Typography color="error">{error}</Typography>}
            {books.map((book) => (
                <Card key={book.id} sx={{ my: 1 }}>
                    <CardContent sx={{ display: 'flex' }}>
                        {thumbnails[book.id] && (
                            <Box sx={{ width: '150px', marginRight: '16px' }}>
                                <img
                                    src={thumbnails[book.id]}
                                    alt="Book Thumbnail"
                                    style={{ width: '100%', height: 'auto' }}
                                />
                            </Box>
                        )}
                        <Box>
                            <Typography variant="h5" component="div" onClick={() => handleBookClick(book.id)} style={{ textDecoration: 'none', color: 'inherit', cursor: 'pointer' }}>
                                {book.title}
                            </Typography>
                            <Typography variant="body1">Цена: {book.price}</Typography>
                            <Typography variant="body1">Дата: {book.date}</Typography>
                            <Typography variant="body2" component={Link} to={`/searchBySeller/${book.sellerName}`} style={{ textDecoration: 'none', color: 'inherit' }}>
                                Продавец: {book.sellerName}
                            </Typography>
                            <Typography variant="body1">Тип: {book.type}</Typography>
                        </Box>
                    </CardContent>
                </Card>
            ))}
            {books.length > 0 && (
                <Box sx={{ display: 'flex', justifyContent: 'space-between', mt: 2 }}>
                    <Button variant="contained" onClick={handlePreviousPage} disabled={currentPage === 1}>
                        Предыдущая страница
                    </Button>
                    <Pagination
                        count={totalPages}
                        page={currentPage}
                        onChange={handlePageChange}
                        color="primary"
                    />
                    <Button variant="contained" onClick={handleNextPage} disabled={currentPage === totalPages}>
                        Следующая страница
                    </Button>
                </Box>
            )}
        </Box>
    );
};

export default BookList;
