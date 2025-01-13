// src/components/Home.jsx
import React, { useState, useEffect, useContext } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { getCategories } from '../api';
import { Button, Typography, Checkbox, FormControlLabel } from '@mui/material';
import { UserContext } from '../context/UserContext';
import axios from 'axios';
import { API_URL } from '../api';

const Home = () => {
    const {
        user, setUser,
        loading, isConfigured, setIsConfigured, configCheckDone
    } = useContext(UserContext);

    // ------------------------------------------------------------
    // Состояния обычного домашнего экрана
    // ------------------------------------------------------------
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
    // Состояния для setup
    // ------------------------------------------------------------
    const [adminEmail, setAdminEmail] = useState('');
    const [adminPassword, setAdminPassword] = useState('');
    const [connectionString, setConnectionString] = useState('');
    const [setupError, setSetupError] = useState('');
    const [message, setMessage] = useState('');

    // ------------------------------------------------------------
    // Грузим категории (если система настроена)
    // ------------------------------------------------------------
    useEffect(() => {
        if (!isConfigured) {
            return;
        }
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
    }, [isConfigured]);

    // ------------------------------------------------------------
    // Если ещё идёт проверка configCheckDone, 
    // можно показать "Проверка системы..." 
    // ------------------------------------------------------------
    /*if (!isConfigured) {
        const handleInitialize = async () => {
            try {
                setSetupError('');
                const res = await axios.post(
                    `${API_URL}/setup/initialize`,
                    {
                        adminEmail,
                        adminPassword,
                        connectionString,
                    },
                    {
                        headers: {
                            'Content-Type': 'application/json',
                        },
                    }
                );       
                if (res.data.success) {
                    setIsConfigured(true);
                    setMessage('Сервер уходит на перезапуск...' + JSON.stringify(res.data));
                } else {
                    setSetupError('Не удалось выполнить настройку.');
                }
            } catch (error) {
                console.error('Ошибка при настройке:', error);
                setSetupError(`Ошибка при настройке: ${error.message}`);
            }
        };

        return (
            <div className="admin-panel-container">
                <h2>Первичная настройка</h2>
                <p>Заполните настройки приложения.</p>
                {setupError && <div style={{ color: 'red' }}>{setupError}</div>}
                <div className="admin-section">
                    <label>Admin E-mail:</label><br />
                    <input
                        type="email"
                        value={adminEmail}
                        onChange={(e) => setAdminEmail(e.target.value)}
                    />
                </div>
                <div className="admin-section">
                    <label>Admin Password:</label><br />
                    <input
                        type="password"
                        value={adminPassword}
                        onChange={(e) => setAdminPassword(e.target.value)}
                    />
                </div>
                <div className="admin-section">
                    <label>Connection String:</label><br />
                    <input
                        type="text"
                        value={connectionString}
                        onChange={(e) => setConnectionString(e.target.value)}
                    />
                </div>
                <button className="admin-button" onClick={handleInitialize}>
                    Инициализировать
                </button>
                {}
                {message && <div style={{ marginTop: '10px' }}>{message}</div>}
            </div>
        );
    }*/

    // ------------------------------------------------------------
    // 2) Если система УЖЕ настроена -> обычная логика Home
    // ------------------------------------------------------------

    const handleTitleSearch = async () => {
        if (title.trim()) {
            navigate(`/searchByTitle/${title}?exactPhrase=${exactPhraseTitle}`);
        }
    };
    const handleDescriptionSearch = async () => {
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
    const handleLogout = () => {
        document.cookie = 'token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT';
        localStorage.removeItem('token');
        setUser(null);
        navigate('/');
    };

    // Если isConfigured=true, но loading ещё true — значит, грузим user
    if (loading) {
        return <div>Загрузка...</div>;
    }

    // Дальше: если user есть -> показываем с поиском и т.д.
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
                    <div className="search-section">
                        <h2>Поиск</h2>
                        <div className="search-box">
                            <input
                                type="text"
                                placeholder="Поиск по названию книги"
                                value={title}
                                onChange={(e) => setTitle(e.target.value)}
                            />
                            <FormControlLabel
                                control={<Checkbox
                                    checked={exactPhraseTitle}
                                    onChange={(e) => setExactPhraseTitle(e.target.checked)}
                                />}
                                label="Искать точную фразу"
                            />
                            <button onClick={handleTitleSearch}>Поиск</button>
                        </div>
                        <div className="search-box">
                            <input
                                type="text"
                                placeholder="Поиск по описанию"
                                value={description}
                                onChange={(e) => setDescription(e.target.value)}
                            />
                            <FormControlLabel
                                control={<Checkbox
                                    checked={exactPhraseDescription}
                                    onChange={(e) => setExactPhraseDescription(e.target.checked)}
                                />}
                                label="Искать точную фразу"
                            />
                            <button onClick={handleDescriptionSearch}>Поиск</button>
                        </div>
                        <div className="search-box">
                            <input
                                type="text"
                                placeholder="Минимальная цена"
                                value={minPrice}
                                onChange={(e) => setMinPrice(e.target.value)}
                            />
                            <input
                                type="text"
                                placeholder="Максимальная цена"
                                value={maxPrice}
                                onChange={(e) => setMaxPrice(e.target.value)}
                            />
                            <button onClick={handlePriceRangeSearch}>Поиск</button>
                        </div>
                        <div className="search-box">
                            <input
                                type="text"
                                placeholder="Введите ID книги"
                                value={bookId}
                                onChange={(e) => setBookId(e.target.value)}
                            />
                            <button onClick={handleIdSearch}>Поиск по ID</button>
                        </div>
                    </div>
                    <div className="categories">
                        <h2>Категории</h2>
                        <ul>
                            {Array.isArray(categories) ? (
                                categories.map((category) => (
                                    <li key={category.id}>
                                        <Link to={`/searchByCategory/${category.id}`}>{category.name}</Link>
                                    </li>
                                ))
                            ) : (
                                <li>Категории не найдены</li>
                            )}
                        </ul>
                    </div>
                    <div className="auth-links">
                        <Button variant="contained" color="secondary" onClick={handleLogout}>
                            Выйти
                        </Button>
                    </div>
                    <div>
                        <div>Добро пожаловать, {user.userName}!</div>
                    </div>
                </>
            ) : (
                // Если user=null, система настроена
                // -> показываем кнопки "Войти", "Регистрация"
                <>
                    <div className="auth-links">
                        <Button variant="contained" color="primary" component={Link} to="/login">
                            Войти
                        </Button>
                        <Button variant="contained" color="secondary" component={Link} to="/register">
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
