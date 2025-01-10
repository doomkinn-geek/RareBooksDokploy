// src/context/UserContext.jsx
import React, { createContext, useState, useEffect } from 'react';
import axios from 'axios';
import Cookies from 'js-cookie';
import { API_URL } from '../api';

export const UserContext = createContext(null);

export const UserProvider = ({ children }) => {
    const [user, setUser] = useState(null);
    const [loading, setLoading] = useState(true);

    // Признак, что система настроена (нет необходимости в initial setup)
    const [isConfigured, setIsConfigured] = useState(false);
    const [configCheckDone, setConfigCheckDone] = useState(false);
    // ↑ нужен, чтобы понимать, что *запрос* на /need-setup уже завершён.

    // Проверяем, нуждается ли система в настройке
    useEffect(() => {
        const checkSetup = async () => {
            try {
                const res = await axios.get(`${API_URL}/setupcheck/need-setup`);
                if (res.data && res.data.needSetup === false) {
                    setIsConfigured(true);
                }
            } catch (error) {
                console.error('Ошибка при проверке NeedSetup:', error);
                // Если упало, допустим, считаем систему настроенной, 
                // чтобы не зацикливаться. Или показывать ошибку — на ваше усмотрение.
                setIsConfigured(true);
            }
            setConfigCheckDone(true);
        };
        checkSetup();
    }, []);

    // Если система настроена — грузим пользователя
    useEffect(() => {
        if (!isConfigured) {
            // система не настроена => не пытаемся грузить user
            setLoading(false);
            return;
        }
        // Если система уже настроена -> грузим юзера
        const fetchUser = async () => {
            const token = Cookies.get('token');
            if (token) {
                try {
                    const response = await axios.get(`${API_URL}/auth/user`, {
                        headers: {
                            Authorization: `Bearer ${token}`,
                        },
                    });
                    setUser(response.data);
                } catch (error) {
                    console.error('Ошибка при получении данных пользователя:', error);
                    setUser(null);
                } finally {
                    setLoading(false);
                }
            } else {
                setUser(null);
                setLoading(false);
            }
        };
        fetchUser();
    }, [isConfigured]);

    return (
        <UserContext.Provider value={{
            user,
            setUser,
            loading,
            isConfigured,
            setIsConfigured,
            configCheckDone
        }}>
            {children}
        </UserContext.Provider>
    );
};
