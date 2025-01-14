// src/components/PrivateRoute.jsx
import React from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { UserContext } from '../context/UserContext';

const PrivateRoute = () => {
    const { user, loading } = React.useContext(UserContext);

    // Пока грузим пользователя — можно показывать Spinner или возвращать null
    if (loading) {
        return <div>Загрузка...</div>;
    }

    // Если user отсутствует — редирект на /login
    if (!user) {
        return <Navigate to="/login" />;
    }

    // Иначе всё ок
    return <Outlet />;
};

export default PrivateRoute;
