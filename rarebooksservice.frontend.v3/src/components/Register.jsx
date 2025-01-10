//src/components/Register.jsx
import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { getCaptcha, registerUser } from '../api'; // Импортируем функции из api.js
import ErrorMessage from './ErrorMessage';

const Register = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [error, setError] = useState('');
    const [validationError, setValidationError] = useState('');
    const [captchaToken, setCaptchaToken] = useState('');
    const [captchaImage, setCaptchaImage] = useState(null);
    const [captchaCode, setCaptchaCode] = useState('');
    const navigate = useNavigate();

    const loadCaptcha = async () => {
        try {
            const response = await getCaptcha();
            console.log("Captcha response headers:", response.headers); // логируем все заголовки
            const captchaTokenFromHeader = response.headers['x-captcha-token'];
            console.log("Captcha token from header:", captchaTokenFromHeader);

            setCaptchaToken(captchaTokenFromHeader);

            const blob = new Blob([response.data], { type: 'image/png' });
            const url = URL.createObjectURL(blob);
            setCaptchaImage(url);
        } catch (error) {
            console.error('Ошибка получения CAPTCHA:', error);
            setError('Ошибка при загрузке защиты от ботов. Попробуйте позже.');
        }
    };


    useEffect(() => {
        loadCaptcha();
    }, []);

    const handleRegister = async () => {
        setError('');
        setValidationError('');

        if (password !== confirmPassword) {
            setValidationError('Пароли не совпадают.');
            return;
        }

        if (!captchaCode.trim()) {
            setValidationError('Введите код с картинки.');
            return;
        }

        try {
            await registerUser({
                email,
                password,
                captchaToken,
                captchaCode
            });
            navigate('/login');
        } catch (error) {
            console.error('Ошибка регистрации:', error.response?.data);
            setError(error.response?.data?.error ?? 'Ошибка при регистрации. Проверьте введенные данные или попробуйте позже.');
        }
    };

    const reloadCaptcha = async () => {
        setError('');
        setValidationError('');
        setCaptchaCode('');
        setCaptchaImage(null);
        setCaptchaToken('');
        await loadCaptcha(); // Просто заново вызываем загрузку капчи
    };

    return (
        <div className="container">
            <h2>Регистрация</h2>
            <div className="auth-form">
                {error && <ErrorMessage message={error} />}
                {validationError && <ErrorMessage message={validationError} />}

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

                <input
                    type="password"
                    placeholder="Подтверждение пароля"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                />

                {captchaImage && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <img src={captchaImage} alt="CAPTCHA" />
                        <button type="button" onClick={reloadCaptcha}>Обновить</button>
                    </div>
                )}


                <input
                    type="text"
                    placeholder="Введите код с картинки"
                    value={captchaCode}
                    onChange={(e) => setCaptchaCode(e.target.value)}
                />

                <button onClick={handleRegister}>Зарегистрироваться</button>
            </div>
        </div>
    );
};

export default Register;
