import React, { useState, useContext, useEffect } from 'react';
import { UserContext } from '../context/UserContext';
import ErrorMessage from './ErrorMessage';
import axios from 'axios';
import { API_URL } from '../api';
import Cookies from 'js-cookie';

const SubscriptionPage = () => {
    const { user } = useContext(UserContext);
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const [plans, setPlans] = useState([]);
    const [selectedPlanId, setSelectedPlanId] = useState(null);
    const [autoRenew, setAutoRenew] = useState(false);

    // Загружаем планы подписки
    useEffect(() => {
        fetchPlans();
    }, []);

    const fetchPlans = async () => {
        try {
            const response = await axios.get(`${API_URL}/subscription/plans`);
            setPlans(response.data);
        } catch (err) {
            console.error(err);
            setError('Не удалось загрузить планы подписки');
        }
    };

    const handleSubscribe = async () => {
        setError('');
        if (!selectedPlanId) {
            setError('Выберите план');
            return;
        }
        setLoading(true);

        try {
            // Посылаем POST: /api/subscription/create-payment
            // body: { subscriptionPlanId, autoRenew }
            const token = Cookies.get('token');
            const response = await axios.post(
                `${API_URL}/subscription/create-payment`,
                { subscriptionPlanId: selectedPlanId, autoRenew },
                { headers: { Authorization: `Bearer ${token}` } }
            );
            // В ответе ожидаем: { redirectUrl: '...' }
            const { redirectUrl } = response.data;
            window.location.href = redirectUrl;
        } catch (err) {
            console.error('Subscription error:', err);
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

    // Если есть уже активная подписка, можем уведомить:
    // (или запросить на бэкенд: /api/subscription/my-subscriptions и проверить последнюю)
    // Для простоты — если user.HasSubscription === true
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
            {error && <ErrorMessage message={error} />}
            {loading && <p>Создание платежа...</p>}

            <div style={{ margin: '20px 0' }}>
                <h3>Выберите план:</h3>
                {plans.length === 0 && <p>Нет доступных планов</p>}
                <ul>
                    {plans.map(plan => (
                        <li key={plan.id} style={{ marginBottom: '10px' }}>
                            <label>
                                <input
                                    type="radio"
                                    name="subscriptionPlan"
                                    value={plan.id}
                                    checked={selectedPlanId === plan.id}
                                    onChange={() => setSelectedPlanId(plan.id)}
                                />
                                {plan.name} — {plan.price} руб/мес, лимит: {plan.monthlyRequestLimit} запросов
                            </label>
                        </li>
                    ))}
                </ul>
            </div>

            <div style={{ margin: '20px 0' }}>
                <label>
                    <input
                        type="checkbox"
                        checked={autoRenew}
                        onChange={() => setAutoRenew(!autoRenew)}
                    />
                    Автоматически продлевать подписку
                </label>
            </div>

            <button onClick={handleSubscribe} disabled={loading}>
                Перейти к оплате
            </button>
        </div>
    );
};

export default SubscriptionPage;
