// src/components/PrivateRoute.jsx
import React from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { UserContext } from '../context/UserContext';

const PrivateRoute = () => {
    const { user, loading } = React.useContext(UserContext);

    if (loading) {
        // Пока идёт проверка токена
        return <div>Загрузка...</div>;
    }

    if (!user) {
        // Проверка закончилась, пользователя нет
        return <Navigate to="/login" />;
    }

    // Иначе пропускаем дальше
    return <Outlet />;
};

export default PrivateRoute;
