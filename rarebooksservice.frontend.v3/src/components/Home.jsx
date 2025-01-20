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

    // Форма обратной связи (Dialog)
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
        <div className="container">
            {/* Статус API */}
            <Typography
                variant="h6"
                color={apiStatus.includes('Failed') ? 'error' : 'primary'}
                align="center"
                sx={{ marginBottom: 2 }}
            >
                {apiStatus}
            </Typography>

            {/* Блок описания сервиса */}
            <div style={{ marginBottom: 20, textAlign: 'center' }}>
                <Typography variant="h4" gutterBottom>
                    Добро пожаловать в Сервис Редких Книг
                </Typography>
                <Typography variant="body1">
                    Сервис редких книг — это платформа, которая помогает любителям редких
                    книг находить, описывать и приобретать уникальные экземпляры.
                    У нас вы можете искать книги по названию, описанию, ценовому
                    диапазону. <b>Мы открыты к предложениям!</b>
                </Typography>
                {user && !user.hasSubscription && (
                    <div style={{ marginTop: 10 }}>
                        <Typography variant="subtitle1" color="error">
                            Подписка на сервис позволяет получить полную информацию по искомым книгам.
                        </Typography>
                    </div>
                )}
            </div>

            {user ? (
                <>
                    {/* Предупреждение об отсутствии подписки */}
                    {!user.hasSubscription && (
                        <div
                            className="subscription-warning"
                            style={{ textAlign: 'center', marginBottom: 20 }}
                        >
                            <Typography color="error">
                                У вас нет подписки. Оформите подписку, чтобы получить доступ к полной версии поиска.{" "}
                                <Link to="/subscription">Подписаться сейчас</Link>
                            </Typography>
                        </div>
                    )}

                    {/* Ссылка на панель админа (только для Admin) */}
                    {user.role === 'Admin' && (
                        <div className="admin-link" style={{ textAlign: 'center', marginBottom: 20 }}>
                            <Typography>
                                <Link to="/admin">Перейти в панель администратора</Link>
                            </Typography>
                        </div>
                    )}

                    {/* Поиск по названию */}
                    <div className="search-box">
                        <Typography variant="h6">Поиск по названию</Typography>
                        <TextField
                            label="Название"
                            variant="outlined"
                            value={title}
                            onChange={(e) => setTitle(e.target.value)}
                            onKeyDown={(e) => {
                                if (e.key === 'Enter') handleTitleSearch();
                            }}
                            fullWidth
                        />
                        <div className="search-row">
                            {/* Левый чекбокс */}
                            <FormControlLabel
                                control={
                                    <Checkbox
                                        checked={exactPhraseTitle}
                                        onChange={(e) => setExactPhraseTitle(e.target.checked)}
                                    />
                                }
                                label="Точная фраза"
                                className="search-checkbox"
                            />
                            {/* Правая кнопка */}
                            <Button
                                variant="contained"
                                className="search-button-right"
                                style={{ backgroundColor: '#ffcc00', color: '#000' }}
                                onClick={handleTitleSearch}
                            >
                                Поиск
                            </Button>
                        </div>
                    </div>

                    {/* Поиск по описанию */}
                    <div className="search-box">
                        <Typography variant="h6">Поиск по описанию</Typography>
                        <TextField
                            label="Описание"
                            variant="outlined"
                            value={description}
                            onChange={(e) => setDescription(e.target.value)}
                            onKeyDown={(e) => {
                                if (e.key === 'Enter') handleDescriptionSearch();
                            }}
                            fullWidth
                        />
                        <div className="search-row">
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
                                className="search-checkbox"
                            />
                            <Button
                                variant="contained"
                                className="search-button-right"
                                style={{ backgroundColor: '#ffcc00', color: '#000' }}
                                onClick={handleDescriptionSearch}
                            >
                                Поиск
                            </Button>
                        </div>
                    </div>

                    {/* Поиск по диапазону цен */}
                    <div className="search-box">
                        <Typography variant="h6">Поиск по диапазону цен</Typography>
                        <div className="price-inputs-row">
                            <TextField
                                label="Мин. цена"
                                variant="outlined"
                                type="number"
                                value={minPrice}
                                onChange={(e) => setMinPrice(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') handlePriceRangeSearch();
                                }}
                                sx={{ flex: 1 }}
                            />
                            <TextField
                                label="Макс. цена"
                                variant="outlined"
                                type="number"
                                value={maxPrice}
                                onChange={(e) => setMaxPrice(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') handlePriceRangeSearch();
                                }}
                                sx={{ flex: 1 }}
                            />
                        </div>
                        <div className="search-row" style={{ justifyContent: 'flex-end' }}>
                            <Button
                                variant="contained"
                                className="search-button-right"
                                style={{ backgroundColor: '#ffcc00', color: '#000' }}
                                onClick={handlePriceRangeSearch}
                            >
                                Поиск
                            </Button>
                        </div>
                    </div>

                    {/* Поиск по ID (только для Admin) */}
                    {user.role === 'Admin' && (
                        <div className="search-box">
                            <Typography variant="h6">
                                Поиск по ID (только для администратора)
                            </Typography>
                            <div className="price-inputs-row">
                                <TextField
                                    label="ID книги"
                                    variant="outlined"
                                    value={bookId}
                                    onChange={(e) => setBookId(e.target.value)}
                                    onKeyDown={(e) => {
                                        if (e.key === 'Enter') handleIdSearch();
                                    }}
                                    sx={{ flex: 1 }}
                                />
                            </div>
                            <div className="search-row" style={{ justifyContent: 'flex-end' }}>
                                <Button
                                    variant="contained"
                                    className="search-button-right"
                                    style={{ backgroundColor: '#ffcc00', color: '#000' }}
                                    onClick={handleIdSearch}
                                >
                                    Поиск по ID
                                </Button>
                            </div>
                        </div>
                    )}                    

                    {/* Секция категорий (если Admin) */}
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

                    {/* Блок информации о пользователе и выход */}
                    <div className="search-box">
                        {/* Просто условно назовём это .user-info-row */}
                        <div className="user-info-row">
                            <Typography variant="subtitle1" sx={{ flex: 1 }}>
                                Добро пожаловать, <strong>{user.userName}</strong>!
                            </Typography>
                            <Button
                                variant="contained"
                                color="secondary"
                                onClick={handleLogout}
                            >
                                Выйти
                            </Button>
                        </div>
                    </div>

                    {/* Кнопка "Оставить предложение" */}
                    <div style={{ marginTop: 20, textAlign: 'center' }}>
                        <Button variant="outlined" onClick={openFeedback}>
                            Оставить предложение
                        </Button>
                    </div>
                </>
            ) : (
                // Если user=null
                <>
                    <div style={{ marginTop: '20px', textAlign: 'center' }}>
                        <Typography variant="body1">
                            Чтобы получить полный доступ к сервису, пожалуйста, войдите или зарегистрируйтесь.
                        </Typography>
                    </div>

                    <div className="auth-links" style={{ marginTop: '20px', textAlign: 'center' }}>
                        <Button variant="contained" color="primary" component={Link} to="/login">
                            Войти
                        </Button>
                        <Button variant="contained" color="secondary" component={Link} to="/register">
                            Регистрация
                        </Button>
                    </div>
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
                    <Button
                        variant="contained"
                        style={{ backgroundColor: '#ffcc00', color: '#000' }}
                        onClick={sendFeedback}
                    >
                        Отправить
                    </Button>
                </DialogActions>
            </Dialog>
        </div>
    );
};

export default Home;
