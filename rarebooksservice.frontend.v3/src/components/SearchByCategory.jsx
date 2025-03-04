// src/components/SearchByCategory.jsx
import React, { useState, useEffect, useContext } from 'react';
import { useParams, Link, useLocation, useNavigate } from 'react-router-dom';
import { 
    Typography, 
    Box, 
    Container, 
    Breadcrumbs, 
    CircularProgress, 
    Alert,
    Paper,
    Grid,
    Button,
    Divider 
} from '@mui/material';
import { searchBooksByCategory, getCategories } from '../api';
import BookList from './BookList';
import { LanguageContext } from '../context/LanguageContext';
import translations from '../translations';

// Импорт иконок
import NavigateNextIcon from '@mui/icons-material/NavigateNext';
import HomeIcon from '@mui/icons-material/Home';
import CategoryIcon from '@mui/icons-material/Category';
import BookIcon from '@mui/icons-material/Book';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';

const SearchByCategory = () => {
    const { categoryId } = useParams();
    const location = useLocation();
    const navigate = useNavigate();
    const { language } = useContext(LanguageContext);
    const t = translations[language];

    // Извлекаем ?page=... из URL, если он есть, иначе берём 1
    const query = new URLSearchParams(location.search);
    const initialPage = parseInt(query.get('page'), 10) || 1;

    // Состояния для книг, текущей/общей страниц
    const [books, setBooks] = useState([]);
    const [currentPage, setCurrentPage] = useState(initialPage);
    const [totalPages, setTotalPages] = useState(1);
    const [totalBooks, setTotalBooks] = useState(0);
    const [errorMessage, setErrorMessage] = useState('');
    const [loading, setLoading] = useState(false);
    const [categoryName, setCategoryName] = useState('');
    const [categoryDescription, setCategoryDescription] = useState('');
    const [categoryLoading, setCategoryLoading] = useState(true);

    // Загружаем информацию о категории
    useEffect(() => {
        const fetchCategoryInfo = async () => {
            setCategoryLoading(true);
            try {
                const response = await getCategories();
                const category = response.data.find(cat => cat.id === parseInt(categoryId, 10) || cat.id === categoryId);
                if (category) {
                    setCategoryName(category.name);
                    setCategoryDescription(category.description || '');
                } else {
                    setCategoryName(language === 'RU' ? 'Категория не найдена' : 'Category not found');
                }
            } catch (error) {
                console.error('Ошибка загрузки информации о категории:', error);
                setCategoryName(language === 'RU' ? 'Ошибка загрузки категории' : 'Error loading category');
            } finally {
                setCategoryLoading(false);
            }
        };

        fetchCategoryInfo();
    }, [categoryId, language]);

    // Загружаем книги по категории при изменении categoryId или currentPage
    useEffect(() => {
        const fetchBooks = async (page = 1) => {
            setLoading(true);
            setErrorMessage('');
            try {
                const response = await searchBooksByCategory(categoryId, page);
                setBooks(response.data.items);
                setTotalPages(response.data.totalPages);
                setTotalBooks(response.data.totalItems || 0);
                setCurrentPage(page);

                if (response.data.items.length === 0) {
                    setErrorMessage(language === 'RU' 
                        ? 'В этой категории нет книг.' 
                        : 'No books found in this category.');
                }
            } catch (error) {
                console.error('Ошибка поиска книг по категориям:', error);
                setErrorMessage(language === 'RU' 
                    ? 'Произошла ошибка при поиске книг. Пожалуйста, попробуйте позже.' 
                    : 'An error occurred while searching for books. Please try again later.');
            } finally {
                setLoading(false);
            }
        };

        fetchBooks(currentPage);
    }, [categoryId, currentPage, language]);

    // Синхронизируем ?page=... в URL при изменении currentPage
    useEffect(() => {
        const newQuery = new URLSearchParams();
        newQuery.set('page', currentPage);
        navigate(`?${newQuery.toString()}`, { replace: true });
    }, [currentPage, navigate]);

    return (
        <Container maxWidth="lg" sx={{ mt: 4, mb: 6 }}>
            {/* Хлебные крошки */}
            <Breadcrumbs separator={<NavigateNextIcon fontSize="small" />} aria-label="breadcrumb" sx={{ mb: 3 }}>
                <Link to="/" style={{ display: 'flex', alignItems: 'center', textDecoration: 'none', color: 'inherit' }}>
                    <HomeIcon sx={{ mr: 0.5 }} fontSize="inherit" />
                    {language === 'RU' ? 'Главная' : 'Home'}
                </Link>
                <Link to="/categories" style={{ display: 'flex', alignItems: 'center', textDecoration: 'none', color: 'inherit' }}>
                    <CategoryIcon sx={{ mr: 0.5 }} fontSize="inherit" />
                    {language === 'RU' ? 'Каталог категорий' : 'Categories catalog'}
                </Link>
                <Typography color="text.primary" sx={{ display: 'flex', alignItems: 'center' }}>
                    <BookIcon sx={{ mr: 0.5 }} fontSize="inherit" />
                    {categoryLoading 
                        ? (language === 'RU' ? 'Загрузка...' : 'Loading...') 
                        : categoryName}
                </Typography>
            </Breadcrumbs>

            <Button 
                variant="outlined" 
                startIcon={<ArrowBackIcon />} 
                component={Link} 
                to="/categories"
                sx={{ mb: 3 }}
            >
                {language === 'RU' ? 'Назад к категориям' : 'Back to categories'}
            </Button>

            <Paper elevation={0} sx={{ p: 3, mb: 4, borderRadius: '10px', bgcolor: '#f5f8ff' }}>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                    <CategoryIcon color="primary" sx={{ mr: 1.5, fontSize: 30 }} />
                    <Typography variant="h4" component="h1" fontWeight="bold">
                        {categoryLoading ? (
                            <CircularProgress size={24} sx={{ mr: 1, verticalAlign: 'middle' }} />
                        ) : (
                            categoryName
                        )}
                    </Typography>
                </Box>

                {categoryDescription && (
                    <Typography variant="body1" color="text.secondary" sx={{ mt: 1 }}>
                        {categoryDescription}
                    </Typography>
                )}

                {!categoryLoading && !loading && totalBooks > 0 && (
                    <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
                        {language === 'RU'
                            ? `Найдено книг: ${totalBooks}`
                            : `Found books: ${totalBooks}`}
                    </Typography>
                )}
            </Paper>

            {/* Сообщение об ошибке и состояния загрузки */}
            {errorMessage && (
                <Alert severity="info" sx={{ mb: 4 }}>
                    {errorMessage}
                </Alert>
            )}

            {loading && (
                <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', my: 6 }}>
                    <CircularProgress size={40} sx={{ mb: 2 }} />
                    <Typography variant="body1">
                        {language === 'RU' ? 'Загрузка книг...' : 'Loading books...'}
                    </Typography>
                </Box>
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
        </Container>
    );
};

export default SearchByCategory;
