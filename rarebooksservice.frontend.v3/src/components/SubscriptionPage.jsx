//src/components/Subscription.jsx
import React, { useState, useContext } from 'react';
import { createPayment } from '../api';
import { UserContext } from '../context/UserContext';
import ErrorMessage from './ErrorMessage';

const SubscriptionPage = () => {
    const { user } = useContext(UserContext);
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);

    const handleSubscribe = async () => {
        setError('');
        setLoading(true);
        try {
            const response = await createPayment();
            const { RedirectUrl } = response.data;
            // Перенаправляем пользователя на страницу оплаты
            window.location.href = RedirectUrl;
        } catch (error) {
            console.error('Subscription error:', error);
            setError('Не удалось создать платеж. Попробуйте позже.');
        } finally {
            setLoading(false);
        }
    };

    if (!user) {
        return (
            <div className="container">
                <h2>Оформить подписку</h2>
                <p>Вы должны быть авторизованы, чтобы оформить подписку.</p>
            </div>
        );
    }

    if (user.hasSubscription) {
        return (
            <div className="container">
                <h2>Подписка уже активна</h2>
                <p>Вы уже имеете активную подписку!</p>
            </div>
        );
    }

    return (
        <div className="container">
            <h2>Оформить подписку</h2>
            <p>Стоимость подписки: 1000 руб/месяц</p>
            {error && <ErrorMessage message={error} />}
            {loading ? <p>Создание платежа...</p> : <button onClick={handleSubscribe}>Перейти к оплате</button>}
        </div>
    );
};

export default SubscriptionPage;
