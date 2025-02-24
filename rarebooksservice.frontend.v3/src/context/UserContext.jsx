// src/context/UserContext.jsx

import React, { createContext, useState, useEffect } from 'react';
import axios from 'axios';
import Cookies from 'js-cookie';
import { API_URL } from '../api';

export const UserContext = createContext(null);

export const UserProvider = ({ children }) => {
    const [user, setUser] = useState(null);
    const [loadingUser, setLoadingUser] = useState(true);

    // Метод, который в любой момент можно вызвать, чтобы 
    // повторно загрузить данные пользователя с бэкенда
    const refreshUser = async () => {
        setLoadingUser(true);
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
            setLoadingUser(false);
        }
    };

    // При первой загрузке контекста тоже вызываем refreshUser
    useEffect(() => {
        refreshUser();
    }, []);

    return (
        <UserContext.Provider value={{ user, setUser, loadingUser, refreshUser }}>
            {children}
        </UserContext.Provider>
    );
};
