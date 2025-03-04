import React, { useState, useEffect, useContext } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { 
    Typography, 
    Container, 
    Grid, 
    Card, 
    CardContent, 
    CardActionArea,
    Box, 
    Divider, 
    CircularProgress, 
    Alert,
    Breadcrumbs,
    Paper 
} from '@mui/material';
import { getCategories } from '../api';
import { LanguageContext } from '../context/LanguageContext';
import translations from '../translations';

// Импорт иконок
import CategoryIcon from '@mui/icons-material/Category';
import NavigateNextIcon from '@mui/icons-material/NavigateNext';
import HomeIcon from '@mui/icons-material/Home';
import BookIcon from '@mui/icons-material/Book';

const Categories = () => {
    const [categories, setCategories] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const navigate = useNavigate();
    const { language } = useContext(LanguageContext);
    const t = translations[language];

    useEffect(() => {
        const fetchCategories = async () => {
            setLoading(true);
            try {
                const response = await getCategories();
                setCategories(response.data);
            } catch (error) {
                console.error('Ошибка при загрузке категорий:', error);
                setError(language === 'RU' ? 
                    'Ошибка при загрузке списка категорий. Пожалуйста, попробуйте позже.' : 
                    'Error loading categories. Please try again later.');
            } finally {
                setLoading(false);
            }
        };

        fetchCategories();
    }, [language]);

    const handleCategoryClick = (categoryId) => {
        navigate(`/searchByCategory/${categoryId}`);
    };

    // Создаем карточку для каждой категории
    const renderCategoryCard = (category, index) => {
        return (
            <Grid item xs={12} sm={6} md={4} key={category.id || index}>
                <Card 
                    elevation={2} 
                    sx={{ 
                        height: '100%', 
                        display: 'flex', 
                        flexDirection: 'column',
                        borderRadius: '10px',
                        transition: 'transform 0.2s, box-shadow 0.2s',
                        '&:hover': {
                            transform: 'translateY(-5px)',
                            boxShadow: '0 8px 16px rgba(0,0,0,0.1)'
                        }
                    }}
                >
                    <CardActionArea 
                        onClick={() => handleCategoryClick(category.id)}
                        sx={{ 
                            flex: 1, 
                            display: 'flex', 
                            flexDirection: 'column', 
                            alignItems: 'flex-start',
                            justifyContent: 'flex-start',
                            p: 2
                        }}
                    >
                        <Box 
                            sx={{ 
                                display: 'flex', 
                                alignItems: 'center', 
                                width: '100%',
                                mb: 2
                            }}
                        >
                            <CategoryIcon color="primary" sx={{ fontSize: 30, mr: 1.5 }} />
                            <Typography variant="h6" component="h2" color="primary">
                                {category.name}
                            </Typography>
                        </Box>
                        
                        <Divider sx={{ width: '100%', mb: 2 }} />
                        
                        <Box 
                            sx={{ 
                                display: 'flex', 
                                alignItems: 'center', 
                                bgcolor: 'primary.light', 
                                color: 'primary.contrastText',
                                py: 0.8,
                                px: 1.5,
                                borderRadius: '20px',
                                fontWeight: 'bold'
                            }}
                        >
                            <BookIcon sx={{ mr: 1, fontSize: 20 }} />
                            <Typography variant="subtitle1" fontWeight="bold">
                                {language === 'RU' 
                                    ? `${category.bookCount || '0'} книг` 
                                    : `${category.bookCount || '0'} books`}
                            </Typography>
                        </Box>
                        
                        {category.description && (
                            <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                                {category.description}
                            </Typography>
                        )}
                    </CardActionArea>
                </Card>
            </Grid>
        );
    };

    return (
        <Container maxWidth="lg" sx={{ mt: 4, mb: 6 }}>
            {/* Хлебные крошки */}
            <Breadcrumbs separator={<NavigateNextIcon fontSize="small" />} aria-label="breadcrumb" sx={{ mb: 3 }}>
                <Link to="/" style={{ display: 'flex', alignItems: 'center', textDecoration: 'none', color: 'inherit' }}>
                    <HomeIcon sx={{ mr: 0.5 }} fontSize="inherit" />
                    {language === 'RU' ? 'Главная' : 'Home'}
                </Link>
                <Typography color="text.primary" sx={{ display: 'flex', alignItems: 'center' }}>
                    <CategoryIcon sx={{ mr: 0.5 }} fontSize="inherit" />
                    {language === 'RU' ? 'Каталог категорий' : 'Categories catalog'}
                </Typography>
            </Breadcrumbs>

            <Paper elevation={0} sx={{ p: 3, mb: 4, borderRadius: '10px', bgcolor: '#f5f8ff' }}>
                <Typography variant="h4" component="h1" gutterBottom fontWeight="bold">
                    {language === 'RU' ? 'Каталог категорий' : 'Categories catalog'}
                </Typography>
                <Typography variant="body1" color="text.secondary">
                    {language === 'RU' 
                        ? 'Выберите категорию, чтобы просмотреть книги в этой категории.' 
                        : 'Select a category to browse books in that category.'}
                </Typography>
            </Paper>

            {loading && (
                <Box sx={{ display: 'flex', justifyContent: 'center', my: 6 }}>
                    <CircularProgress />
                </Box>
            )}

            {error && (
                <Alert severity="error" sx={{ mb: 4 }}>
                    {error}
                </Alert>
            )}

            {!loading && !error && categories.length === 0 && (
                <Alert severity="info" sx={{ mb: 4 }}>
                    {language === 'RU'
                        ? 'Категории не найдены. Они будут добавлены в ближайшее время.'
                        : 'No categories found. They will be added soon.'}
                </Alert>
            )}

            {!loading && !error && categories.length > 0 && (
                <Grid container spacing={3}>
                    {categories.map((category, index) => renderCategoryCard(category, index))}
                </Grid>
            )}
        </Container>
    );
};

export default Categories; 