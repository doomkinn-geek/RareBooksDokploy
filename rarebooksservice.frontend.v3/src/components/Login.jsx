//src/components/Login.jsx
import React, { useState, useContext } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import Cookies from 'js-cookie';
import { UserContext } from '../context/UserContext';
import { API_URL } from '../api';
import ErrorMessage from './ErrorMessage';

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
            Cookies.set('token', response.data.token, { expires: 7 });
            setUser(response.data.user);
            navigate('/');
        } catch (error) {
            console.error('Ошибка входа:', error);
            setError('Неверные учетные данные или проблемы с сервером.');
        }
    };

    return (
        <div className="container">
            <h2>Вход</h2>
            <div className="auth-form">
                <input
                    type="email"
                    placeholder="Email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                />
                <input
                    type="password"
                    placeholder="Пароль"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                />
                <button onClick={handleLogin}>Войти</button>
                <ErrorMessage message={error} />
            </div>
        </div>
    );
};

export default Login;
