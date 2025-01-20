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

    // --- Методы поиска ---
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

    // --- Логаут ---
    const handleLogout = () => {
        document.cookie = 'token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT';
        localStorage.removeItem('token');
        setUser(null);
        navigate('/');
    };

    // --- Обратная связь ---
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
        <div className="container" style={{ maxWidth: '800px', margin: '0 auto' }}>
            {/* Статус API */}
            <Typography variant="h6" color={apiStatus.includes('Failed') ? 'error' : 'primary'}>
                {apiStatus}
            </Typography>

            {/* Описание сервиса */}
            <div style={{ margin: '20px 0', textAlign: 'center' }}>
                <Typography variant="h4" gutterBottom>
                    Добро пожаловать в Сервис Редких Книг
                </Typography>
                <Typography variant="body1">
                    Сервис редких книг — это платформа, которая помогает любителям редких
                    книг находить, описывать и приобретать уникальные экземпляры. У нас
                    вы можете искать книги по названию, описанию, ценовому диапазону...
                    <b> Мы открыты к предложениям!</b>
                </Typography>
                {!loading && user && !user.hasSubscription && (
                    <Box sx={{ mt: 2 }}>
                        <Typography variant="h6" color="error">
                            Подписка на сервис позволяет получить полную информацию
                            по искомым книгам.
                        </Typography>
                    </Box>
                )}
            </div>

            {user ? (
                <>
                    {/* Предупреждение об отсутствии подписки */}
                    {!user.hasSubscription && (
                        <div className="subscription-warning" style={{ textAlign: 'center' }}>
                            <Typography color="error">
                                У вас нет подписки. <Link to="/subscription">Подписаться сейчас</Link>
                            </Typography>
                        </div>
                    )}

                    {/* Ссылка на панель админа (только для Admin) */}
                    {user.role === 'Admin' && (
                        <Box sx={{ textAlign: 'center', mt: 2 }}>
                            <Typography>
                                <Link to="/admin">Перейти в панель администратора</Link>
                            </Typography>
                        </Box>
                    )}

                    {/* --- Блок поиска --- */}
                    <Box className="search-section" sx={{ mt: 4 }}>
                        <Typography variant="h5" align="center" gutterBottom>
                            Поиск
                        </Typography>

                        {/* Поиск по названию */}
                        <Box sx={{
                            display: 'flex',
                            gap: 2,
                            alignItems: 'center',
                            justifyContent: 'center',
                            mb: 2,
                            flexWrap: 'wrap'
                        }}>
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
                        <Box sx={{
                            display: 'flex',
                            gap: 2,
                            alignItems: 'center',
                            justifyContent: 'center',
                            mb: 2,
                            flexWrap: 'wrap'
                        }}>
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
                                        onChange={(e) =>
                                            setExactPhraseDescription(e.target.checked)
                                        }
                                    />
                                }
                                label="Точная фраза"
                            />
                            <Button variant="contained" onClick={handleDescriptionSearch}>
                                Поиск
                            </Button>
                        </Box>

                        {/* Поиск по диапазону цен */}
                        <Box sx={{
                            display: 'flex',
                            gap: 2,
                            alignItems: 'center',
                            justifyContent: 'center',
                            mb: 2,
                            flexWrap: 'wrap'
                        }}>
                            <TextField
                                label="Мин. цена"
                                variant="outlined"
                                value={minPrice}
                                onChange={(e) => setMinPrice(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') handlePriceRangeSearch();
                                }}
                                sx={{ width: '140px' }}
                            />
                            <TextField
                                label="Макс. цена"
                                variant="outlined"
                                value={maxPrice}
                                onChange={(e) => setMaxPrice(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') handlePriceRangeSearch();
                                }}
                                sx={{ width: '140px' }}
                            />
                            <Button variant="contained" onClick={handlePriceRangeSearch}>
                                Поиск
                            </Button>
                        </Box>

                        {/* Поиск по ID (только администратор) */}
                        {user.role === 'Admin' && (
                            <Box sx={{
                                display: 'flex',
                                gap: 2,
                                alignItems: 'center',
                                justifyContent: 'center',
                                mb: 2,
                                flexWrap: 'wrap'
                            }}>
                                <TextField
                                    label="Введите ID книги"
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

                    {/* --- Секция категорий (не меняем стили) --- */}
                    {user.role === 'Admin' && (
                        <div className="categories">
                            <Typography variant="h5">Категории</Typography>
                            <ul>
                                {Array.isArray(categories) ? (
                                    categories.map((category) => (
                                        <li key={category.id}>
                                            <Link to={`/searchByCategory/${category.id}`}>
                                                {category.name}
                                            </Link>
                                        </li>
                                    ))
                                ) : (
                                    <li>Категории не найдены</li>
                                )}
                            </ul>
                        </div>
                    )}

                    <Box sx={{ textAlign: 'center', mt: 3 }}>
                        <Button variant="outlined" onClick={openFeedback}>
                            Оставить предложение
                        </Button>
                    </Box>

                    <Box sx={{ textAlign: 'center', mt: 3 }}>
                        <Button variant="contained" color="secondary" onClick={handleLogout}>
                            Выйти
                        </Button>
                    </Box>

                    <Box sx={{ textAlign: 'center', mt: 2 }}>
                        Добро пожаловать, <strong>{user.userName}</strong>!
                    </Box>
                </>
            ) : (
                <>
                    <Box sx={{ textAlign: 'center', mt: 4 }}>
                        <Typography variant="body1">
                            Чтобы получить полный доступ к сервису, пожалуйста, войдите
                            или зарегистрируйтесь.
                        </Typography>
                    </Box>

                    <Box className="auth-links" sx={{ display: 'flex', gap: 2, justifyContent: 'center', mt: 3 }}>
                        <Button variant="contained" component={Link} to="/login">
                            Войти
                        </Button>
                        <Button variant="contained" color="secondary" component={Link} to="/register">
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
