// src/components/Home.jsx
import React, { useState, useEffect, useContext } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { getCategories } from '../api';
import { Button, Typography, Checkbox, FormControlLabel } from '@mui/material';
import { UserContext } from '../context/UserContext';
import axios from 'axios';
import { API_URL } from '../api';

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

    // ------------------------------------------------------------
    // Грузим категории (если система настроена)
    // ------------------------------------------------------------
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

    // ------------------ Обработчики поиска ------------------
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

    // ------------------ Логаут ------------------
    const handleLogout = () => {
        document.cookie = 'token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT';
        localStorage.removeItem('token');
        setUser(null);
        navigate('/');
    };

    if (loading) {
        return <div>Загрузка...</div>;
    }

    return (
        <div className="container">
            <Typography variant="h6" color={apiStatus.includes('Failed') ? 'error' : 'primary'}>
                {apiStatus}
            </Typography>
            {user ? (
                <>
                    {!user.hasSubscription && (
                        <div className="subscription-warning">
                            <Typography color="error">
                                У вас нет подписки. <Link to="/subscription">Подписаться сейчас</Link>
                            </Typography>
                        </div>
                    )}
                    {user.role === 'Admin' && (
                        <div className="admin-link">
                            <Typography>
                                <Link to="/admin">Перейти в панель администратора</Link>
                            </Typography>
                        </div>
                    )}

                    {/* Блок поиска */}
                    <div className="search-section">
                        <h2>Поиск</h2>

                        {/* Поиск по названию */}
                        <div className="search-box">
                            <input
                                type="text"
                                placeholder="Поиск по названию книги"
                                value={title}
                                onChange={(e) => setTitle(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') {
                                        handleTitleSearch();
                                    }
                                }}
                            />
                            <FormControlLabel
                                control={
                                    <Checkbox
                                        checked={exactPhraseTitle}
                                        onChange={(e) =>
                                            setExactPhraseTitle(e.target.checked)
                                        }
                                    />
                                }
                                label="Искать точную фразу"
                            />
                            <button onClick={handleTitleSearch}>Поиск</button>
                        </div>

                        {/* Поиск по описанию */}
                        <div className="search-box">
                            <input
                                type="text"
                                placeholder="Поиск по описанию"
                                value={description}
                                onChange={(e) => setDescription(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') {
                                        handleDescriptionSearch();
                                    }
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
                                label="Искать точную фразу"
                            />
                            <button onClick={handleDescriptionSearch}>Поиск</button>
                        </div>

                        {/* Поиск по диапазону цен */}
                        <div className="search-box">
                            <input
                                type="text"
                                placeholder="Минимальная цена"
                                value={minPrice}
                                onChange={(e) => setMinPrice(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') {
                                        handlePriceRangeSearch();
                                    }
                                }}
                            />
                            <input
                                type="text"
                                placeholder="Максимальная цена"
                                value={maxPrice}
                                onChange={(e) => setMaxPrice(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') {
                                        handlePriceRangeSearch();
                                    }
                                }}
                            />
                            <button onClick={handlePriceRangeSearch}>Поиск</button>
                        </div>

                        {/* Поиск по ID */}
                        <div className="search-box">
                            <input
                                type="text"
                                placeholder="Введите ID книги"
                                value={bookId}
                                onChange={(e) => setBookId(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') {
                                        handleIdSearch();
                                    }
                                }}
                            />
                            <button onClick={handleIdSearch}>Поиск по ID</button>
                        </div>
                    </div>

                    {/* Секция категорий */}
                    <div className="categories">
                        <h2>Категории</h2>
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

                    <div className="auth-links">
                        <Button
                            variant="contained"
                            color="secondary"
                            onClick={handleLogout}
                        >
                            Выйти
                        </Button>
                    </div>
                    <div>Добро пожаловать, {user.userName}!</div>
                </>
            ) : (
                // Если user=null
                <>
                    <div className="auth-links">
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
                    </div>
                    <div>Пожалуйста, войдите в систему.</div>
                </>
            )}
        </div>
    );
};

export default Home;
