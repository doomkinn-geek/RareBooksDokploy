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
//                                 ^^^^^^^^^^^^^^^^^^^^^   важно: импортируем sendFeedback
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
    const [feedbackError, setFeedbackError] = useState(''); // можно вывести ошибку при отправке

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

    // Методы поиска (handleTitleSearch, handleDescriptionSearch, ...)
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
            // Если успех:
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
        <div className="container" text>
            {/* Статус API */}
            <Typography variant="h6" color={apiStatus.includes('Failed') ? 'error' : 'primary'}>
                {apiStatus}
            </Typography>

            {/* Блок описания сервиса */}
            <div style={{ margin: '20px 0' }}>
                <Typography variant="h4" gutterBottom>
                    Добро пожаловать в Сервис Редких Книг
                </Typography>
                <Typography variant="body1">
                    Сервис редких книг — это платформа, которая помогает любителям редких
                    книг находить, описывать и приобретать уникальные экземпляры У нас
                    вы можете искать книги по названию, описанию, ценовому
                    диапазону. <b>Мы открыты к предложениям.</b> Вносите свои инциативы по доработке сервиса через
                    форму обратной связи.
                </Typography>
                {!loading && user && !user.hasSubscription && (
                    <div>
                        <br />
                        <h3><b>Подписка на сервис позволяет получить полную информацию по искомым книгам.</b></h3>
                    </div>
                )}
            </div>

            {user ? (
                <>
                    {/* Предупреждение об отсутствии подписки */}
                    {!user.hasSubscription && (
                        <div className="subscription-warning">
                            <Typography color="error">
                                У вас нет подписки. Оформите подписку, чтобы получить доступ к полной версии поиска.<Link to="/subscription">Подписаться сейчас</Link>
                            </Typography>
                        </div>
                    )}
                    {/* Ссылка на панель админа (только для Admin) */}
                    {user.role === 'Admin' && (
                        <div className="admin-link">
                            <Typography>
                                <Link to="/admin">Перейти в панель администратора</Link>
                            </Typography>
                        </div>
                    )}

                    {/* Блок поиска */}
                    {/* Блок поиска (добавим класс/стиль для центровки) */}
                    <div
                        className="search-section"
                        style={{
                            maxWidth: '600px',
                            margin: '0 auto',
                            textAlign: 'center'
                        }}
                    >
                        <Typography variant="h5" gutterBottom>
                            Поиск
                        </Typography>

                        {/* Поиск по названию */}
                        <div className="search-box" style={{ flexDirection: 'column', gap: '10px' }}>
                            <TextField
                                label="По названию"
                                variant="outlined"
                                value={title}
                                onChange={(e) => setTitle(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') handleTitleSearch();
                                }}
                            />
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                <FormControlLabel
                                    control={
                                        <Checkbox
                                            checked={exactPhraseTitle}
                                            onChange={(e) => setExactPhraseTitle(e.target.checked)}
                                        />
                                    }
                                    label="Точная фраза"
                                />
                                <Button
                                    variant="contained"
                                    style={{ backgroundColor: '#ffcc00', color: '#000' }}
                                    onClick={handleTitleSearch}
                                >
                                    Поиск
                                </Button>
                            </div>
                        </div>

                        {/* Поиск по описанию */}
                        <div className="search-box" style={{ flexDirection: 'column', gap: '10px' }}>
                            <TextField
                                label="По описанию"
                                variant="outlined"
                                value={description}
                                onChange={(e) => setDescription(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') handleDescriptionSearch();
                                }}
                            />
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                <FormControlLabel
                                    control={
                                        <Checkbox
                                            checked={exactPhraseDescription}
                                            onChange={(e) => setExactPhraseDescription(e.target.checked)}
                                        />
                                    }
                                    label="Точная фраза"
                                />
                                <Button
                                    variant="contained"
                                    style={{ backgroundColor: '#ffcc00', color: '#000' }}
                                    onClick={handleDescriptionSearch}
                                >
                                    Поиск
                                </Button>
                            </div>
                        </div>

                        {/* Поиск по диапазону цен */}
                        <div className="search-box" style={{ flexDirection: 'column', gap: '10px' }}>
                            <div style={{ display: 'flex', gap: '10px' }}>
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
                            <Button
                                variant="contained"
                                style={{ backgroundColor: '#ffcc00', color: '#000' }}
                                onClick={handlePriceRangeSearch}
                            >
                                Поиск
                            </Button>
                        </div>

                        {/* Поиск по ID (только администратор) */}
                        {user.role === 'Admin' && (
                            <div className="search-box" style={{ flexDirection: 'column', gap: '10px' }}>
                                <TextField
                                    label="ID книги"
                                    variant="outlined"
                                    value={bookId}
                                    onChange={(e) => setBookId(e.target.value)}
                                    onKeyDown={(e) => {
                                        if (e.key === 'Enter') handleIdSearch();
                                    }}
                                />
                                <Button
                                    variant="contained"
                                    style={{ backgroundColor: '#ffcc00', color: '#000' }}
                                    onClick={handleIdSearch}
                                >
                                    Поиск по ID
                                </Button>
                            </div>
                        )}
                    </div>

                    {/* Секция категорий (не меняем!) */}
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

                    {/* ...кнопка "Оставить предложение" и пр... */}
                    <div style={{ marginTop: '20px' }}>
                        <Button variant="outlined" onClick={openFeedback}>
                            Оставить предложение
                        </Button>
                    </div>

                    <div className="auth-links" style={{ marginTop: '20px' }}>
                        <Button variant="contained" color="secondary" onClick={handleLogout}>
                            Выйти
                        </Button>
                    </div>
                    <div style={{ marginTop: '10px' }}>
                        Добро пожаловать, <strong>{user.userName}</strong>!
                    </div>
                </>
            ) : (
                <>
                    <div style={{ marginTop: '20px' }}>
                        <Typography variant="body1">
                            Чтобы получить полный доступ к сервису, пожалуйста, войдите или зарегистрируйтесь.
                        </Typography>
                    </div>

                    <div className="auth-links" style={{ marginTop: '20px' }}>
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
