// src/components/SubscriptionPage.jsx

import React, { useState, useContext, useEffect } from 'react';
import { UserContext } from '../context/UserContext';
import ErrorMessage from './ErrorMessage';
import axios from 'axios';
import { API_URL } from '../api';
import Cookies from 'js-cookie';

const SubscriptionPage = () => {
    const { user, loadingUser, refreshUser } = useContext(UserContext);
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const [plans, setPlans] = useState([]);
    const [selectedPlanId, setSelectedPlanId] = useState(null);
    const [autoRenew, setAutoRenew] = useState(false);
    const [supportsAutoRenew] = useState(false); // ваш магазин не поддерживает recurring

    // При монтировании компонента — сначала обновляем пользователя, потом грузим планы
    useEffect(() => {
        let mounted = true;

        (async () => {
            try {
                setError('');
                setLoading(true);

                // 1) Обновить пользователя
                await refreshUser(); // меняет user, но мы не перерисовываем ещё раз через зависимость

                // 2) Загрузить планы
                const response = await axios.get(`${API_URL}/subscription/plans`);
                if (mounted) setPlans(response.data);
            } catch (err) {
                if (mounted) {
                    const serverMessage = err.response?.data || 'Нет дополнительной информации';
                    setError(`Не удалось загрузить планы подписки: ${serverMessage}`);
                }
            } finally {
                if (mounted) setLoading(false);
            }
        })();

        return () => {
            mounted = false;
        };
        // Пустой массив зависимостей — эффект вызовется один раз при монтировании
    }, []);


    const handleSubscribe = async () => {
        setError('');
        if (!selectedPlanId) {
            setError('Выберите план');
            return;
        }
        setLoading(true);

        try {
            console.log("Создаём платёж для плана", selectedPlanId, "autoRenew=", autoRenew);
            const token = Cookies.get('token');
            const response = await axios.post(
                `${API_URL}/subscription/create-payment`,
                { subscriptionPlanId: selectedPlanId, autoRenew },
                { headers: { Authorization: `Bearer ${token}` } }
            );
            const { redirectUrl } = response.data;
            console.log("Payment создан. Редирект на:", redirectUrl);
            window.location.href = redirectUrl;
        } catch (err) {
            console.error("Ошибка при создании платежа:", err);
            const serverMessage = err.response?.data || 'Нет дополнительной информации';
            setError(`Не удалось создать платёж. Причина: ${serverMessage}`);
        } finally {
            setLoading(false);
        }
    };

    // Если ещё грузим данные пользователя - покажем прелоадер
    if (loadingUser) {
        return <div className="container"><p>Загрузка данных пользователя...</p></div>;
    }

    // Проверяем user
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
            {error && <ErrorMessage message={error} />}
            {loading && <p>Загрузка...</p>}

            <div style={{ margin: '20px 0' }}>
                <h3>Выберите план:</h3>
                {plans.length === 0 && !loading && (
                    <p>Нет доступных планов или произошла ошибка при загрузке.</p>
                )}
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

            {supportsAutoRenew && (
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
            )}

            <button onClick={handleSubscribe} disabled={loading}>
                Перейти к оплате
            </button>
        </div>
    );
};

export default SubscriptionPage;
