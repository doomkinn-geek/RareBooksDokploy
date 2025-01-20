// src/components/Home.jsx
import React, { useState, useEffect, useContext } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
    Button,
    Typography,
    Checkbox,
    FormControlLabel,
    TextField,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Box
} from '@mui/material';
import { getCategories, sendFeedback as sendFeedbackApi } from '../api';
import { UserContext } from '../context/UserContext';

const Home = () => {
    const { user, setUser, loading } = useContext(UserContext);

    const [title, setTitle] = useState('');
    const [description, setDescription] = useState('');
    const [minPrice, setMinPrice] = useState('');
    const [maxPrice, setMaxPrice] = useState('');
    const [bookId, setBookId] = useState('');
    const [categories, setCategories] = useState([]);
    const [exactPhraseTitle, setExactPhraseTitle] = useState(false);
    const [exactPhraseDescription, setExactPhraseDescription] = useState(false);
    const [apiStatus, setApiStatus] = useState('Checking API connection...');
    const navigate = useNavigate();

    // Форма обратной связи
    const [isFeedbackOpen, setIsFeedbackOpen] = useState(false);
    const [feedbackText, setFeedbackText] = useState('');
    const [feedbackError, setFeedbackError] = useState('');

    useEffect(() => {
        const fetchCategories = async () => {
            try {
                const response = await getCategories();
                setCategories(response.data);
                setApiStatus('');
            } catch (error) {
                console.error('Ошибка при загрузке категорий:', error);
                setApiStatus('Failed to connect to API');
            }
        };
        fetchCategories();
    }, []);

    // Методы поиска
    const handleTitleSearch = () => {
        if (title.trim()) {
            navigate(`/searchByTitle/${title}?exactPhrase=${exactPhraseTitle}`);
        }
    };
    const handleDescriptionSearch = () => {
        if (description.trim()) {
            navigate(`/searchByDescription/${description}?exactPhrase=${exactPhraseDescription}`);
        }
    };
    const handlePriceRangeSearch = () => {
        if (minPrice.trim() && maxPrice.trim()) {
            navigate(`/searchByPriceRange/${minPrice}/${maxPrice}`);
        }
    };
    const handleIdSearch = () => {
        if (bookId.trim()) {
            navigate(`/books/${bookId}`);
        }
    };

    // Логаут
    const handleLogout = () => {
        document.cookie = 'token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT';
        localStorage.removeItem('token');
        setUser(null);
        navigate('/');
    };

    // Обратная связь (диалог)
    const openFeedback = () => {
        setIsFeedbackOpen(true);
    };
    const closeFeedback = () => {
        setIsFeedbackOpen(false);
        setFeedbackText('');
        setFeedbackError('');
    };
    const sendFeedback = async () => {
        setFeedbackError('');
        if (!feedbackText.trim()) {
            setFeedbackError('Нельзя отправить пустое предложение!');
            return;
        }
        try {
            await sendFeedbackApi(feedbackText);
            closeFeedback();
            alert('Спасибо за предложение! Мы учтём его.');
        } catch (err) {
            console.error('Ошибка при отправке предложения:', err);
            setFeedbackError(
                err.response?.data ?? 'Ошибка при отправке предложения. Попробуйте позже.'
            );
        }
    };

    if (loading) {
        return <div>Загрузка...</div>;
    }

    return (
        <div className="container">
            <Typography variant="h6" color={apiStatus.includes('Failed') ? 'error' : 'primary'}>
                {apiStatus}
            </Typography>

            {/* Блок описания сервиса */}
            <Box sx={{ mb: 3, mt: 2 }}>
                <Typography variant="h4" gutterBottom>
                    Добро пожаловать в Сервис Редких Книг
                </Typography>
                <Typography variant="body1">
                    Сервис редких книг — это платформа, которая помогает любителям редких
                    книг находить, описывать и приобретать уникальные экземпляры. У нас
                    вы можете искать книги по названию, описанию, ценовому диапазону.
                    <br />
                    <b>Мы открыты к предложениям:</b> вносите инициативы по доработке сервиса
                    через форму обратной связи (кнопка ниже).
                </Typography>
                {user && !user.hasSubscription && (
                    <Box sx={{ mt: 2 }}>
                        <Typography variant="h6" color="error">
                            У вас нет подписки. Оформите подписку, чтобы получить доступ к полной
                            версии поиска. <Link to="/subscription">Подписаться сейчас</Link>
                        </Typography>
                    </Box>
                )}
            </Box>

            {/* Если авторизован */}
            {user ? (
                <>
                    {/* Если user.role === 'Admin' -> панель */}
                    {user.role === 'Admin' && (
                        <Box sx={{ mb: 2 }}>
                            <Typography>
                                <Link to="/admin">Перейти в панель администратора</Link>
                            </Typography>
                        </Box>
                    )}

                    {/* Блок поиска, оформим как Login-стиль */}
                    <Box
                        sx={{
                            maxWidth: 600,
                            margin: '0 auto',
                            display: 'flex',
                            flexDirection: 'column',
                            gap: 2
                        }}
                    >
                        <Typography variant="h5" align="center">
                            Поиск
                        </Typography>

                        {/* Поиск по названию */}
                        <Box
                            sx={{
                                display: 'flex',
                                flexDirection: 'column',
                                gap: 1,
                                backgroundColor: '#fff',
                                padding: 2,
                                borderRadius: 2,
                                boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
                            }}
                        >
                            <TextField
                                label="По названию"
                                variant="outlined"
                                value={title}
                                onChange={(e) => setTitle(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') handleTitleSearch();
                                }}
                            />
                            <FormControlLabel
                                control={
                                    <Checkbox
                                        checked={exactPhraseTitle}
                                        onChange={(e) => setExactPhraseTitle(e.target.checked)}
                                    />
                                }
                                label="Точная фраза"
                            />
                            <Button variant="contained" onClick={handleTitleSearch}>
                                Поиск
                            </Button>
                        </Box>

                        {/* Поиск по описанию */}
                        <Box
                            sx={{
                                display: 'flex',
                                flexDirection: 'column',
                                gap: 1,
                                backgroundColor: '#fff',
                                padding: 2,
                                borderRadius: 2,
                                boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
                            }}
                        >
                            <TextField
                                label="По описанию"
                                variant="outlined"
                                value={description}
                                onChange={(e) => setDescription(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') handleDescriptionSearch();
                                }}
                            />
                            <FormControlLabel
                                control={
                                    <Checkbox
                                        checked={exactPhraseDescription}
                                        onChange={(e) => setExactPhraseDescription(e.target.checked)}
                                    />
                                }
                                label="Точная фраза"
                            />
                            <Button variant="contained" onClick={handleDescriptionSearch}>
                                Поиск
                            </Button>
                        </Box>

                        {/* Поиск по диапазону цен */}
                        <Box
                            sx={{
                                display: 'flex',
                                flexDirection: 'column',
                                gap: 1,
                                backgroundColor: '#fff',
                                padding: 2,
                                borderRadius: 2,
                                boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
                            }}
                        >
                            <TextField
                                label="Мин. цена"
                                variant="outlined"
                                value={minPrice}
                                onChange={(e) => setMinPrice(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') handlePriceRangeSearch();
                                }}
                            />
                            <TextField
                                label="Макс. цена"
                                variant="outlined"
                                value={maxPrice}
                                onChange={(e) => setMaxPrice(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') handlePriceRangeSearch();
                                }}
                            />
                            <Button variant="contained" onClick={handlePriceRangeSearch}>
                                Поиск
                            </Button>
                        </Box>

                        {/* Поиск по ID (только администратор) */}
                        {user.role === 'Admin' && (
                            <Box
                                sx={{
                                    display: 'flex',
                                    flexDirection: 'column',
                                    gap: 1,
                                    backgroundColor: '#fff',
                                    padding: 2,
                                    borderRadius: 2,
                                    boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
                                }}
                            >
                                <TextField
                                    label="Поиск по ID книги"
                                    variant="outlined"
                                    value={bookId}
                                    onChange={(e) => setBookId(e.target.value)}
                                    onKeyDown={(e) => {
                                        if (e.key === 'Enter') handleIdSearch();
                                    }}
                                />
                                <Button variant="contained" onClick={handleIdSearch}>
                                    Поиск по ID
                                </Button>
                            </Box>
                        )}
                    </Box>

                    {/* Категории (для админа) */}
                    {user.role === 'Admin' && (
                        <Box
                            sx={{
                                maxWidth: 600,
                                margin: '20px auto 0 auto',
                                backgroundColor: '#fff',
                                padding: 2,
                                borderRadius: 2,
                                boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
                            }}
                        >
                            <Typography variant="h5">Категории</Typography>
                            <ul style={{ marginTop: '10px', listStyle: 'none', padding: 0 }}>
                                {Array.isArray(categories) ? (
                                    categories.map((category) => (
                                        <li key={category.id} style={{ marginBottom: '5px' }}>
                                            <Link
                                                to={`/searchByCategory/${category.id}`}
                                                style={{
                                                    textDecoration: 'none',
                                                    color: '#333',
                                                    border: '1px solid #ddd',
                                                    padding: '8px',
                                                    borderRadius: '4px',
                                                    display: 'inline-block',
                                                    backgroundColor: '#f9f9f9'
                                                }}
                                            >
                                                {category.name}
                                            </Link>
                                        </li>
                                    ))
                                ) : (
                                    <li>Категории не найдены</li>
                                )}
                            </ul>
                        </Box>
                    )}

                    <Box sx={{ mt: 3, textAlign: 'center' }}>
                        <Button variant="outlined" onClick={openFeedback}>
                            Оставить предложение
                        </Button>
                    </Box>

                    <Box sx={{ mt: 3, textAlign: 'center' }}>
                        <Button variant="contained" color="secondary" onClick={handleLogout}>
                            Выйти
                        </Button>
                    </Box>
                    <Box sx={{ mt: 2, textAlign: 'center' }}>
                        <Typography variant="body1">
                            Добро пожаловать, <strong>{user.userName}</strong>!
                        </Typography>
                    </Box>
                </>
            ) : (
                // Если user=null
                <>
                    <Box sx={{ mt: 3 }}>
                        <Typography variant="body1">
                            Чтобы получить полный доступ к сервису, пожалуйста,
                            войдите или зарегистрируйтесь.
                        </Typography>
                    </Box>

                    <Box sx={{ mt: 3, display: 'flex', gap: 2 }}>
                        <Button
                            variant="contained"
                            color="primary"
                            component={Link}
                            to="/login"
                        >
                            Войти
                        </Button>
                        <Button
                            variant="contained"
                            color="secondary"
                            component={Link}
                            to="/register"
                        >
                            Регистрация
                        </Button>
                    </Box>
                </>
            )}

            {/* Диалог обратной связи */}
            <Dialog open={isFeedbackOpen} onClose={closeFeedback}>
                <DialogTitle>Оставить предложение</DialogTitle>
                <DialogContent>
                    {feedbackError && (
                        <Typography color="error" sx={{ mb: 1 }}>
                            {feedbackError}
                        </Typography>
                    )}
                    <TextField
                        label="Ваше предложение"
                        multiline
                        rows={4}
                        value={feedbackText}
                        onChange={(e) => setFeedbackText(e.target.value)}
                        variant="outlined"
                        fullWidth
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={closeFeedback}>Отмена</Button>
                    <Button onClick={sendFeedback} variant="contained" color="primary">
                        Отправить
                    </Button>
                </DialogActions>
            </Dialog>
        </div>
    );
};

export default Home;
