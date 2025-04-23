// src/components/BookSearchByTitle.jsx

import React, { useState, useEffect, useContext } from 'react';
import { useParams, Link, useLocation, useNavigate } from 'react-router-dom';
import { searchBooksByTitle, getCategories } from '../api';
import BookList from './BookList';
import { 
    Typography, 
    Box, 
    FormControl, 
    InputLabel, 
    Select, 
    MenuItem, 
    Checkbox, 
    ListItemText, 
    OutlinedInput, 
    Chip,
    FormControlLabel,
    Switch,
    Grid,
    Button,
    Paper
} from '@mui/material';
import ErrorMessage from './ErrorMessage';
import FilterListIcon from '@mui/icons-material/FilterList';
import { LanguageContext } from '../context/LanguageContext';
import translations from '../translations';

const BookSearchByTitle = () => {
    const { title } = useParams();
    const location = useLocation();
    const navigate = useNavigate();
    const { language } = useContext(LanguageContext);
    const t = translations[language];

    const query = new URLSearchParams(location.search);
    const exactPhrase = query.get('exactPhrase') === 'true';
    const initialPage = parseInt(query.get('page'), 10) || 1;
    const initialCategoryIds = query.get('categoryIds') ? query.get('categoryIds').split(',').map(id => parseInt(id)) : [];

    const [books, setBooks] = useState([]);
    const [currentPage, setCurrentPage] = useState(initialPage);
    const [totalPages, setTotalPages] = useState(1);
    const [categories, setCategories] = useState([]);
    const [selectedCategories, setSelectedCategories] = useState(initialCategoryIds);
    const [showFilters, setShowFilters] = useState(false);

    const [errorMessage, setErrorMessage] = useState('');
    const [loading, setLoading] = useState(false);
    const [remainingRequests, setRemainingRequests] = useState(null);

    // Загрузка списка категорий при монтировании компонента
    useEffect(() => {
        const fetchCategories = async () => {
            try {
                const response = await getCategories();
                setCategories(response.data);
            } catch (error) {
                console.error('Ошибка при загрузке категорий:', error);
            }
        };

        fetchCategories();
    }, []);

    useEffect(() => {
        const fetchBooks = async (page = 1) => {
            setLoading(true);
            setErrorMessage('');
            try {
                const response = await searchBooksByTitle(title, exactPhrase, page, 10, selectedCategories);

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
    }, [title, exactPhrase, currentPage, selectedCategories]);

    useEffect(() => {
        const newQuery = new URLSearchParams();
        newQuery.set('exactPhrase', exactPhrase);
        newQuery.set('page', currentPage);
        if (selectedCategories.length > 0) {
            newQuery.set('categoryIds', selectedCategories.join(','));
        }
        navigate(`?${newQuery.toString()}`, { replace: true });
    }, [exactPhrase, currentPage, navigate, selectedCategories]);

    const handleCategoryChange = (event) => {
        const {
            target: { value },
        } = event;
        setSelectedCategories(typeof value === 'string' ? value.split(',').map(id => parseInt(id)) : value);
        setCurrentPage(1); // Сбрасываем страницу при изменении фильтров
    };

    const handleResetFilters = () => {
        setSelectedCategories([]);
        setCurrentPage(1);
    };

    return (
        <div className="container">
            <Box sx={{ mb: 2 }}>
                <Typography variant="h5" sx={{ fontWeight: 'bold', marginTop: '10px' }}>
                    {language === 'RU' ? 'Книги по названию:' : 'Books by title:'} {title}
                </Typography>
            </Box>

            <Box sx={{ mb: 3 }}>
                <Button 
                    variant="outlined" 
                    startIcon={<FilterListIcon />}
                    onClick={() => setShowFilters(!showFilters)}
                    sx={{ mb: 1 }}
                >
                    {language === 'RU' ? 'Фильтры' : 'Filters'}
                </Button>
                
                {showFilters && (
                    <Paper sx={{ p: 2, mt: 1 }}>
                        <Grid container spacing={2} alignItems="center">
                            <Grid item xs={12} md={6}>
                                <FormControl fullWidth>
                                    <InputLabel id="category-select-label">
                                        {language === 'RU' ? 'Категории' : 'Categories'}
                                    </InputLabel>
                                    <Select
                                        labelId="category-select-label"
                                        multiple
                                        value={selectedCategories}
                                        onChange={handleCategoryChange}
                                        input={<OutlinedInput label={language === 'RU' ? 'Категории' : 'Categories'} />}
                                        renderValue={(selected) => (
                                            <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                                                {selected.map((value) => {
                                                    const category = categories.find(cat => cat.id === value);
                                                    return (
                                                        <Chip 
                                                            key={value} 
                                                            label={category ? category.name : value} 
                                                        />
                                                    );
                                                })}
                                            </Box>
                                        )}
                                    >
                                        {categories.map((category) => (
                                            <MenuItem key={category.id} value={category.id}>
                                                <Checkbox checked={selectedCategories.indexOf(category.id) > -1} />
                                                <ListItemText 
                                                    primary={category.name} 
                                                    secondary={`${language === 'RU' ? 'Книг' : 'Books'}: ${category.bookCount}`} 
                                                />
                                            </MenuItem>
                                        ))}
                                    </Select>
                                </FormControl>
                            </Grid>
                            <Grid item xs={12} md={3}>
                                <FormControlLabel
                                    control={
                                        <Switch 
                                            checked={exactPhrase} 
                                            onChange={(e) => navigate(`?exactPhrase=${e.target.checked}&page=1${selectedCategories.length > 0 ? `&categoryIds=${selectedCategories.join(',')}` : ''}`)}
                                        />
                                    }
                                    label={language === 'RU' ? 'Точная фраза' : 'Exact phrase'}
                                />
                            </Grid>
                            <Grid item xs={12} md={3}>
                                <Button 
                                    variant="outlined" 
                                    onClick={handleResetFilters}
                                    fullWidth
                                >
                                    {language === 'RU' ? 'Сбросить фильтры' : 'Reset filters'}
                                </Button>
                            </Grid>
                        </Grid>
                    </Paper>
                )}
            </Box>

            <ErrorMessage message={errorMessage} />
            {loading && <Typography variant="h6">{language === 'RU' ? 'Загрузка...' : 'Loading...'}</Typography>}

            {/* Отображаем, сколько осталось запросов, если сервер прислал remainingRequests */}
            {!loading && (remainingRequests !== null) && (
                <Typography variant="body1" sx={{ color: '#666', marginBottom: '8px' }}>
                    {language === 'RU' ? 'Осталось запросов в этом месяце:' : 'Remaining requests this month:'} {remainingRequests === null ? (language === 'RU' ? 'безлимит' : 'unlimited') : remainingRequests}
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
