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
    CircularProgress
} from '@mui/material';
import axios from 'axios';
import Cookies from 'js-cookie';
import { getCategories, sendFeedback as sendFeedbackApi, API_URL } from '../api';
import { UserContext } from '../context/UserContext';
import ErrorMessage from './ErrorMessage'; // если нужно, используйте свой компонент для ошибок

const Home = () => {
    const { user, setUser, loading } = useContext(UserContext);

    // --- Состояния для поиска ---
    const [title, setTitle] = useState('');
    const [description, setDescription] = useState('');
    const [minPrice, setMinPrice] = useState('');
    const [maxPrice, setMaxPrice] = useState('');
    const [bookId, setBookId] = useState('');
    const [categories, setCategories] = useState([]);
    const [exactPhraseTitle, setExactPhraseTitle] = useState(false);
    const [exactPhraseDescription, setExactPhraseDescription] = useState(false);

    // --- Состояния для логина (встроенная форма) ---
    const [loginEmail, setLoginEmail] = useState('');
    const [loginPassword, setLoginPassword] = useState('');
    const [loginError, setLoginError] = useState('');

    // --- Состояния для feedback (предложение) ---
    const [isFeedbackOpen, setIsFeedbackOpen] = useState(false);
    const [feedbackText, setFeedbackText] = useState('');
    const [feedbackError, setFeedbackError] = useState('');
    const [feedbackLoading, setFeedbackLoading] = useState(false);

    // --- Прочие ---
    const [apiStatus, setApiStatus] = useState('Checking API connection...');
    const navigate = useNavigate();

    // Загрузка категорий
    useEffect(() => {
        const fetchCategories = async () => {
            try {
                const response = await getCategories();
                setCategories(response.data);
                setApiStatus(''); // Успешно
            } catch (error) {
                console.error('Ошибка при загрузке категорий:', error);
                setApiStatus('Failed to connect to API');
            }
        };
        fetchCategories();
    }, []);

    // --- Поиск ---

    // Обёртка, чтобы проверять авторизацию перед поиском
    const checkAuthBeforeSearch = (searchFn) => {
        if (!user) {
            alert('Сначала авторизуйтесь, чтобы выполнять поиск.');
            return;
        }
        // Если авторизован, запускаем реальный поиск
        searchFn();
    };

    const handleTitleSearch = () => {
        checkAuthBeforeSearch(() => {
            if (title.trim()) {
                navigate(`/searchByTitle/${title}?exactPhrase=${exactPhraseTitle}`);
            }
        });
    };

    const handleDescriptionSearch = () => {
        checkAuthBeforeSearch(() => {
            if (description.trim()) {
                navigate(`/searchByDescription/${description}?exactPhrase=${exactPhraseDescription}`);
            }
        });
    };

    const handlePriceRangeSearch = () => {
        checkAuthBeforeSearch(() => {
            if (minPrice.trim() && maxPrice.trim()) {
                navigate(`/searchByPriceRange/${minPrice}/${maxPrice}`);
            }
        });
    };

    const handleIdSearch = () => {
        checkAuthBeforeSearch(() => {
            if (bookId.trim()) {
                navigate(`/books/${bookId}`);
            }
        });
    };

    // --- Логаут ---
    const handleLogout = () => {
        //document.cookie = 'token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT';
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

        setFeedbackLoading(true);
        try {
            await sendFeedbackApi(feedbackText);
            closeFeedback();
            alert('Спасибо за предложение! Мы учтём его.');
        } catch (err) {
            console.error('Ошибка при отправке предложения:', err);
            setFeedbackError(
                err.response?.data ?? 'Ошибка при отправке предложения. Попробуйте позже.'
            );
        } finally {
            setFeedbackLoading(false);
        }
    };

    // --- Логин прямо на главной ---
    const handleLogin = async () => {
        setLoginError('');
        try {
            // отправляем запрос
            const response = await axios.post(`${API_URL}/auth/login`, {
                email: loginEmail,
                password: loginPassword
            });

            //Cookies.set('token', response.data.token, { expires: 7 });
            // Вместо Cookies — localStorage:
            localStorage.setItem('token', response.data.token);

            // Сразу прописываем пользователя в контекст
            setUser(response.data.user);

            // чистим поля формы
            setLoginEmail('');
            setLoginPassword('');

            // переход или просто обновить UI
            // navigate('/');
        } catch (err) {
            console.error('Ошибка входа:', err);
            setLoginError('Неверные учётные данные или ошибка сервера.');
        }
    };   

    // Пока UserContext грузит данные (например, проверку токена)
    if (loading) {
        return <div>Загрузка пользователя...</div>;
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
                    диапазону. Полная версия поиска доступна по подписке.
                </Typography>
                <Typography variant="body1">
                    <b>Мы открыты к предложениям!</b>. Если у вас есть вопросы или предложения по дополнениям к нашему сервису, пишите через форму обратной связи. 
                </Typography>
            </div>

            {/* Если пользователь не авторизован — показываем форму логина */}
            {!user && (
                <div
                    style={{
                        border: '1px solid #ccc',
                        padding: '16px',
                        marginBottom: '20px',
                        maxWidth: '400px',
                        margin: '0 auto'
                    }}
                >
                    <Typography variant="h5" gutterBottom align="center">
                        Авторизация
                    </Typography>
                    <TextField
                        type="email"
                        label="Email"
                        variant="outlined"
                        value={loginEmail}
                        onChange={(e) => setLoginEmail(e.target.value)}
                        autoComplete="username"
                        fullWidth
                        sx={{ mb: 2 }}
                        onKeyDown={(e) => {
                            if (e.key === 'Enter') {
                                handleLogin();
                            }
                        }}
                    />
                    <TextField
                        type="password"
                        label="Пароль"
                        variant="outlined"
                        value={loginPassword}
                        onChange={(e) => setLoginPassword(e.target.value)}
                        autoComplete="current-password"
                        fullWidth
                        sx={{ mb: 2 }}
                        onKeyDown={(e) => {
                            if (e.key === 'Enter') {
                                handleLogin();
                            }
                        }}
                    />
                    {loginError && <ErrorMessage message={loginError} />}
                    <div style={{ textAlign: 'center', marginTop: '10px' }}>
                        <Button variant="contained" onClick={handleLogin}>
                            Войти
                        </Button>
                    </div>
                    <div style={{ textAlign: 'center', marginTop: '10px' }}>
                        <Typography variant="body2">
                            Нет аккаунта?{' '}
                            <Link to="/register">Зарегистрироваться</Link>
                        </Typography>
                    </div>
                </div>
            )}

            {/* Блоки поиска доступны всегда, но реально работать будут только для авторизованного пользователя */}
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

            {/* Для админа: поиск по ID + список категорий */}
            {user && user.role === 'Admin' && (
                <>
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

                    <div className="categories">
                        <Typography variant="h6">Категории</Typography>
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
                </>
            )}

            {/* Если пользователь авторизован, показываем доп. функционал (подписка и т.д.) */}
            {user && (
                <>
                    {!user.hasSubscription && (
                        <div
                            className="subscription-warning"
                            style={{ textAlign: 'center', marginBottom: 20 }}
                        >
                            <Typography color="error">
                                У вас нет подписки. Оформите подписку, чтобы получить доступ к полной версии поиска.{' '}
                                <Link to="/subscription">Подписаться сейчас</Link>
                            </Typography>
                        </div>
                    )}

                    {/* Ссылка на панель админа (для Admin) */}
                    {user.role === 'Admin' && (
                        <div className="admin-link" style={{ textAlign: 'center', marginBottom: 20 }}>
                            <Typography>
                                <Link to="/admin">Перейти в панель администратора</Link>
                            </Typography>
                        </div>
                    )}

                    <div className="search-box">
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
                        disabled={feedbackLoading}
                    >
                        {feedbackLoading ? <CircularProgress size={24} /> : 'Отправить'}
                    </Button>
                </DialogActions>
            </Dialog>
        </div>
    );
};

export default Home;
