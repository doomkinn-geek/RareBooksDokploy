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
import { getCategories } from '../api';
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

    // Обратная связь
    const openFeedback = () => {
        setIsFeedbackOpen(true);
    };
    const closeFeedback = () => {
        setIsFeedbackOpen(false);
        setFeedbackText('');
    };
    const sendFeedback = () => {
        // Здесь вы можете сделать запрос на сервер, чтобы сохранить предложение
        // Например, axios.post('/api/feedback', { text: feedbackText })
        console.log('Отправляем фидбек:', feedbackText);
        closeFeedback();
        alert('Спасибо за предложение! Мы учтём его.');
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
                    книг находить, описывать и приобретать уникальные экземпляры. У нас
                    вы можете искать книги по названию, описанию, ценовому
                    диапазону. Также вы можете связаться
                    с продавцами и следить за интересующими вас лотами.
                </Typography>                
            </div>

            {user ? (
                <>
                    {/* Предупреждение об отсутствии подписки */}
                    {!user.hasSubscription && (
                        <div className="subscription-warning">
                            <Typography color="error">
                                У вас нет подписки. <Link to="/subscription">Подписаться сейчас</Link>
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
                    <div className="search-section">
                        <Typography variant="h5" gutterBottom>
                            Поиск
                        </Typography>

                        {/* Поиск по названию */}
                        <div className="search-box">
                            <input
                                type="text"
                                placeholder="По названию"
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
                            <button onClick={handleTitleSearch}>Поиск</button>
                        </div>

                        {/* Поиск по описанию */}
                        <div className="search-box">
                            <input
                                type="text"
                                placeholder="По описанию"
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
                            <button onClick={handleDescriptionSearch}>Поиск</button>
                        </div>

                        {/* Поиск по диапазону цен */}
                        <div className="search-box">
                            <input
                                type="text"
                                placeholder="Мин. цена"
                                value={minPrice}
                                onChange={(e) => setMinPrice(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') handlePriceRangeSearch();
                                }}
                            />
                            <input
                                type="text"
                                placeholder="Макс. цена"
                                value={maxPrice}
                                onChange={(e) => setMaxPrice(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') handlePriceRangeSearch();
                                }}
                            />
                            <button onClick={handlePriceRangeSearch}>Поиск</button>
                        </div>

                        {/* Поиск по ID (только администратор) */}
                        {user.role === 'Admin' && (
                            <div className="search-box">
                                <input
                                    type="text"
                                    placeholder="Введите ID книги"
                                    value={bookId}
                                    onChange={(e) => setBookId(e.target.value)}
                                    onKeyDown={(e) => {
                                        if (e.key === 'Enter') handleIdSearch();
                                    }}
                                />
                                <button onClick={handleIdSearch}>Поиск по ID</button>
                            </div>
                        )}
                    </div>

                    {/* Секция категорий (тоже только для администратора) */}
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
