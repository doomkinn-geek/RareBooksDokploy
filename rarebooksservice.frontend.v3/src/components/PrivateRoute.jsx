// PrivateRoute.jsx
import React from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { UserContext } from '../context/UserContext';

const PrivateRoute = () => {
    const { user, initialLoading } = React.useContext(UserContext);

    // Показываем Loading только при самом первом запросе к API
    if (initialLoading) {
        return <div>Загрузка...</div>;
    }

    // Если первый запрос уже был, и user=null, значит, не авторизован.
    if (!user) {
        return <Navigate to="/login" />;
    }

    return <Outlet />;
};

export default PrivateRoute;
