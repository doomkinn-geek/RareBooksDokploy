// src/components/BookSearchByTitle.jsx

import React, { useState, useEffect } from 'react';
import { useParams, Link, useLocation, useNavigate } from 'react-router-dom';
import { 
    searchBooksByTitle, 
    getCategories 
} from '../api';
import BookList from './BookList';
import { 
    Typography, 
    Box,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Chip,
    OutlinedInput,
    Checkbox,
    ListItemText,
    Paper,
    Button
} from '@mui/material';
import ErrorMessage from './ErrorMessage';
import FilterListIcon from '@mui/icons-material/FilterList';
import CategoryIcon from '@mui/icons-material/Category';

const ITEM_HEIGHT = 48;
const ITEM_PADDING_TOP = 8;
const MenuProps = {
    PaperProps: {
        style: {
            maxHeight: ITEM_HEIGHT * 4.5 + ITEM_PADDING_TOP,
            width: 250,
        },
    },
};

const BookSearchByTitle = () => {
    const { title } = useParams();
    const location = useLocation();
    const navigate = useNavigate();

    const query = new URLSearchParams(location.search);
    const exactPhrase = query.get('exactPhrase') === 'true';
    const initialPage = parseInt(query.get('page'), 10) || 1;
    
    // Состояние для книг и пагинации
    const [books, setBooks] = useState([]);
    const [currentPage, setCurrentPage] = useState(initialPage);
    const [totalPages, setTotalPages] = useState(1);
    
    // Состояние для ошибок и загрузки
    const [errorMessage, setErrorMessage] = useState('');
    const [loading, setLoading] = useState(false);
    
    // Состояние для запросов
    const [remainingRequests, setRemainingRequests] = useState(null);
    
    // Новое: состояние для категорий
    const [categories, setCategories] = useState([]);
    const [selectedCategories, setSelectedCategories] = useState([]);
    const [loadingCategories, setLoadingCategories] = useState(false);
    
    // Загружаем категории при монтировании компонента
    useEffect(() => {
        const loadCategories = async () => {
            setLoadingCategories(true);
            try {
                const response = await getCategories();
                if (response.data && Array.isArray(response.data)) {
                    setCategories(response.data);
                }
            } catch (error) {
                console.error('Ошибка при загрузке категорий:', error);
            } finally {
                setLoadingCategories(false);
            }
        };
        
        loadCategories();
    }, []);

    useEffect(() => {
        const fetchBooks = async (page = 1) => {
            setLoading(true);
            setErrorMessage('');
            try {
                // Используем выбранные категории для поиска
                const categoryIds = selectedCategories.map(cat => cat.id);
                const response = await searchBooksByTitle(title, exactPhrase, categoryIds, page);

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
                console.error('Ошибка поиска книг:', error);
                setBooks([]);
                setErrorMessage('Произошла ошибка при поиске книг. Попробуйте позже.');
            } finally {
                setLoading(false);
            }
        };

        fetchBooks(currentPage);
    }, [title, exactPhrase, currentPage, selectedCategories]);


    useEffect(() => {
        const newQuery = new URLSearchParams();
        newQuery.set('exactPhrase', exactPhrase);
        newQuery.set('page', currentPage);
        navigate(`?${newQuery.toString()}`, { replace: true });
    }, [exactPhrase, currentPage, navigate]);
    
    const handleCategoryChange = (event) => {
        const {
            target: { value },
        } = event;

        // Находим полные объекты категорий на основе выбранных ID
        const selectedCats = value.map(selectedId => 
            categories.find(cat => cat.id === selectedId)
        );
        
        setSelectedCategories(selectedCats);
        // Сбрасываем страницу при изменении категорий
        setCurrentPage(1);
    };
    
    const clearCategoryFilter = () => {
        setSelectedCategories([]);
        setCurrentPage(1);
    };

    return (
        <div className="container">
            <Box sx={{ mb: 2 }}>
                <Typography variant="h5" sx={{ fontWeight: 'bold', marginTop: '10px' }}>
                    Книги по названию: {title}
                </Typography>
            </Box>
            
            {/* Новое: фильтр категорий */}
            <Paper elevation={0} sx={{ p: 2, mb: 3, bgcolor: '#f5f8ff', borderRadius: '8px' }}>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                    <FilterListIcon sx={{ mr: 1, color: '#4527a0' }} />
                    <Typography variant="h6">Фильтры</Typography>
                </Box>
                
                <FormControl sx={{ width: { xs: '100%', md: 300 }, mt: 1 }}>
                    <InputLabel id="category-multiple-checkbox-label">Категории</InputLabel>
                    <Select
                        labelId="category-multiple-checkbox-label"
                        id="category-multiple-checkbox"
                        multiple
                        value={selectedCategories.map(cat => cat.id)}
                        onChange={handleCategoryChange}
                        input={<OutlinedInput label="Категории" />}
                        renderValue={(selected) => (
                            <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                                {selected.map((selectedId) => {
                                    const category = categories.find(cat => cat.id === selectedId);
                                    return (
                                        <Chip 
                                            key={selectedId} 
                                            label={category ? category.name : selectedId} 
                                            size="small" 
                                            icon={<CategoryIcon sx={{ fontSize: 16 }} />}
                                        />
                                    );
                                })}
                            </Box>
                        )}
                        MenuProps={MenuProps}
                        disabled={loadingCategories}
                    >
                        {categories.map((category) => (
                            <MenuItem key={category.id} value={category.id}>
                                <Checkbox checked={selectedCategories.some(c => c.id === category.id)} />
                                <ListItemText primary={category.name} />
                            </MenuItem>
                        ))}
                    </Select>
                </FormControl>
                
                {selectedCategories.length > 0 && (
                    <Button 
                        variant="outlined" 
                        size="small" 
                        onClick={clearCategoryFilter} 
                        sx={{ mt: 1, ml: 1 }}
                    >
                        Очистить фильтр
                    </Button>
                )}
            </Paper>

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
