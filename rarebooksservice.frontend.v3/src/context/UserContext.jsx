﻿// UserContext.jsx
import React, { createContext, useState, useEffect } from 'react';
import axios from 'axios';
import Cookies from 'js-cookie';
import { API_URL } from '../api';

export const UserContext = createContext(null);

export const UserProvider = ({ children }) => {
    const [user, setUser] = useState(null);

    // Показываем PrivateRoute «запрет на рендер» только во время первого запроса
    const [initialLoading, setInitialLoading] = useState(true);

    // А это «фоновое» обновление, которое не мешает рендеру
    const [userRefreshInProgress, setUserRefreshInProgress] = useState(false);

    // Первый вызов при загрузке приложения
    useEffect(() => {
        (async () => {
            try {
                await refreshUser(); // см. ниже
            } finally {
                // По окончании «первого» refreshUser снимаем initialLoading
                setInitialLoading(false);
            }
        })();
    }, []);

    // Обычный метод refreshUser, но различаем, первый это вызов или нет
    const refreshUser = async (force = false) => {
        // Если force === true, мы допускаем, что нужно «принудительно» сходить за данными
        // и обновить user, при этом показывать local-спиннер,
        // но не выключать всё приложение.

        // Если это «не первая загрузка», используем userRefreshInProgress
        if (!initialLoading) {
            setUserRefreshInProgress(true);
        }

        try {
            const token = Cookies.get('token');
            if (!token) {
                setUser(null);
                return;
            }
            const response = await axios.get(`${API_URL}/auth/user`, {
                headers: { Authorization: `Bearer ${token}` },
            });
            setUser(response.data);
        } catch (error) {
            console.error('Ошибка при получении данных пользователя:', error);
            setUser(null);
        } finally {
            if (!initialLoading) {
                setUserRefreshInProgress(false);
            }
        }
    };

    return (
        <UserContext.Provider
            value={{
                user,
                setUser,
                initialLoading,
                userRefreshInProgress,
                refreshUser,
            }}
        >
            {children}
        </UserContext.Provider>
    );
};
