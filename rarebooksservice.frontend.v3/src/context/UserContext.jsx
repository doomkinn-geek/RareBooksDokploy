// src/context/UserContext.jsx
import React, { createContext, useState, useEffect } from 'react';
import axios from 'axios';
import Cookies from 'js-cookie';
import { API_URL } from '../api';

export const UserContext = createContext(null);

export const UserProvider = ({ children }) => {
    const [user, setUser] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchUser = async () => {
            const token = Cookies.get('token');
            // Берём токен из localStorage
            //const token = localStorage.getItem('token');
            if (token) {
                try {
                    // Пытаемся сходить на /auth/user
                    const response = await axios.get(`${API_URL}/auth/user`, {
                        headers: { Authorization: `Bearer ${token}` },
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
    }, []);

    return (
        <UserContext.Provider value={{ user, setUser, loading }}>
            {children}
        </UserContext.Provider>
    );
};
