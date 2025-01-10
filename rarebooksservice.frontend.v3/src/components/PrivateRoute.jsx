// src/components/PrivateRoute.jsx
import React from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { UserContext } from '../context/UserContext';

const PrivateRoute = () => {
    const { user, isConfigured } = React.useContext(UserContext);

    // 1) Если система не настроена, 
    //    перенаправляем на '/', где будет показана страница initial setup.
    if (!isConfigured) {
        return <Navigate to="/" />;
    }

    // 2) Если система настроена, а user отсутствует — редирект на /login.
    if (!user) {
        return <Navigate to="/login" />;
    }

    // Иначе всё ок, пускаем
    return <Outlet />;
};

export default PrivateRoute;
