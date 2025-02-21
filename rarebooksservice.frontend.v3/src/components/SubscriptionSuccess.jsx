// src/components/SubscriptionSuccess.jsx
import React, { useState, useEffect } from 'react';
import { API_URL } from '../api';
import axios from 'axios';
import Cookies from 'js-cookie';
import ErrorMessage from './ErrorMessage';

const SubscriptionSuccess = () => {
    const [error, setError] = useState('');
    const [checking, setChecking] = useState(true);
    const [success, setSuccess] = useState(false);

    // При загрузке компонента сделаем запрос на сервер, чтобы уточнить, 
    // активна ли подписка.
    useEffect(() => {
        checkSubscriptionStatus();
    }, []);

    const checkSubscriptionStatus = async () => {
        setChecking(true);
        setError('');
        try {
            const token = Cookies.get('token');
            if (!token) {
                setError('Вы не авторизованы');
                setChecking(false);
                return;
            }
            // Запрашиваем /api/subscription/my-subscriptions
            const response = await axios.get(`${API_URL}/subscription/my-subscriptions`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            const subs = response.data;
            // если среди подписок есть IsActive=true и EndDate > Now - значит успех
            const activeSub = subs.find((s) => s.isActive);
            if (activeSub) {
                setSuccess(true);
            } else {
                setError('Подписка пока не активирована. Подождите немного или обратитесь в поддержку.<br/>Для экстренной связи пишите в телеграм https://t.me/doomkinn');
            }
        } catch (err) {
            console.error('Check subscription error:', err);
            setError('Ошибка при проверке подписки.');
        } finally {
            setChecking(false);
        }
    };

    if (checking) {
        return <div className="container">Проверяем статус подписки...</div>;
    }

    if (error) {
        return (
            <div className="container">
                <h2>Результат оплаты</h2>
                <ErrorMessage message={error} />
            </div>
        );
    }

    if (success) {
        return (
            <div className="container">
                <h2>Оплата успешно выполнена!</h2>
                <p>Ваша подписка активна. Благодарим за использование Rare Books Service.</p>
            </div>
        );
    }

    return (
        <div className="container">
            <h2>Оплата завершена</h2>
            <p>Подписка пока не активна. Пожалуйста, обновите страницу позже или свяжитесь с поддержкой.</p>
        </div>
    );
};

export default SubscriptionSuccess;
