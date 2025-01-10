// src/components/InitialSetupPage.jsx
import React, { useState, useEffect } from 'react';
import axios from 'axios';

export default function InitialSetupPage() {
    const [adminEmail, setAdminEmail] = useState('');
    const [adminPassword, setAdminPassword] = useState('');
    const [connectionString, setConnectionString] = useState('');
    const [message, setMessage] = useState('');

    const handleInitialize = async () => {
        setMessage('');
        try {
            const res = await axios.post('/api/setup/initialize', {
                adminEmail,
                adminPassword,
                connectionString,
            });
            setMessage('Сервер уходит на перезапуск... ' + res.data);
        } catch (err) {
            setMessage('Ошибка: ' + (err.response?.data || err.message));
            console.error(err);
        }
    };

    return (
        <div className="admin-panel-container">
            <h2>Первичная настройка</h2>
            <p>Заполните настройки приложения.</p>
            <div className="admin-section">
                <label>Admin E-mail:</label><br />
                <input
                    type="email"
                    value={adminEmail}
                    onChange={(e) => setAdminEmail(e.target.value)}
                />
            </div>
            <div className="admin-section">
                <label>Admin Password:</label><br />
                <input
                    type="password"
                    value={adminPassword}
                    onChange={(e) => setAdminPassword(e.target.value)}
                />
            </div>
            <div className="admin-section">
                <label>Connection String:</label><br />
                <input
                    type="text"
                    value={connectionString}
                    onChange={(e) => setConnectionString(e.target.value)}
                />
            </div>
            <button className="admin-button" onClick={handleInitialize}>
                Инициализировать
            </button>
            {message && <div style={{ marginTop: '10px' }}>{message}</div>}
        </div>
    );
}
