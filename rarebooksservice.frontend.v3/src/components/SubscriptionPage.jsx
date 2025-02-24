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

    useEffect(() => {
        let mounted = true;
        (async () => {
            try {
                setError('');
                setLoading(true);

                // 1) Обновить пользователя
                await refreshUser();

                // 2) Загрузить планы
                const response = await axios.get(`${API_URL}/subscription/plans`);
                if (mounted) {
                    setPlans(response.data);
                }
            } catch (err) {
                if (mounted) {
                    const serverMessage = err.response?.data || 'Нет дополнительной информации';
                    setError(`Не удалось загрузить планы подписки: ${serverMessage}`);
                }
            } finally {
                if (mounted) setLoading(false);
            }
        })();
        return () => { mounted = false; };
    }, []);

    const handleSubscribe = async () => {
        setError('');
        if (!selectedPlanId) {
            setError('Выберите план');
            return;
        }
        setLoading(true);

        try {
            const token = Cookies.get('token');
            const response = await axios.post(
                `${API_URL}/subscription/create-payment`,
                { subscriptionPlanId: selectedPlanId, autoRenew },
                { headers: { Authorization: `Bearer ${token}` } }
            );
            const { redirectUrl } = response.data;
            window.location.href = redirectUrl;
        } catch (err) {
            const serverMessage = err.response?.data || 'Нет дополнительной информации';
            setError(`Не удалось создать платёж. Причина: ${serverMessage}`);
        } finally {
            setLoading(false);
        }
    };

    if (loadingUser) {
        return (
            <div className="container">
                <p>Загрузка данных пользователя...</p>
            </div>
        );
    }

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

                {/* Блок карточек */}
                <div
                    style={{
                        display: 'grid',
                        gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))',
                        gap: '16px',
                        marginTop: '16px'
                    }}
                >
                    {plans.map((plan) => {
                        const isSelected = selectedPlanId === plan.id;

                        return (
                            <div
                                key={plan.id}
                                className="plan-card"
                                style={{
                                    border: isSelected ? '2px solid #ffcc00' : '1px solid #ccc',
                                    borderRadius: '4px',
                                    padding: '16px',
                                    boxShadow: isSelected
                                        ? '0 0 8px rgba(255, 204, 0, 0.5)'
                                        : '0 2px 4px rgba(0,0,0,0.1)',
                                    cursor: 'pointer',
                                    transition: 'all 0.2s ease-in-out'
                                }}
                                onClick={() => setSelectedPlanId(plan.id)}
                            >
                                <h4 style={{ marginTop: 0 }}>{plan.name}</h4>
                                <p style={{ margin: '8px 0' }}>
                                    <strong>Цена:</strong> {plan.price} руб/мес
                                </p>
                                <p style={{ margin: '8px 0' }}>
                                    <strong>Лимит запросов:</strong> {plan.monthlyRequestLimit}
                                </p>
                                <div style={{ marginTop: '12px' }}>
                                    {/* Радиокнопка, скрытая от глаз, 
                                        но всё же обрабатываем checked для логики */}
                                    <input
                                        type="radio"
                                        name="subscriptionPlan"
                                        value={plan.id}
                                        checked={isSelected}
                                        onChange={() => setSelectedPlanId(plan.id)}
                                        style={{ display: 'none' }}
                                    />
                                    {isSelected && (
                                        <span style={{ color: '#ffcc00', fontWeight: 'bold' }}>
                                            Выбрано
                                        </span>
                                    )}
                                </div>
                            </div>
                        );
                    })}
                </div>
            </div>

            {supportsAutoRenew && (
                <div style={{ margin: '20px 0' }}>
                    <label>
                        <input
                            type="checkbox"
                            checked={autoRenew}
                            onChange={() => setAutoRenew(!autoRenew)}
                            style={{ marginRight: '8px' }}
                        />
                        Автоматически продлевать подписку
                    </label>
                </div>
            )}

            <button
                onClick={handleSubscribe}
                disabled={loading || !selectedPlanId}
                style={{
                    backgroundColor: '#ffcc00',
                    color: '#000',
                    border: 'none',
                    padding: '10px 20px',
                    cursor: 'pointer',
                    borderRadius: '4px'
                }}
            >
                Перейти к оплате
            </button>
        </div>
    );
};

export default SubscriptionPage;
