// src/components/Login.jsx
import React, { useState, useContext } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import axios from 'axios';
import { UserContext } from '../context/UserContext';
import { API_URL } from '../api';
import ErrorMessage from './ErrorMessage';
import { Button, TextField, Typography } from '@mui/material';

const Login = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const { setUser } = useContext(UserContext);
    const navigate = useNavigate();
    const [error, setError] = useState('');

    const handleLogin = async () => {
        setError('');
        try {
            const response = await axios.post(`${API_URL}/auth/login`, { email, password });
            //Cookies.set('token', response.data.token, { expires: 7 });
            // вместо Cookies:
            localStorage.setItem('token', response.data.token);

            // прописываем пользователя в контекст
            setUser(response.data.user);

            navigate('/');
        } catch (err) {
            console.error('Ошибка входа:', err);
            setError('Неверные учетные данные или проблемы с сервером.');
        }
    };

    return (
        <div className="container" style={{ maxWidth: '480px', margin: '0 auto' }}>
            <Typography variant="h4" align="center" gutterBottom>
                Вход
            </Typography>

            <div className="auth-form" style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                <TextField
                    type="email"
                    label="Email"
                    variant="outlined"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    autoComplete="username"
                />
                <TextField
                    type="password"
                    label="Пароль"
                    variant="outlined"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    autoComplete="current-password"
                />
                <Button variant="contained" onClick={handleLogin}>
                    Войти
                </Button>
                <ErrorMessage message={error} />

                <Typography variant="body2" align="center">
                    Нет аккаунта? <Link to="/register">Зарегистрироваться</Link>
                </Typography>
            </div>
        </div>
    );
};

export default Login;
