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
    DialogActions
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

    // Открыть/закрыть диалог обратной связи
    const openFeedback = () => {
        setIsFeedbackOpen(true);
    };
    const closeFeedback = () => {
        setIsFeedbackOpen(false);
        setFeedbackText('');
        setFeedbackError('');
    };

    // Отправка предложения
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
            setFeedbackError(err.response?.data ?? 'Ошибка при отправке предложения. Попробуйте позже.');
        }
    };

    if (loading) {
        return <div>Загрузка...</div>;
    }

    return (
        <div className="home-container">
            {/* Статус API */}
            {apiStatus && apiStatus.includes('Failed') ? (
                <Typography variant="h6" color="error">
                    {apiStatus}
                </Typography>
            ) : (
                <Typography variant="h6" color="primary">
                    {apiStatus}
                </Typography>
            )}

            <div className="home-card">
                {/* Заголовок */}
                <Typography variant="h4" align="center" gutterBottom>
                    Добро пожаловать в Сервис Редких Книг
                </Typography>

                <Typography variant="body1" paragraph>
                    Сервис редких книг — это платформа, которая помогает любителям редких
                    книг находить, описывать и приобретать уникальные экземпляры. У нас
                    вы можете искать книги по названию, описанию, ценовому диапазону.
                </Typography>

                {user && !user.hasSubscription && (
                    <Typography variant="body1" paragraph color="error">
                        У вас нет подписки. <Link to="/subscription">Подписаться сейчас</Link>
                    </Typography>
                )}

                {user ? (
                    <>
                        {/* Админ-ссылка, если роль Admin */}
                        {user.role === 'Admin' && (
                            <Typography align="center" sx={{ marginBottom: 2 }}>
                                <Link to="/admin">Перейти в панель администратора</Link>
                            </Typography>
                        )}

                        {/* Блок поиска */}
                        <Typography variant="h5" align="center" gutterBottom>
                            Поиск
                        </Typography>

                        {/* Поиск по названию */}
                        <div className="home-search-box">
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
                        </div>

                        {/* Поиск по описанию */}
                        <div className="home-search-box">
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
                        </div>

                        {/* Поиск по диапазону цен */}
                        <div className="home-search-box">
                            <TextField
                                label="Мин. цена"
                                variant="outlined"
                                value={minPrice}
                                onChange={(e) => setMinPrice(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') handlePriceRangeSearch();
                                }}
                                sx={{ maxWidth: 150 }}
                            />
                            <TextField
                                label="Макс. цена"
                                variant="outlined"
                                value={maxPrice}
                                onChange={(e) => setMaxPrice(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') handlePriceRangeSearch();
                                }}
                                sx={{ maxWidth: 150 }}
                            />
                            <Button variant="contained" onClick={handlePriceRangeSearch}>
                                Поиск
                            </Button>
                        </div>

                        {/* Поиск по ID (только администратор) */}
                        {user.role === 'Admin' && (
                            <div className="home-search-box">
                                <TextField
                                    label="ID книги"
                                    variant="outlined"
                                    value={bookId}
                                    onChange={(e) => setBookId(e.target.value)}
                                    onKeyDown={(e) => {
                                        if (e.key === 'Enter') handleIdSearch();
                                    }}
                                    sx={{ maxWidth: 200 }}
                                />
                                <Button variant="contained" onClick={handleIdSearch}>
                                    Поиск по ID
                                </Button>
                            </div>
                        )}

                        {/* Категории (тоже только для администратора) */}
                        {user.role === 'Admin' && (
                            <div className="home-categories">
                                <Typography variant="h6" align="center" sx={{ marginTop: 2 }}>
                                    Категории
                                </Typography>
                                {Array.isArray(categories) && categories.length > 0 ? (
                                    <ul className="home-categories-list">
                                        {categories.map((cat) => (
                                            <li key={cat.id}>
                                                <Link to={`/searchByCategory/${cat.id}`}>
                                                    {cat.name}
                                                </Link>
                                            </li>
                                        ))}
                                    </ul>
                                ) : (
                                    <Typography variant="body2" color="textSecondary">
                                        Категории не найдены
                                    </Typography>
                                )}
                            </div>
                        )}

                        <div style={{ marginTop: '20px', textAlign: 'center' }}>
                            <Button variant="outlined" onClick={openFeedback}>
                                Оставить предложение
                            </Button>
                        </div>

                        <div style={{ marginTop: '20px', textAlign: 'center' }}>
                            <Button variant="contained" color="secondary" onClick={handleLogout}>
                                Выйти
                            </Button>
                        </div>

                        <Typography variant="body2" align="center" sx={{ marginTop: 1 }}>
                            Добро пожаловать, <strong>{user.userName}</strong>!
                        </Typography>
                    </>
                ) : (
                    <>
                        <Typography variant="body1" paragraph align="center">
                            Чтобы получить полный доступ к сервису,
                            пожалуйста, войдите или зарегистрируйтесь.
                        </Typography>

                        <div style={{ display: 'flex', justifyContent: 'center', gap: '10px' }}>
                            <Button variant="contained" color="primary" component={Link} to="/login">
                                Войти
                            </Button>
                            <Button variant="contained" color="secondary" component={Link} to="/register">
                                Регистрация
                            </Button>
                        </div>
                    </>
                )}
            </div>

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
