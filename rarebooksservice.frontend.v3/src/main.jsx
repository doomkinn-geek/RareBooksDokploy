//src/main.jsx
import React from 'react';
import ReactDOM from 'react-dom/client'; // ������ �� 'react-dom/client'
import App from './App.jsx';
import './index.css';
import './style.css';
import { UserProvider } from './context/UserContext';

// ������� ���������, � ������� �� ������ ��������� ����������
const container = document.getElementById('root');

// �������� ������
const root = ReactDOM.createRoot(container);

// ������ ����������� root.render ��� ���������� ����������
root.render(
    //��-�� StrictMode ������ ������ ����������� ���������� ������.
    //<React.StrictMode>
        <UserProvider>
            <App />
        </UserProvider>
    //</React.StrictMode>
);
