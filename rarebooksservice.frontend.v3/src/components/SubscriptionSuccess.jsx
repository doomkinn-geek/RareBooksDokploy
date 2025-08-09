// src/components/SubscriptionSuccess.jsx
import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { API_URL } from '../api';
import axios from 'axios';
import Cookies from 'js-cookie';
import ErrorMessage from './ErrorMessage';

const SubscriptionSuccess = () => {
    const [error, setError] = useState('');
    const [checking, setChecking] = useState(true);
    const [success, setSuccess] = useState(false);
    const navigate = useNavigate();

    useEffect(() => {
        checkSubscriptionStatus();
        // eslint-disable-next-line react-hooks/exhaustive-deps
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
            // если есть подписка IsActive = true (и энд-дата > now)
            const activeSub = subs.find((s) => s.isActive);
            if (activeSub) {
                setSuccess(true);
                // Если оформляли подписку со страницы книги — вернём пользователя туда
                try {
                    const returnTo = localStorage.getItem('returnTo');
                    if (returnTo) {
                        localStorage.removeItem('returnTo');
                        // Чуть задержим редирект для отображения статуса
                        setTimeout(() => {
                            navigate(returnTo, { replace: true });
                        }, 500);
                    }
                } catch (_e) {}
            } else {
                setError('Подписка пока не активирована. Подождите немного или обратитесь в поддержку.');
            }
        } catch (err) {
            console.error('Check subscription error:', err);
            setError('Ошибка при проверке подписки.');
        } finally {
            setChecking(false);
        }
    };

    // Пока идёт проверка
    if (checking) {
        return (
            <div className="container" style={{ marginTop: '40px', textAlign: 'center' }}>
                <h2>Проверяем статус подписки...</h2>
                <p>Пожалуйста, подождите.</p>
            </div>
        );
    }

    // Если есть ошибка
    if (error) {
        return (
            <div className="container" style={{ marginTop: '40px', maxWidth: '600px' }}>
                <h2>Результат оплаты</h2>
                <div style={{
                    border: '1px solid #e00',
                    padding: '16px',
                    borderRadius: '4px',
                    backgroundColor: '#ffe5e5'
                }}>
                    <ErrorMessage message={error} />
                </div>
                <p style={{ marginTop: '20px' }}>
                    Если проблема не решается, пожалуйста, свяжитесь с поддержкой.
                    Для экстренной связи пишите в телеграм <a href="https://t.me/doomkinn" target="_blank" rel="noopener noreferrer">https://t.me/doomkinn</a>
                </p>
            </div>
        );
    }

    // Если success
    if (success) {
        return (
            <div className="container" style={{ marginTop: '40px', maxWidth: '600px' }}>
                <h2 style={{ color: '#3c763d' }}>Оплата успешно выполнена!</h2>
                <div style={{
                    border: '1px solid #5cb85c',
                    padding: '16px',
                    borderRadius: '4px',
                    backgroundColor: '#dff0d8'
                }}>
                    <p style={{ margin: 0 }}>
                        Ваша подписка активна. Благодарим за использование Rare Books Service.
                    </p>
                </div>
            </div>
        );
    }

    // Если проверили, но success=false и error='' (например, подписка не активна, но и без ошибки):
    return (
        <div className="container" style={{ marginTop: '40px', maxWidth: '600px' }}>
            <h2>Оплата завершена</h2>
            <div style={{
                border: '1px solid #ccc',
                padding: '16px',
                borderRadius: '4px',
                backgroundColor: '#f9f9f9'
            }}>
                <p>
                    Подписка пока не активна. Пожалуйста, обновите страницу позже или
                    свяжитесь с поддержкой.
                </p>
            </div>
        </div>
    );
};

export default SubscriptionSuccess;
